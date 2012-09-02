#!/usr/bin/perl

@dates = (
"2008-12-15",
"2008-12-16",
"2008-12-17",
"2008-12-18",
"2008-12-19",
"2008-12-20",
"2008-12-21",
"2008-12-22",
"2008-12-23",
"2008-12-24",
"2008-12-25",
"2008-12-26",
"2008-12-27",
"2008-12-28",
"2008-12-29",
"2008-12-30",
"2008-12-31",
"2009-01-01",
"2009-01-02",
"2009-01-03",
"2009-01-04",
"2009-01-05",
"2009-01-06",
"2009-01-07",
"2009-01-08",
);
@models = ("vic","clm","noah_2.8","sac","multimodel");

foreach $date (@dates) {
  foreach $model (@models) {
    $cmd = "nowcast_model.pl mexico $model plots $date";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
  }
}
