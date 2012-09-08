#!/usr/bin/env perl
use warnings;
# This script creates fmt file from the all time series of station obs between the given dates.
# This script assumes that a) no records are missing from the time series and b) the time series
# all contain the start date.

# Cmdline arguments
$stn_ts_dir = shift;
$stn_list = shift;
$start_date = shift;
$end_date = shift;
$pfmt = shift;
$txfmt = shift;
$tnfmt = shift;

# Parse dates
($start_year,$start_month,$start_day) = split /-/, $start_date;
($end_year,$end_month,$end_day) = split /-/, $end_date;

# Loop over files in stn_ts_dir, appending to fmt files
$nstn = 0;
$store = 0;
$nrecs_max = 0;
$first = 1;
open (STNLIST, "$stn_list") or die "$0: ERROR: cannot open station list file $stn_list for reading\n";
STN_LOOP: foreach (<STNLIST>) {
  if ($first) {
    $first = 0;
    next;
  }
  chomp;
  @fields = split /\s+/;
  $stn_data[$nstn] = $fields[3];
  open (FILE, "$stn_ts_dir/$stn_data[$nstn]") or die "$0: ERROR: cannot open station data file $stn_ts_dir/$stn_data[$nstn] for reading\n";
  $nrecs = 0;
  foreach $line (<FILE>) {
    chomp $line;
    if ($line =~ /^\d/) {
      ($year,$month,$day,$prcp,$tmax,$tmin) = split /\s+/, $line;
      if ($year*1 == $start_year*1 && $month*1 == $start_month*1 && $day*1 == $start_day*1) {
        $store = 1;
      }
      if ($store) {
        push @{$prcp_data{$stn_data[$nstn]}}, $prcp;
        push @{$tmax_data{$stn_data[$nstn]}}, $tmax;
        push @{$tmin_data{$stn_data[$nstn]}}, $tmin;
        $nrecs++;
      }
      if ($year == $end_year && $month == $end_month && $day == $end_day) {
        $store = 0;
	close(FILE);
	if ($nrecs > $nrecs_max) {
	  $nrecs_max = $nrecs;
	}
        $nstn++;
	next STN_LOOP;
      }
    }
  }
  close (FILE);
  $nstn++;
}
close (STNLIST);

# Open fmt files
open (PFMT, ">$pfmt") or die "$0: ERROR: cannot open p fmt file $pfmt for writing\n";
open (TXFMT, ">$txfmt") or die "$0: ERROR: cannot open tx fmt file $txfmt for writing\n";
open (TNFMT, ">$tnfmt") or die "$0: ERROR: cannot open tn fmt file $tnfmt for writing\n";

# Loop over data & write to fmt files
for ($i==0; $i<$nrecs; $i++) {
  $first = 1;
  for ($n=0; $n<$nstn; $n++) {
    if ($first) {
      printf PFMT "${$prcp_data{$stn_data[$n]}}[$i]";
      printf TXFMT "${$tmax_data{$stn_data[$n]}}[$i]";
      printf TNFMT "${$tmin_data{$stn_data[$n]}}[$i]";
      $first = 0;
    }
    else {
      printf PFMT " ${$prcp_data{$stn_data[$n]}}[$i]";
      printf TXFMT " ${$tmax_data{$stn_data[$n]}}[$i]";
      printf TNFMT " ${$tmin_data{$stn_data[$n]}}[$i]";
    }
  }
  printf PFMT "\n";
  printf TXFMT "\n";
  printf TNFMT "\n";
}
close (PFMT);
close (TXFMT);
close (TNFMT);
