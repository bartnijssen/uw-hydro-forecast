#!/usr/bin/perl

$infile = shift;
$start_col = shift;
$start_date = shift;

# Parse start date
($start_year,$start_month) = split /-/, $start_date;

# Initialize date
$year = $start_year;
$month = $start_month;

# Read input file
open (FILE,$infile) or die "$0: Error: cannot open $infile\n";
foreach (<FILE>) {

  chomp;
  s/^\s+//;
  @data = split /\s+/;
  for ($m=0; $m<12; $m++) {
    printf "%04d %02d", $year, $month;
    for ($i=$start_col; $i<=$#data; $i++) {
      printf " %.4f", $data[$i];
    }
    print "\n";

    # Increment date
    $month++;
    if ($month > 12) {
      $month = 1;
      $year++;
    }
  }

}
close(FILE);
