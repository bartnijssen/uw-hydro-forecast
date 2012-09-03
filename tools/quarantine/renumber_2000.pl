#!/usr/bin/perl

$file = shift;

@month_days = (31,28,31,30,31,30,31,31,30,31,30,31);

$month = 1;
$day = 1;
$found = 0;
open (FILE, $file) or die "$0: ERROR: cannot open $file for reading\n";
foreach (<FILE>) {

  chomp;
  @fields = split /\s+/;
  if (!$found) {
    $year = $fields[0];
  }

  if ($year >= 2000) {

    $found = 1;

    # Print record with new date
    printf "%04d %02d %02d", $year, $month, $day;
    for ($i=3; $i<@fields; $i++) {
      print " $fields[$i]";
    }
    print "\n";

    # Increment date by delta_days
    $day++;
    $days_in_month = $month_days[$month-1];
    if ($year % 4 == 0 && $month == 2) {
      $days_in_month++;
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

  else {
    print "$_\n";
  }

}
close(FILE);
