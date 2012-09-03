#!/usr/bin/perl

@dates = (
"2009-01-19",
"2009-01-20",
"2009-01-21",
"2009-01-22",
"2009-01-23",
"2009-01-24",
"2009-01-25",
);
#@models = ("vic","clm","noah_2.8","sac","multimodel");
@models = ("multimodel");

foreach $date (@dates) {
  foreach $model (@models) {
    $cmd = "nowcast_model.pl conus $model stats,plots,depot $date";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
    $cmd = "nowcast_model.pl mexico $model stats,plots,depot $date";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
  }
}
