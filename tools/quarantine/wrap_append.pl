#!/usr/bin/perl

$indir = shift;
$outdir = shift;
$prefix = shift; # If omitted, all files in the input directory will be appended to the output directory

opendir(INDIR,$indir) or die "$0: ERROR: cannot open directory $refdir for reading\n";
if ($prefix) {
  @filelist = grep /^$prefix/, readdir(INDIR);
}
else {
  @filelist = grep !/^\./, readdir(INDIR);
}
closedir(INDIR);

foreach $file (sort(@filelist)) {
  $cmd = "cat $indir/$file >> $outdir/$file";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
}
