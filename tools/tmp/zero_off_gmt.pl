#!/usr/bin/perl

$file = shift;
$nlayer = shift;

open(FILE, $file) or die "$0: ERROR: cannot open file $file\n";
foreach (<FILE>) {
  chomp;
  @fields = split /\s+/;
  $fields[$nlayer*9+12] = 0;
  print "$fields[0]";
  for ($i=1; $i<@fields; $i++) {
    print " $fields[$i]";
  }
  print "\n";
}
close(FILE);
