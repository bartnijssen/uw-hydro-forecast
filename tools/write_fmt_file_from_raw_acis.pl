#!/usr/bin/perl

use lib "/usr/lib/perl5/site_perl/5.6.1";
use Date::Calc qw(leap_year Days_in_Month Delta_Days Add_Delta_Days);

# Cmdline arguments
$raw_data_dir = shift;
$stn_list = shift;
$start_date = shift;
$end_date = shift;
$void = shift;
$pfmt = shift;
$txfmt = shift;
$tnfmt = shift;

# Read station list and initialize stn_info hash
open (STN, $stn_list) or die "$0: ERROR: cannot open station list $stn_list\n";
foreach (<STN>) {
  chomp;
  @fields = split /\s+/;
  $stn_info{$fields[3]}{P} = $void;
  $stn_info{$fields[3]}{TX} = $void;
  $stn_info{$fields[3]}{TN} = $void;
}
close(STN);

# Parse dates
($start_year,$start_month,$start_day) = split /-/, $start_date;
($end_year,$end_month,$end_day) = split /-/, $end_date;

# Open fmt files
open (PFMT, ">$pfmt") or die "$0: ERROR: cannot open p fmt file $pfmt for writing\n";
open (TXFMT, ">$txfmt") or die "$0: ERROR: cannot open tx fmt file $txfmt for writing\n";
open (TNFMT, ">$tnfmt") or die "$0: ERROR: cannot open tn fmt file $tnfmt for writing\n";

# Loop over files in raw_data_dir, appending to fmt files
$year = $start_year;
$month = $start_month;
$day = $start_day;
while (    $year < $end_year
       || ($year == $end_year && (    $month < $end_month
                                  || ($month == $end_month && $day <= $end_day) ) ) ) {

  # Re-initialize stn_info hash - this ensures that, if a station is missing from the
  # raw station file, we'll have a placeholder for it
  foreach $key (keys(%stn_info)) {
    $stn_info{$key}{P} = $void;
    $stn_info{$key}{TX} = $void;
    $stn_info{$key}{TN} = $void;
  }

  $filename = sprintf "stns.%04d%02d%02d.all.ymd", $year,$month,$day;
  open (FILE, "$raw_data_dir/$filename") or die "$0: ERROR: cannot open raw data file $raw_data_dir/$filename\n";
  foreach (<FILE>) {
    if (/^\d/) {
      @fields = split /\s+/;
      # Only store values if this station is on the list
      if ($stn_info{$fields[0]}{P} == $void) {
        $stn_info{$fields[0]}{P} = $fields[4];
        $stn_info{$fields[0]}{TX} = $fields[5];
        $stn_info{$fields[0]}{TN} = $fields[6];
      }
    }
  }
  close (FILE);
  $first = 1;
  foreach $key (sort(keys(%stn_info))) {
    if ($first) {
      printf PFMT "$stn_info{$fields[0]}{P}";
      printf TXFMT "$stn_info{$fields[0]}{TX}";
      printf TNFMT "$stn_info{$fields[0]}{TN}";
      $first = 0;
    }
    else {
      printf PFMT " $stn_info{$fields[0]}{P}";
      printf TXFMT " $stn_info{$fields[0]}{TX}";
      printf TNFMT " $stn_info{$fields[0]}{TN}";
    }
  }
  printf PFMT "\n";
  printf TXFMT "\n";
  printf TNFMT "\n";
  ($year,$month,$day) = Add_Delta_Days($year,$month,$day,1);

}
close (PFMT);
close (TXFMT);
close (TNFMT);
