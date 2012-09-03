#!/usr/bin/perl

$indir = shift;
$prefix = shift;

opendir(ASC_DIR, $indir) or die "$0: ERROR: cannot open $indir for reading\n";
@my_filelist = grep /^$prefix/, readdir(ASC_DIR);
closedir(ASC_DIR);

foreach $myfile (@my_filelist) {
  if ($myfile =~ /^$prefix\_([^_\s]+)\_([^_\s]+)$/) {
    ($lat,$lon) = ($1,$2);
    if ($lon > 180) {
      $lon = sprintf "%.4f", -1*(360-$lon);
    }
    $newfile = $prefix . "_" . $lat . "_" . $lon;
    $cmd = "mv $indir/$myfile $indir/$newfile";
    (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";
  }
}
