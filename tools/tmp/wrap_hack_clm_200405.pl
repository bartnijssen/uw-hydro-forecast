#!/usr/bin/perl

$indir = shift;
$outdir = shift;

opendir(INDIR,$indir) or die "$0: ERROR: cannot open directory $indir for reading\n";
@filelist = grep !/^\./, readdir(INDIR);
closedir(INDIR);

foreach $file (sort(@filelist)) {
  if ($file =~ /^([^\_]+)\_([^\_]+)\_([^\_]+)$/) {
    ($prefix,$lat,$lon) = ($1,$2,$3);
    if ($lon < -98.25) {
      $newlon = sprintf "%.4f", $lon + 31;
      $newlat = sprintf "%.4f", $lat - 0.5;
    }
    else {
      $newlon = sprintf "%.4f", $lon - 26.5;
      $newlat = sprintf "%.4f", $lat;
    }
    $newfile = $prefix . "_" . $newlat . "_" . $newlon;
    $cmd = "cp $indir/$file $outdir/$newfile";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
  }
}
