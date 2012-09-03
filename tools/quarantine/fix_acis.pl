#!/usr/bin/perl

$filename = shift;
open (FILE, $filename);
foreach (<FILE>) {
  s/-72.78/-99.00/g;
  print;
}
close(FILE);
