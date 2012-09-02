#!/usr/bin/perl

$infile = shift;
$start_date = shift;
$dt = shift; # dt in hours

@month_days = (31,28,31,30,31,30,31,31,30,31,30,31);

# Parse start date
($start_year,$start_month,$start_day) = split /-/, $start_date;

# Initialize date
$year = $start_year;
$month = $start_month;
$day = $start_day;
$hour = 0; # Assume we start at hour 0

# Read input file
open (FILE,$infile) or die "$0: Error: cannot open $infile\n";
foreach (<FILE>) {

  chomp;
  s/^\s+//;
  @data = split /\s+/;
  printf "%04d %02d %02d", $year, $month, $day;
  if ($dt < 24) {
    printf " %02d", $hour;
  }
  for ($i=0; $i<=$#data; $i++) {
    printf " %.6f", $data[$i];
  }
  print "\n";

  # Increment date
  $days_in_month = $month_days[$month-1];
  if ($month == 2 and !($year % 4)) {
    $days_in_month++;
  }
  $hour += $dt;
  if ($hour > 23) {
    $hour = 0;
    $day++;
  }
  if ($day > $days_in_month) {
    $day = 1;
    $month++;
  }
  if ($month > 12) {
    $month = 1;
    $year++;
  }

}
close(FILE);
