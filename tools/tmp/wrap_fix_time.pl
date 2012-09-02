#!/usr/bin/perl

$indir = shift;
$outdir = shift;

opendir(INDIR,$indir) or die "$0: ERROR: cannot open directory $indir\n";
@filelist = grep !/^\./, readdir(INDIR);
closedir(INDIR);

foreach $file (@filelist) {
  $cmd = "fix_time.pl $indir/$file > $outdir/$file";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
}
