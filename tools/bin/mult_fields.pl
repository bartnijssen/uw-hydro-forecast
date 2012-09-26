#!/usr/bin/env perl
use warnings;

# This script multiplies ascii text file columns by a factor.
# Usage:
# add_fields.pl filename ndate col1,col2,col3,... factor
$file     = shift;  # Input file name
$ndate    = shift;  # number of date fields
$col_list = shift;  # comma-separated list of columns to multiply by the factor
$factor   = shift;
@cols = split /,/, $col_list;
open(FILE, "$file") or die "$0: ERROR: cannot open $file for reading\n";
foreach (<FILE>) {
  chomp;
  @fields = split /\s+/;
  if ($ndate) {
    printf "%s", $fields[0];
    for ($i = 1 ; $i < $ndate ; $i++) {
      printf " %s", $fields[$i];
    }
  }
  $j = 0;
  for ($i = $ndate ; $i < @fields ; $i++) {
    if ($i == $cols[$j]) {
      $fields[$i] *= $factor;
      $j++;
    }
    if ($i == 0) {
      printf "%f", $fields[$i];
    } else {
      printf " %f", $fields[$i];
    }
  }
  print "\n";
}
close(FILE);
