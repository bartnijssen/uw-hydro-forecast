#!/usr/bin/perl

$refdir = shift;
$indir = shift;
$prefix = shift;
$outdir = shift;

opendir(INDIR,$refdir) or die "$0: ERROR: cannot open directory $refdir for reading\n";
@filelist = grep /^$prefix/, readdir(INDIR);
closedir(INDIR);

foreach $file (sort(@filelist)) {
  $cmd = "cp $indir/$file $outdir/";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
}
