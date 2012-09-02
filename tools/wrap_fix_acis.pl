#!/usr/bin/perl

$indir = shift;
#$prefix = shift;

opendir(DIR,$indir);
#@filelist = grep /^$prefix/, readdir(DIR);
@filelist = grep !/^\./, readdir(DIR);
closedir(DIR);

foreach $file (sort(@filelist)) {
  $cmd = "fix_acis.pl $indir/$file > $indir/$file.tmp";
  (system($cmd)==0) or die "$0: ERROR: $cmd faile\n";
  $cmd = "mv $indir/$file.tmp $indir/$file";
  (system($cmd)==0) or die "$0: ERROR: $cmd faile\n";
}
