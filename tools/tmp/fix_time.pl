#!/usr/bin/perl

$file = shift;

@month_days = (31,28,31,30,31,30,31,31,30,31,30,31);

open(FILE,$file) or die "$0: ERROR: cannot open file $file\n";
$first = 1;
foreach (<FILE>) {

  chomp;
  @fields = split /\s+/;

  if ($first) {
    ($year,$month,$day) = @fields[0..2];
    $first = 0;
  }
  else {
    $day++;
    $days_in_month = @month_days[$month-1];
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

  printf "%04d %02d %02d 00", $year, $month, $day;
  for ($i=4; $i<@fields; $i++) {
    print " $fields[$i]";
  }
  print "\n";

}
closedir(FILE);
