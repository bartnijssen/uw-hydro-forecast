#!/usr/bin/env perl
use warnings;

# calculate values from anomalies given precalculated means
# inputs:  .grd file with anomalies in same column order as
#        .info/.xyz type file with desired averages to apply
# outputs: .grd file with values
#          vicinput files
# AWW-083003:  memory problems with crb 1/8 deg (6392 cell), 2.7 yr period
#              changed to read about 1 year at a time (366 days)
# AWW-103103:  modified to just write temperature grids, no precip or forcings
#              also to run a loop for all basins
# AWW-1104:  runs for just one basin, automatically, off args
#            needs no args. removed functionality for longer datasets
#            tailored for ps / pnw only
#use Date::Calc qw(Delta_Days);
use lib "<SYSTEM_PERL_LIB>";
use UWTime;

# command-line arguments
$tx_anom = shift;
$tn_anom = shift;
$avgs    = shift;
$tx_grd  = shift;
$tn_grd  = shift;
print "$0: - Avgs file is $avgs\n";

# open files
open(TXANOM, "<$tx_anom") or die "$0: ERROR: Cannot open $tx_anom: $!\n";
open(TNANOM, "<$tn_anom") or die "$0: ERROR: Cannot open $tn_anom: $!\n";
open(AVGS,   "<$avgs")    or die "$0: ERROR: Cannot open $avgs: $!\n";
open(TXGRD,  ">$tx_grd")  or die "$0: ERROR: Cannot open $tx_grd: $!\n";
open(TNGRD,  ">$tn_grd")  or die "$0: ERROR: Cannot open $tn_grd: $!\n";

# read averages ---------------------------------------
$c = 0;
while (<AVGS>) {
  ($name[$c], $junk, $txavg[$c], $tnavg[$c], $junk) = split;
  $c++;
}
close(AVGS);

# read in anomaly gridfiles ----------------
print "reading anomaly .grd files\n";
$rec = 0;
@txanom = @tnanom = ();
while (<TXANOM>) {
  @tmp = split;
  for ($c = 0 ; $c < @tmp ; $c++) {
    $txanom[$rec][$c] = $tmp[$c];
  }
  $line = <TNANOM>;         # same length as TXANOM, or this wouldn't work
  @tmp = split(" ", $line);
  for ($c = 0 ; $c < @tmp ; $c++) {
    $tnanom[$rec][$c] = $tmp[$c];
  }
  $rec++;
}  # end reading

# write out anomaly .grd files, handling voids (should be none)
print "writing value .grd files\n";
for ($r = 0 ; $r < $rec ; $r++) {
  for ($c = 0 ; $c < @name ; $c++) {
    printf TXGRD "%.2f ", $txanom[$r][$c] + $txavg[$c];
    printf TNGRD "%.2f ", $tnanom[$r][$c] + $tnavg[$c];
  }
  printf TXGRD "\n";
  printf TNGRD "\n";
}  # end reading & writing grids

#} # %%%%%% end iteration through chunks of data %%%%%%%%%%%%%%%%
close(TXANOM);
close(TNANOM);
close(TXGRD);
close(TNGRD);
