#!/usr/bin/perl

use lib "/usr/lib/perl5/site_perl/5.6.1";
use Date::Calc qw(leap_year Days_in_Month Delta_Days Add_Delta_Days);

# Cmdline arguments
$raw_data_dir = shift;
$stn_list = shift;
$listed_stns_only = shift; # 0 = update files for all stations found in the download file; 1 = only update stations listed in the station list
$start_date = shift;
$end_date = shift;
$nodata = shift;
$out_dir = shift;

# Read station list and initialize stn_info hash
$n = 0;
open (STN, $stn_list) or die "$0: ERROR: cannot open station list $stn_list\n";
foreach (<STN>) {
  chomp;
  @fields = split /\s+/;
  if (@fields >= 4) {
    $station[$n] = $fields[3];
    $n++;
  }
}
close(STN);
$nStn = $n;

# Parse dates
($start_year,$start_month,$start_day) = split /-/, $start_date;
($end_year,$end_month,$end_day) = split /-/, $end_date;

# Loop over files in raw_data_dir, appending to station files
$year = $start_year;
$month = $start_month;
$day = $start_day;
while (    $year < $end_year
       || ($year == $end_year && (    $month < $end_month
                                  || ($month == $end_month && $day <= $end_day) ) ) ) {

  $filename = sprintf "stns.%04d%02d%02d.all.ymd", $year,$month,$day;
  open (FILE, "$raw_data_dir/$filename") or die "$0: ERROR: cannot open raw data file $raw_data_dir/$filename\n";
  $n=0;
  FILE_LOOP: foreach (<FILE>) {
    if (!/^\d/) {
      next FILE_LOOP;
    }
    chomp;
    @fields = split /\s+/;
    if ($fields[4] != $nodata) {
      $fields[4] *= 25.4;
    }
    if ($fields[5] != $nodata) {
      $fields[5] = ($fields[5]-32)*5/9;
    }
    if ($fields[6] != $nodata) {
      $fields[6] = ($fields[6]-32)*5/9;
    }
    if (!$listed_stns_only) {
      open (STN, ">>$out_dir/$fields[0]") or die "$0: ERROR: cannot open station file $out_dir/$fields[0] for appending\n";
      printf STN "%04d %02d %02d %.2f %.2f %.2f\n", $fields[1], $fields[2], $fields[3], $fields[4], $fields[5], $fields[6];
      close (STN);
    }
    else {
      if ($fields[0] == $station[$n]) {
        open (STN, ">>$out_dir/$station[$n]") or die "$0: ERROR: cannot open station file $out_dir/$station[$n] for appending\n";
        printf STN "%04d %02d %02d %.2f %.2f %.2f\n", $fields[1], $fields[2], $fields[3], $fields[4], $fields[5], $fields[6];
        close (STN);
        $n++;
      }
      elsif ($fields[0] < $station[$n]) {
        next FILE_LOOP;
      }
      else {
        open (STN, ">>$out_dir/$station[$n]") or die "$0: ERROR: cannot open station file $out_dir/$station[$n] for appending\n";
        printf STN "%04d %02d %02d %.2f %.2f %.2f\n", $year, $month, $day, $nodata, $nodata, $nodata;
        close (STN);
        $n++;
      }
      if ($n == $nStn) {
        last FILE_LOOP;
      }
    }
  }
  close (FILE);
  ($year,$month,$day) = Add_Delta_Days($year,$month,$day,1);

}
