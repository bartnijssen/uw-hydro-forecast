#!/usr/bin/perl

$project = shift;
$modellist = shift;
$start_date = shift;
$end_date = shift;
$results_subdir = shift;

@month_days = (31,28,31,30,31,30,31,31,30,31,30,31);
@models = split /,/, $modellist;
($year,$month,$day) = split /-/, $start_date;
($endyear,$endmonth,$endday) = split /-/, $end_date;
while ($year < $endyear || ($year == $endyear && ($month < $endmonth || ($month == $endmonth && $day <= $endday)))) { 

  foreach $model (@models) {
    $cmd = "get_stats.pl $model $project $year $month $day $results_subdir";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
    $cmd = "plot_qnts.pl $project $model $year $month $day";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
  }

  $days_in_month = $month_days[$month-1];
  if ($year % 4 == 0 && $month*1 == 2) {
    $days_in_month++;
  }
  $day++;
  if ($day > $days_in_month) {
    $day = 1;
    $month++;
    if ($month > 12) {
      $month = 1;
      $year++;
    }
  }

}
