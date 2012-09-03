#!/usr/bin/perl

$indir = shift;

opendir (DIR, $indir);
@filelist = grep /9969209968386869046778552952102584320/, readdir (DIR);
closedir (DIR);

foreach $file (@filelist) {
  $cmd = "rm -f $indir/$file";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
}
