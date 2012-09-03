#!/usr/bin/perl

$indir = shift;
$col = shift;
$maxlag = shift;
$outdir = shift;

#opendir(INDIR,$indir) or die "$0: ERROR: cannot open directory $indir for reading\n";
#@filelist = grep !/^\./, readdir(INDIR);
#closedir(INDIR);
$cmd = "ls $indir";
@filelist = `$cmd`;
foreach (@filelist) {
  chomp;
  s/^\s+//;
}

foreach $file (@filelist) {
  $cmd = "autocorr.pl $indir/$file $col $maxlag > $outdir/$file";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
}
