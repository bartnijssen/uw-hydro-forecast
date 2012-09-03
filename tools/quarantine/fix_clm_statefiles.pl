#!/usr/bin/perl

$indir = shift;
$prefix = shift;

@month_days = (31,28,31,30,31,30,31,31,30,31,30,31);

opendir (INDIR, $indir) or die "$0: ERROR: cannot open input directory $indir for reading\n";
@filelist = grep /^$prefix/, readdir(INDIR);
closedir(INDIR);
@filelist = sort(@filelist);

foreach $file (@filelist) {
  if ($file =~ /^$prefix\.(\d\d\d\d)(\d\d)/) {
    ($year,$month) = ($1,$2);
    $year--;
  }
  $newfile = sprintf "state.%04d%02d31.nc", $year,$month;
  $cmd = "mv $indir/$file $indir/$newfile";
#print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
}
