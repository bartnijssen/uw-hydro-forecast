#!/usr/bin/env perl
use warnings;
use Date::Calc qw(Days_in_Month Delta_Days Add_Delta_Days);

# This script takes gridded forcings (image mode, i.e., for each time step,
# values for all grid cells are listed) and converts to ascii time series
# (i.e., for each grid cell, a time series is listed).
# inputs:  Tmax & Tmin .grd file with values calculated in anom_meth/ dir by
#            anoms_2_vals.PNW_125.pl script
#          Pcp rescaled .rsc file calc'd by grd_monamt_2_dlyamt.pl, this dir.
#          .info/.xyz type file with desired averages to apply (for wind)
# outputs: vicinput tser files, ascii
# ------------- ARGUMENTS ----------------
$p_rsc      = shift;
$tx_grd     = shift;
$tn_grd     = shift;
$Fyr        = shift;
$Fmon       = shift;
$Fday       = shift;
$Forc_Eyr   = shift;
$Forc_Emon  = shift;
$Forc_Eday  = shift;
$avgs       = shift;
$RT_ForcDir = shift;

# open files
open(AVGS,  "<$avgs")   or die "$0: ERROR: Cannot open $avgs: $!\n";
open(P_RSC, "<$p_rsc")  or die "$0: ERROR: Cannot open $p_rsc: $!\n";
open(TXGRD, "<$tx_grd") or die "$0: ERROR: Cannot open $tx_grd: $!\n";
open(TNGRD, "<$tn_grd") or die "$0: ERROR: Cannot open $tn_grd: $!\n";

# read averages ---------------------------------------
print "reading average file\n";
@name = @pavg = @txavg = @tnavg = @wavg = ();
$c = 0;
while (<AVGS>) {
  ($name[$c], $pavg[$c], $txavg[$c], $tnavg[$c], $wavg[$c]) = split;
  $c++;
}
close(AVGS);

# read in files
print "reading .grd/.rsc files\n";
$rec = 0;
@p = @tx = @tn = ();
while (<P_RSC>) {
  @tmp = split;
  for ($c = 0 ; $c < @tmp ; $c++) {
    $p[$rec][$c] = $tmp[$c];
  }
  $line = <TXGRD>;
  @tmp = split(" ", $line);
  for ($c = 0 ; $c < @tmp ; $c++) {
    $tx[$rec][$c] = $tmp[$c];
  }
  $line = <TNGRD>;
  @tmp = split(" ", $line);
  for ($c = 0 ; $c < @tmp ; $c++) {
    $tn[$rec][$c] = $tmp[$c];
  }
  $rec++;
}  # end while

# ==== now loop through and update forcing files ====================
# NOTE:  updates go back and overwrite the last (1-2) per(s)-worth of forcings
#       this amount varies depending on the setting of $MinDays:
print "writing forcings\n";

# actions:  -read prev. forc in up to date when they're replaced
#           -close file, and reopen for writing
#           -rewrite previous up to point where replacement starts
#           -write replacement and new update data
for ($c = 0 ; $c < @name ; $c++) {
  $fname = "$RT_ForcDir/$name[$c]";
  open(FORC, "<$fname") or die "$0: ERROR: Cannot open $fname: $!\n";
  $or = 0;
  while (<FORC>) {
    ($op[$or], $otx[$or], $otn[$or], $ow[$or]) = split;
    $or++;
  }
  close(FORC);
  if ($c == 0) {  # figure out some dates
    $N_repl_days =
      $rec - Delta_Days($Forc_Eyr, $Forc_Emon, $Forc_Eday, $Fyr, $Fmon, $Fday);
    print STDERR
      "truncating $N_repl_days from forcings and then writing $rec days\n";
  }
  open(FORC, ">$fname") or die "$0: ERROR: Cannot open $fname: $!\n";
  for ($r = 0 ; $r < ($or - $N_repl_days) ; $r++) {
    printf FORC "%.2f %.2f %.2f %.1f\n", $op[$r], $otx[$r], $otn[$r], $ow[$r];
  }
  for ($nr = 0 ; $nr < $rec ; $nr++) {
    printf FORC "%.2f %.2f %.2f %.1f\n", $p[$nr][$c], $tx[$nr][$c],
      $tn[$nr][$c], $wavg[$c];
  }
  close(FORC);
}
close(P_RSC);
close(TXGRD);
close(TNGRD);
