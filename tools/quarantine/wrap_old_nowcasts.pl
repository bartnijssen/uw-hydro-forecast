#!/usr/bin/perl

$project = shift;
$model_list = shift;
$start_date = shift; # yyyy-mm-dd
$end_date = shift; # yyyy-mm-dd
$logfile = shift;

@month_days = (31,28,31,30,31,30,31,31,30,31,30,31);

@models = split /,/, $model_list;
($Syr,$Smon,$Sday) = split /-/, $start_date;
($Eyr,$Emon,$Eday) = split /-/, $end_date;

$year = $Syr;
$month = $Smon;
$day = $Sday;
while ($year < $Eyr || ($year == $Eyr && ($month < $Emon || $month == $Emon && $day <= $Eday))) {

  foreach $model (@models) {
    $cmd = "get_stats.pl $model $project $year $month $day >& $logfile.tmp; cat $logfile.tmp >> $logfile";
    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
    $cmd = "calc.cum_ro_qnts.pl $model $project $year $month $day >& $logfile.tmp; cat $logfile.tmp >> $logfile";
    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
    $cmd = "plot_qnts.pl $project $model $year $month $day >& $logfile.tmp; cat $logfile.tmp >> $logfile";
    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
  }

  $day++;
  $days_in_month = $month_days[$month-1];
  if ($year % 4 == 0 && $month == 2) {
    $days_in_month++;
  }
  if ($day > $days_in_month) {
    $day = 1;
    $month++;
    if ($month > 12) {
      $month = 1;
      $year++;
    }
  }
}
