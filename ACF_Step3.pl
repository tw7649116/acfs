#!/usr/bin/perl -w
use strict;
# cluster circRNAs reads
die "Usage: $0   \"output\"   \"parsed.2pp.S2.sum_input1\"  \"\(optional\)parsed.2pp.S2.sum01_input2 and so on\" " if (@ARGV < 2);
my $fileout=$ARGV[0];
my %uniq;
my $Nr=scalar(@ARGV);

my $command="rm -f Step3_finished";
system($command);

for(my $i=1; $i<$Nr; $i++) {
    my $filein=$ARGV[$i];
    open(IN, $filein) or die "Cannot open input parsed.2pp.S2.sum file : $filein ";
    while (<IN>) {
        chomp;
        next if (m/^#/);
        my @a=split("\t",$_);
        if (scalar(@a) < 23) {
            die "Input file $filein is not expected. Please use the \"\*\.sum\" files generated by ACF_step1\.pl ";
        }
        my $id=join("_",$a[2],$a[6],$a[10],($a[10] - $a[6]));
        if (exists $uniq{$id}) {
            my @b=split("\t",$uniq{$id});
            my $seqid=$a[0];
            if ($b[-1]=~m/$seqid/) {
                warn "Sequence with ID = $seqid appeared > 1 times. Please check if the input files are duplicated.";
            }
            $b[-1]=$b[-1].",".$seqid;
            $uniq{$id}=join("\t",@b);
        }
        else {
            $uniq{$id}=join("\t",$a[2],$a[6],$a[10],($a[10] - $a[6]),$a[14],$a[15],$a[16],$a[17],$a[18],$a[19],$a[20],$a[21],$a[22],$a[0]);
        }
    }
    close IN;
}
open(OUT, ">".$fileout) or die "Cannot open output file $fileout";
#print OUT join("\t","#ID","chr","start","end","jump","SumSS","S5S","S3S","strand","overlap","moveL","moveR","SMS","PMS","newids"),"\n";
foreach my $id (keys %uniq) {
    print OUT $id,"\t",$uniq{$id},"\n";
}
close OUT;
my $fileout2=$fileout.".s";
$command="sort -k2,2 -k3,4n $fileout > $fileout2";
system($command);
$command="rm -f $fileout";
system($command);
$command="mv $fileout2 $fileout";
system($command);

open(OUTFLAG,">Step3_finished");
print OUTFLAG "Step3_finished\n";
close OUTFLAG;