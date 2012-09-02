#!/usr/bin/perl

$indir = shift;

opendir(INDIR,$indir) or die "$0: ERROR: cannot open directory $indir for reading\n";
@filelist = grep !/^\./, grep !/gz$/, readdir(INDIR);
closedir(INDIR);

foreach $file (sort(@filelist)) {
  $cmd = "wc -l $indir/$file";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
}
