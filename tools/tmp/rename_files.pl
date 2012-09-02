#!/usr/bin/perl

$indir = shift;
$outdir = shift;

opendir(INDIR,$indir) or die "$0: ERROR: cannot open directory $indir\n";
@filelist = grep !/^\./, readdir(INDIR);
closedir(INDIR);

foreach $file (@filelist) {
  if ($file =~ /^(\S+)(\d\d\d\d)-(\d\d).nc/) {
    $newfile = "$1.$2$3.nc";
  }
  $cmd = "cp $indir/$file $outdir/$newfile";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
}
