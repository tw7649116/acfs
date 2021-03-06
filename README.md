# ACFS
Accurate CircRNA Finder Suite. Discovering circRNAs from RNA-Seq data.


# Overview
CircRNAs are generated through splicing, or to be precise, back-splicing where the downstream splice donor attacks an upstream splice acceptor. Identifying the exact site of back-splice lies in the heart of circRNA discovery.

ACFS first examines and pinpoints the back-splice site from RNA-Seq alignment using a maximal entropy model. The expression of circRNAs is estimated from a second round of alignment to the inferred pseudo circular sequences.

No prior knowledge of gene annotation is needed for circRNA prediection, but reading the coordinates is far less interesting than reading gene names, so circRNAs are annotated using the gene annotation if provided. Also, given annotation, circRNA sequences can be better estimated (especially those contains short exons) and enhance the accuracy of circRNA expression quantification.

ACFS is designed for Single-end RNA-Seq reads. Seeing is believing, we would like to see read directly spanning the back-splice sites. Paired-end data is also supported, albeit with lower sensitivity (if neither of the read ends crosses the back-splice, but the read-pair does).

# Change Log
- Update on 2016-05-06 :
   Added extension for fining trans-splicing evidence, which can be used to identify fusion-circRNAs
- Update on 2016-01-27 :
   Performance improvement and add scripts for simulation
- Update on 2015-09-17 :
   Added a small real-world example
- Update on 2015-08-20 :
   Added support for paired-end reads
- Update on 2015-08-11 :
   Corrected the Tutorial section in README, thanks to Zol
- Update on 2015-03-09 :
   Now ACF can include pre-defined circRNA annotations from a bed6 or bed12 file (and their authenticity will be checked, so please adjust (minJump, maxJump, minSplicingScore) accordingly ).
   This way, you can both predict novel circRNAs in your data and estimate the abundance of annotated circRNAs.
- First release on 2013-11-01


# Installation
Simply unpack the ACFS package.


# Requirement
- bwa-0.7.3a (included in the package, but you **_need_** to do "make")
- perl
- blat (not necessary, sometime it helps to rule out false positive fusion-circRNAs when there is a gene-duplication or gene-pseudogene dilemma)


# Pipeline scheme
1. Map all Tophat2-unmapped-reads to genome using BWA, seperate :
    - 1-part
    - 2-part-same-chromosome-same-strand  (contain circRNAs)
    - 2-part-same-chromosome-diff-strand  (possibly PolII backwalk)
    - \>2-part-same-chromosome             (contain circRNAs, if they are originated from short exons)
    - \>=2-part-diff-chromosome            (contain trans-splicing, or even fusion-circRNAs)
2. Estimate splicing strength using Christoph Berge's method for "2-part-same-chromosome-same-strand". report:
    - forward-splice (not interesting)
    - back-splice and canonical splice-motif {[GT-AT],[GC-AG],[AT-AC]}, calculate strength using MaxEnt
    - back-splice and non-canonical splice-motif, find the maximal score using MaxEnt and the corresponding back-splice site
    - try to rescue circles using ">2-part-same-chromosome"
3. Check if both splice sites of the cirRNAs are on known exon-borders **_if_** an annotation is provided; otherwise all are CBR. report:
    - both known exon-border (termed : **_MEA_** .  **_M_** atch with **_E_** xisting **_A_** nnotation, which is somewhat more reliable)
    - at least one splice site sits on unknown exon-border (termed : **_CBR_** .   **_C_** hris **_B_** erge **_R_** escued)
4. Build gtf and pseudo-transcript for results from step3
5. Map all unmapped-reads to pseudo-transcipts and estimate the abundance of circRNAs
6. Generate bed track for visulization
7. Optional search of trans-splicing and fusion-circRNA events


# Before running ACFS, a few pre-process
0. Map the RNA-Seq reads to genome and transcriptom, and extract the unmapped reads. This is **_recommended_** as those mapped reads will NOT span the back-splice sites, and therefore do NOT contribute to circRNA discovery. 

1. Change fasta/fastq header format to allow processing multiple samples in one run.
    This is **_IMPORTANT_** ! ACFS expects a special header format so that multiple samples can be processed in one run. Do change the default header such as ">HWUSI-EAS100R:6:73:941:1973" into ">Truseq_sample1_HWUSI-EAS100R:6:73:941:1973", where the "sample1" is the name of your choice describing the sample. Do the conversion as:
    ```
    perl change_fastq_header.pl SRR650317_1.fasta SRR650317_1.fa Truseq_SRR650317left
    perl change_fastq_header.pl SRR650317_2.fasta SRR650317_2.fa Truseq_SRR650317right
    ```
    Make sure there is **_No underline_** within the sample name. e.g. ">Truseq_ctrl.1_Default_header" and ">Truseq_AGO2KO.1_Default_header" are OK; ">Truseq_ctrl_1_Default_header" is BAD because ACF will register "ctrl" as the sample name instead of "ctrl_1".

2. Merge sequences from multiple fasta/fastq files into one fasta file, which saves time for mapping.
    ```
    perl Truseq_merge_unique_fa.pl UNMAP SRR650317_1.fa SRR650317_2.fa
    ```
    Alternatively, if there are many files to merge, generate a file (named filelist for example) contains the full-path of each file
    ```
    perl Truseq_merge_unique_filelist.pl <UNMAP> <filelist>
    ```
    ```UNMAP``` is the collasped fasta file which will be processed by ACFS, and ```UNMAP_expr``` contains the readcount per sequence in all the samples. If you change the name of ```UNMAP``` to ```SomethingElse```, then the readcount file will be automatically named as ```SomethingElse_expr```
    
    However, one **can** bypass the previous and this step to run ACFS **sample by sample**. This way, no fasta header reformatting and reads collapsing is needed. For each sample, set the value of ```UNMAP``` to the name of fasta/fastq in the SPEC_example.txt file, and set the value of ```UNMAP_expr``` to "no".
    
3. Build BWA index, using verion 0.73a (currently not support for other versions as the output format changes between versions)
    ```
    /bin/bwa073a/bwa index /data/iGenome/human/Ensembl/GRCh37/Sequence/BWAIndex/genome.fa
    ```
    
4. Prepare for annotation (recommended)
    Download the gtf file from iGenome package    or    download ensembl gtf here : ftp://ftp.ensembl.org/pub/current_gtf/
    Then run:
    ```
    perl get_split_exon_border_biotype_genename.pl </data/iGenome/human/Ensembl/GRCh37/Annotation/Genes/genes.gtf> </data/iGenome/human/Ensembl/GRCh37/Annotation/Genes/Homo_sapiens.GRCh37.71_split_exon.gtf>
    ```
    The first argument is the input gtf file, the second argument is the output

5. Strandedness is assumed as from the Truseq Stranded RNA-Seq, so the reads are reverse-complementary to mRNAs.
    - If the reads are actually sense (the same 5'->3' direction as mRNA), please reverse-complement all reads.
    - If the reads are actually stransless or pair-ended, please run in parallel original reads and reverse-complemented reads.
    - No pair-end information is used, as the exact junction-site must be supported by a single read. Seeing is believing.
    
6. For Paired-end data, it is highly recommended to align the reads to genome+transcriptome first (e.g. using Tophat2), and extract the unmapped read (read pairs) using the following script (the fasta header line is also modified)
    ```
    perl convert_unmapped_SAM_to_fa_for_acfs.pl <output_file_name> <unmapped.sam> sample_id
    ```


# Parameters
There are nine mandatory parameters to run ACFS in a basic mode. Searching for fusion-circRNAs is disabled by default. Please modify the config file "SPEC_example.txt" according to your specific organism, experimental design and sequence specs. The config file "SPEC_example.txt" is a two-column tab-delimited file : \<name\>\t\<value\>

Mandatory paramters:

| Parameter | value | Note | 
| --------- | ----- | ---- | 
| BWA_folder | /home/bin/bwa037a/ | path of the folder of bwa | 
| BWA_genome_Index | /data/.../BWAIndex/genome.fa | full path to the index files | 
| BWA_genome_folder | /data/.../Chromosomes/ | full path to the folder containing **_separeted_** chromosome files | 
| ACF_folder | /home/bin/ACFS/ | path of the folder of ACFS | 
| CBR_folder | /home/bin/ACFS/CB_splice/ | path of the folder for MaxEnt | 
| Agtf | /data/.../Homo_sapiens.GRCh37.71_split_exon.gtf | processed annotation, see the previous section point-4 | 
| UNMAP | UNMAP | the collapsed fasta file | 
| UNMAP_expr | UNMAP_expr | the expression of the collasped reads | 
| Seq_len | 150 | length of sequencing reads | 

Optional parameters, the values in below are set as default:

| Parameter | value | Note |
| --------- | ----- | ---- |
| Thread | 16 | number of threads used in bwa |
| BWA_seed_length | 16 | bwa seed length  |
| BWA_min_score | 20 | bwa min score to trigger report. For shorter reads, e.g. 50nt, set to 10 or lower could report more circRNAs at risk of higher FDR |
| minJump | 100 | the minimum distance of a back-splice. The smaller, the more likely you can find circles from short exons |
| maxJump | 2500000 | the maximum distance of a back-splice. The larger, the more likely you can find circles from long genes. The longest human gene is CNTNAP2 which spans 2.3M bp |
| minSplicingScore | 10 | the minimum score for the sum of splicing strength at both splice site, 10 corresponds to 95% of all human/mouse splice site pairs. One could also set it to a lower value, e.g. zero, and do a post-filtering after running acfs |
| minSampleCnt | 1 | the minimum number of samples that detect any given circle |
| minReadCnt | 1 | the minimum number of reads (from all samples) that detect any given circle |
| minMappingQuality | 20 | the minimum mapping quality of any given sequence |
| minSpanJunc | 6 | the minimum number of bases reach beyond the back-splice-site. The larger the less likely of false-positive |
| Coverage | 0.9 | the minimum percentage of any given read is aligned. The larger the more conserved the results are |
| ErrorRate | 0.05 | the maximum error rate for re-alignment. The smaller the better |
| Strandness | - | the strand information of sequencing, must be one of the {+, -, no}  |
| pre_defined_circle_bed | no | pre-defined circle annotation in bed6 or bed12 format (to increase sensitivity for lowly expressed circRNAs please include bed12 files of annotated one, e.g. merge the bed files from GSE61991) |
| Search_trans_splicing | no | set to "yes" to seach for trans-splicing reads |
| blat_search | yes | use blat to discard false positives results from gene duplication, turn off by "no" |
| blat_path | blat | full path to the executable, such as "/usr/bin/blat/blat", it is ignored if the blat_search option is set to no |
| trans_splicing_coverage | 0.9 | see Coverage |
| trans_splicing_minMappingQuality | 0 | see minMappingQuality |
| trans_splicing_minSplicingScore | 10 | see minSplicingScore |
| trans_splicing_maxSpan | 2500000 | the maximum distance between the junctions on the same gene for fusion circRNAs |


# run ACFS
1. make Pipeline Bash file
    ```
    perl ACF_MAKE.pl <SPEC_example.txt> <BASH_example.sh>
    ```  
2. find circles
    ```
    bash <BASH_example.sh>
    ```


# Results
1. circRNAs are stored in two files, which can be visualzed using UCSC Genome Browser:
    - circle_candidates_MEA.bed12
    - circle_candidates_CBR.bed12  
    The higher the value in 5th column, the more "likely" that circle is true.  
    The name in 4th column can be seperated by "|" into four segments: circle-ID, sum-of-Splicing-Strength, number-of-supporting-samples, number-of-supporting-reads.  
    The sequence for the "middle exons" in almost every circle is hypothetically filled in using the annotations provided, true sequences could be determined by integrating mRNA-Seq data and validated by inward and outward PCRs.

2. The circRNA expression is stored here:
    - circle_candidates_expr (merged file of <circle_candidates_MEA.expr> and <circle_candidates_CBR.expr>)
    The second column denote the name of the gene from which this circRNA is derived.

3. Fusion-circRNAs, if enabled:  
    - fusion_circRNAs  
    The Junctional sequences are stored in "unmap.trans.splicing.tsloci.fa".



# Tutorial
0. We provide a toy example in the ```test``` folder after unpacking ```test.tar.gz```. One can run the pipeline in few minutes.

1. pre-processing for sequencing reads

    1A. **_for single-end RNA-Seq Raw data only_**. Note this sample is from a stranded RNA-Seq experiment from mouse, therefore mouse annotation should be used. (Feasible but not a good idea in practice, since you don't want to map all reads again. Use unmapped reads instead.)
    ```
    wget ftp://ftp-trace.ncbi.nlm.nih.gov/sra/sra-instant/reads/ByExp/sra/SRX%2FSRX852%2FSRX852583/SRR1772422/SRR1772422.sra  
    fastq-dump.2 --fasta 0 --split-files SRR1772422.sra  
    perl change_fastq_header.pl SRR1772422.fasta SRR1772422.fa Truseq_HippoSyn  
    perl Truseq_merge_unique_fa.pl UNMAP SRR1772422.fa
    ```  
    1B. **_for paired-end RNA-Seq Raw data only_**. Note this sample is from an unstranded RNA-Seq experiment from human, therefore human annotation should be used. (Feasible but not a good idea in practice, since you don't want to map all reads again. Use unmapped reads instead.) As the RNA-Seq was un-stranded, we need to make reverse complement for all reads. For paired-end stranded RNA-Seq data, we need to make reverse complement for Read-2 if the Read-1 is antisense to mRNA (dUTP, NSR, NNSR protocol).
    ```
    wget ftp://ftp-trace.ncbi.nlm.nih.gov/sra/sra-instant/reads/ByExp/sra/SRX%2FSRX218%2FSRX218203/SRR650317/SRR650317.sra  
    fastq-dump.2 --fasta 0 --split-files SRR650317.sra
    perl reverse_complement.pl SRR650317_1.fasta
    perl reverse_complement.pl SRR650317_2.fasta
    perl change_fastq_header.pl SRR650317_1.fasta SRR650317_1.fa Truseq_SRR650317left  
    perl change_fastq_header.pl SRR650317_2.fasta SRR650317_2.fa Truseq_SRR650317right  
    perl change_fastq_header.pl SRR650317_1.fasta.rc SRR650317_1.fa.rc Truseq_SRR650317left  
    perl change_fastq_header.pl SRR650317_2.fasta.rc SRR650317_2.fa.rc Truseq_SRR650317right
    perl Truseq_merge_unique_fa.pl UNMAP SRR650317_1.fa SRR650317_1.fa.rc SRR650317_2.fa SRR650317_2.fa.rc
    ```
    1C. **_for single-end and paired-end RNA-Seq unmapped reads_**.  
    If you have already aligned raw RNA-Seq reads to some reference (using say Bowtie/BWA/STAR/Tophat2), obtain a SAM file ```unmapped.sam``` containing all the unmapped reads. For example if you used Tophat2, simply convert the file ```unmapped.bam``` to ```unmapped.sam``` and then run the following command:
    ```
    perl convert_unmapped_SAM_to_fa_for_acfs.pl <USER_converted.fa> <unmapped.sam> sample_id
    ```  
    where ```sample_id``` is the new sample ID that is added to the fasta/fastq header according to ACFS style. It could be "Ctrl12" or "TreatA.rep2", your choice as long as there is NO underscore as "_" in it.  
    ```USER_converted.fa``` is the name of the output file. Then collapse the reads using the following command:
    ```
    perl Truseq_merge_unique_fa.pl <UNMAP> <USER_converted.fa>
    ```
    Or if you have more than one samples:
    ```
    perl Truseq_merge_unique_fa.pl <UNMAP> <USER_converted_1.fa> <USER_converted_2.fa> <USER_converted_3.fa>  ...
    ```
2. prepare for annotation, if you haven't done so

    ```
    perl get_split_exon_border_biotype_genename.pl /data/iGenome/human/Ensembl/GRCh37/Annotation/Genes/genes.gtf /data/iGenome/human/Ensembl/GRCh37/Annotation/Genes/Homo_sapiens.GRCh37.71_split_exon.gtf
    ```
3. modify the config file SPEC_example.txt accordingly.
4. generate ACFS pipeline

    ```
    perl ACF_MAKE.pl <SPEC_example.txt> <BASH_example.sh>
    ```
5. run ACFS

    ```
    nohup bash <BASH_example.sh> &
    ```
6. take a look at the results when finished :

    - circle_candidates_MEA.bed12      # circRNAs back-splice at annotated boundarys of exon(s)
    - circle_candidates_CBR.bed12      # circRNAs back-splice at un-annotated boundarys of exon(s)  
    And the expression(readcounts) table for circRNAs, with circRNAs in rows and samples in columns
    - circle_candidates.expr               
    And the potential fusion circRNAs  
    - fusion_circRNAs



# A few useful scripts for simulation  
To see the usage, simply run the perl scripts with no arguments.  

1. simulating SE reads from linear transcripts
    ```
    simulate_SE_reads_from_linear.pl
    ```

2. simulating PE reads from linear transcripts
    ```
    simulate_PE_reads_from_linear.pl
    ```

3. simulating circRNAs
    ```
    simulate_gtf_for_circRNA.pl
    get_split_exon_border_biotype_genename.pl
    get_seq_from_agtf.pl
    ```

4. simulating SE reads from circRNAs
    ```
    simulate_SE_reads_from_circRNA.pl
    ```

5. simulating PE reads from circRNAs
    ```
    simulate_PE_reads_from_circRNA.pl
    ```

6. simulating fusion-circRNAs
    ```
    simulate_gtf_for_fusion_circRNA.pl
    get_split_exon_border_biotype_genename.pl
    get_seq_from_agtf.pl
    get_id_from_simulate_fusion_circRNA_gtf.pl
    ```

7. simulating SE reads from fusion-circRNAs (or PE reads where the insert-size is the read length)
    ```
    simulate_reads_for_fusion_circRNA.pl
    ```



    
# Contact
This pipeline is developed and is maintained by Arthur Xintian You: arthur.yxt@gmail.com. I will do my best to respond in a timely manner.

# Cite
Nat Neurosci 2015 Apr;18(4):603-10 [PMID: 25714049]




