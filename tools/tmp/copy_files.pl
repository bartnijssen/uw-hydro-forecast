#!/usr/bin/perl

$indir = shift;
$prefix = shift;
$soilfile = shift;
$outdir = shift;

open (SOIL, $soilfile) or die "$0: ERROR: cannot open soil file $soilfile\n";
foreach (<SOIL>) {
  @fields = split /\s+/;
  $filename = $prefix . "_" . $fields[2] . "_" . $fields[3];
  $cmd = "cp $indir/$filename $outdir/";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
}
close(SOIL);
