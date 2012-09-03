#!/usr/bin/perl

$indir = shift;
$in = shift;
$out = shift;
$agginfo = shift;
$outdir = shift;

opendir(INDIR,$indir) or die "$0: ERROR: cannot open directory $indir for reading\n";
@filelist = grep !/^\./, readdir(INDIR);
closedir(INDIR);

foreach $file (sort(@filelist)) {
  $cmd = "/raid8/forecast/sw_monitor/tools/agg_time.pl -i $indir/$file -in $in -o $outdir/$file -out $out $agginfo";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
}
