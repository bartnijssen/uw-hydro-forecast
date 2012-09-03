#!/usr/bin/perl

# This script takes two files of identical dimensions and, for every field on every line
# (except the date fields) forms the product a1*x1 + a2*x2, where x1 and x2 are the value
# of the field from files 1 and 2, and a1 and a2 are coefficients.

$a1 = shift;
$file1 = shift;
$a2 = shift;
$file2 = shift;
$ndate = shift;

open (FILE1, $file1) or die "$0: ERROR: cannot open file $file1\n";
open (FILE2, $file2) or die "$0: ERROR: cannot open file $file2\n";
foreach $line1 (<FILE1>) {
  $line2 = <FILE2>;
  chomp $line1;
  chomp $line2;
  @fields1 = split /\s+/, $line1;
  @fields2 = split /\s+/, $line2;
  @date = @fields1[0..$ndate-1];
  print "@date";
  for ($i=0; $i<=$#fields1-$ndate; $i++) {
    $data = $a1*$fields1[$ndate+$i] + $a2*$fields2[$ndate+$i];
#    printf " %.4e", $data;
    printf " %.4f", $data;
  }
  print "\n";
}
close(FILE1);
close(FILE2);
