#!/usr/bin/perl

$infile = shift;
$col = shift;

open (FILE, $infile) or die "$0: ERROR: cannot open $infile\n";
foreach (<FILE>) {
  chomp;
  @fields = split /\s+/;
  $fields[$col] = 0;
  print "$fields[0]";
  for ($i=1; $i<@fields; $i++) {
    print " $fields[$i]";
  }
  print "\n";
}
close(FILE);
