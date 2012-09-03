#!/usr/bin/perl -w
use Date::Calc qw(Days_in_Month Delta_Days Add_Delta_Days);

# This does same thing as vicinput, but also adds wind avgs
# inputs:  Tmax & Tmin .grd file with values calculated in anom_meth/ dir by
#            anoms_2_vals.PNW_125.pl script
#          Pcp rescaled .rsc file calc'd by grd_monamt_2_dlyamt.pl, this dir.
#          .info/.xyz type file with desired averages to apply (for wind)
# outputs: vicinput tser files, ascii

# AWW-083003:  memory problems with crb 1/8 deg (6392 cell), 2.7 yr period
#              changed to read about 1 year at a time (366 days)
# AWW-103003:  modified to run over 5 basins in sequence
# AWW-1104:  modified for real-time updates, so don't need iterations.
#          also, appends to existing forcings, replacing recent ones.

# ------------- ARGUMENTS ----------------
($Fyr, $Fmon, $Fday) = ($ARGV[0],$ARGV[1],$ARGV[2]);
($Forc_Eyr, $Forc_Emon, $Forc_Eday) = ($ARGV[3],$ARGV[4],$ARGV[5]);
$RT_ForcDir = $ARGV[6];

$BAS = "US";
$BAS_CLUSTER = "conus";

# -------------------- files --------------
$PATH = "/raid8/forecast/sw_monitor/data/$BAS_CLUSTER/forcing/spinup";
$avgs = "$PATH/grd_info/met_means.$BAS.1915-2003"; # has wind field, fnames
$p_rsc = "$PATH/dly_append/tmpdat/p-dlyamt.$BAS.rsc";
$tx_grd = "$PATH/dly_append/tmpdat/tx.$BAS.grd";
$tn_grd = "$PATH/dly_append/tmpdat/tn.$BAS.grd";

# open files
open(AVGS, "<$avgs") or die "Can't open $avgs: $!\n";
open(P_RSC, "<$p_rsc") or die "Can't open $p_rsc: $!\n";
open(TXGRD, "<$tx_grd") or die "Can't open $tx_grd: $!\n";
open(TNGRD, "<$tn_grd") or die "Can't open $tn_grd: $!\n";

# read averages ---------------------------------------
print "reading average file\n";
@name = @pavg = @txavg = @tnavg = @wavg = ();
$c=0;
while (<AVGS>) {
  ($name[$c],$pavg[$c],$txavg[$c],$tnavg[$c],$wavg[$c]) = split;
  $c++;
}
close(AVGS);

# read in files
print "reading .grd/.rsc files\n";
$rec = 0;
@p = @tx = @tn = ();
while (<P_RSC>) {
  @tmp = split;
  for($c=0;$c<@tmp;$c++) {
    $p[$rec][$c] = $tmp[$c];
  }

  $line= <TXGRD>;
  @tmp = split(" ",$line);
  for($c=0;$c<@tmp;$c++) {
    $tx[$rec][$c] = $tmp[$c];
  }

  $line= <TNGRD>;
  @tmp = split(" ",$line);
  for($c=0;$c<@tmp;$c++) {
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

for($c=0;$c<@name;$c++) {
  $fname = $RT_ForcDir . $name[$c];
  open(FORC, "<$fname") or die "Can't open $fname: $!\n";

  $or=0;
  while(<FORC>) {
    ($op[$or],$otx[$or],$otn[$or],$ow[$or]) = split;
    $or++;
  }
  close(FORC);

  if($c==0) {   # figure out some dates
    $N_repl_days = $rec - Delta_Days($Forc_Eyr, $Forc_Emon, $Forc_Eday,
                                     $Fyr, $Fmon, $Fday);
  print STDERR "truncating $N_repl_days from forcings and then writing $rec days\n";
  }

  open(FORC, ">$fname") or die "Can't open $fname: $!\n";
  for($r=0;$r < ($or-$N_repl_days) ;$r++) {
    printf FORC "%.2f %.2f %.2f %.1f\n", $op[$r],$otx[$r],$otn[$r],$ow[$r];
  }

  for($nr=0;$nr<$rec;$nr++) {
    printf FORC "%.2f %.2f %.2f %.1f\n",
      $p[$nr][$c], $tx[$nr][$c], $tn[$nr][$c], $wavg[$c];
  }
  close(FORC);

}
close(P_RSC);
close(TXGRD);
close(TNGRD);
