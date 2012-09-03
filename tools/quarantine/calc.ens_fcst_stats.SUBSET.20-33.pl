#!/usr/bin/perl -w
# A. Wood Aug 2007

# calculate predicted daily SM & SWE and cumulative 3- and 6-month RO percentile
# after 1 month, 2 months, 3 months

#   taken prior to the current (latest) day, for all cells in a basin
# output format:  one row per cell
#   lon lat [smqnt at N future dates] [swe qnt at dates] [cum3mo RO qnt at dates]  [cum6mo RO ...]
#
#  NOTE:  supply climatology period for calculating percentiles.
#    Set start of climatology period so that accumulation periods do not
#    precede start of data.

# VERSION:  takes string of subset years (e.g., for ENSO) and uses those

use lib "/usr/lib/perl5/site_perl/5.6.1";
use Date::Calc qw(leap_year Days_in_Month Delta_Days Add_Delta_Days Add_Delta_YM);
use Statistics::Lite ("mean");

# LAST:  (1) could handle sm & swe separately, since don't need their spinup...will cut down on memo
#        (2) also, could read only the part of the spinup fluxes needed to calculate the cumulative variables.

# Note: probability outputs are for top N-1 quantiles (bottom one is remainder)


#----------------------------------------------------------------------------------------------
# Determine tools, root, and config directories - assume this script lives in TOOLS_DIR/
#----------------------------------------------------------------------------------------------
if ($0 =~ /^(.+)\/[^\/]+$/) {
  $TOOLS_DIR = $1;
}
elsif ($0 =~ /^[^\/]+$/) {
  $TOOLS_DIR = ".";
}
else {
  die "$0: ERROR: cannot determine tools directory\n";
}
if ($TOOLS_DIR =~ /^(.+)\/tools/i) {
  $ROOT_DIR = $1;
}
else {
  $ROOT_DIR = "$TOOLS_DIR/..";
}
$CONFIG_DIR = "$ROOT_DIR/config";

#----------------------------------------------------------------------------------------------
# Include external modules
#----------------------------------------------------------------------------------------------
# Subroutine for reading config files
require "/raid8/forecast/sw_monitor/tools/simma_util.pl";

# Date arithmetic
use Date::Calc qw(Days_in_Month Delta_Days Add_Delta_Days);




# ---------- ARGS ----------------------------
if(@ARGV != 10) {
  die "Usage:  calc.ens_fcst_stats.SUBSET.pl <YYYY> <MM> <DD> <Clim_Syr> <Clim_Eyr> <Flist> <NearRTDir> <RTDir> <EspDir> <Model>\n";
} 


$Cyr = "$ARGV[0]";
$Cmon = "$ARGV[1]";
$Cday = "$ARGV[2]";
$datestr = sprintf("%04d%02d%02d",$Cyr,$Cmon,$Cday);

# ---------- SETTINGS ------------------------------
@PER = (1, 2, 3);  # calculation intervals, in months
@LIM = (0.20, 0.33);  # probability category bounds (i.e., terciles)
@QNT = (0, 0.25, 0.50, 0.75, 1); # i.e., min, 0.25, 0.50, 0.75, max
#@SUBSET_YRS = (1961, 1964, 1967, 1970, 1971, 1973, 1974, 1975, 1983, 1984, 1988, 1995, 1998, 1999);
#@SUBSET_YRS = (1950, 1954, 1955, 1956, 1964, 1967, 1970, 1971, 1973, 1974, 1975, 1983, 1984, 1988, 1995, 1998, 1999, 2000);  # for fall start
#@SUBSET_YRS = (1951, 1955, 1956, 1957, 1965, 1968, 1971, 1972, 1974, 1975, 1976, 1984, 1985, 1989, 1996, 1999, 2000, 2001);  # for spring start
#@SUBSET_YRS = (1971, 1972, 1974, 1975, 1976, 1984, 1985, 1989, 1996, 1999, 2000);  # for spring start
#@SUBSET_YRS = (1951, 1957, 1963, 1965, 1968, 1972, 1976, 1977, 1982, 1986, 1987, 1991, 1994, 1997, 2002, 2004); ## CPC list of Elnino years
#@SUBSET_YRS = (1951, 1957, 1963, 1965, 1968, 1972, 1976, 1977, 1982, 1986, 1987, 1991, 1994, 1997, 2002);
@SUBSET_YRS = (1964, 1966, 1969, 1970, 1973, 1977, 1978, 1983, 1987, 1988, 1992, 1995, 1998); ### CPC list of Elnino years## Updated by Shrad in Jan 10
# NB these start in autumn, using year previous to winter of la nina; update in Jan
$Void = -99.0;
$VARS = 4;
$NENS = @SUBSET_YRS;

$Clim_Syr = "$ARGV[3]";
$Clim_Eyr = "$ARGV[4]";
$Flist  = "$ARGV[5]";
$NearRTDir = "$ARGV[6]";
$RTDir = "$ARGV[7]";
$EspDir = "$ARGV[8]";
$MODEL = "$ARGV[9]";
$FutDir = "$EspDir/temp/";
$FutArchive = "$EspDir/saved/$MODEL/$datestr/";
# next file has sorted climatologies for three variables:  cum_ro, sm, swe
$ClimDist_Fl = "$EspDir/xyzz/$datestr/wb_vals.CLIM.$MODEL.$datestr.xyzz";
$Outfl  = "$EspDir/xyzz/$datestr/wb_qnts.ENS.SUBSET.$MODEL.$datestr.xyzz";
$Outfl2 = "$EspDir/xyzz/$datestr/wb_prob.ENS.20-33.SUBSET.$MODEL.$datestr.xyzz";
$NCLIM = $Clim_Eyr-$Clim_Syr+1;

# Read project configuration info
# Read model configuration info
$ConfigModel = "$CONFIG_DIR/config.model.$MODEL";
$var_info_model_ref = &read_config($ConfigModel);
%var_info_model = %{$var_info_model_ref};
$SMCOL_LIST = $var_info_model{"SMCOL"};
@SMCols = split /,/, $SMCOL_LIST;
$ROCOL_LIST = $var_info_model{"ROCOL"};
@ROCols = split /,/, $ROCOL_LIST;
$SWECol = $var_info_model{"SWECOL"};
$STOTCol = $var_info_model{"STOTCOL"};


# read file/station list ----------------------
@cell = `cat $Flist`;
chomp(@cell);
$Ncells = @cell;
#$Ncells = 10; # for testing

# ----------- get climatology data ----------------------------
# sorted variables for each runoff period calculated by script: 'calc.per_stats.clim.pl'
# NOTE:  file list and clim. dist. MUST have same order
open(FL, "<$ClimDist_Fl") or die "can't open $ClimDist_Fl: $!\n";
$c=0;
@lon = @lat = @climdist = ();
while(<FL>) {
  @tmp = ();
  ($lon[$c],$lat[$c],@tmp) = split;
  if(scalar(@tmp) != $NCLIM*$VARS*scalar(@PER)) {
    printf "retro distribution have %d elements, need %d\n", scalar(@tmp),$NCLIM*$VARS*@PER;
    die;
  }
  for($v=0;$v<$VARS;$v++) {  # v:  0=sm; 1=swe; 2=cum6ro; 3=cum3ro;
    for($p=0;$p<@PER;$p++) {  # periods
      for($e=0;$e<$NCLIM;$e++) {
        $climdist[$c][$v][$p][$e] = $tmp[($v*@PER+$p)*$NCLIM + $e];
      }
    }
  }
  $c++;  # cell counter
}

# check adequacy, potential overlap of near RT and RT data records ---------------
# also record ending record for spinup
$r = 0;
open(FL, "<$NearRTDir/$cell[0]") or die "can't open $NearRTDir/$cell[0]: $!\n";
while(<FL>) {
  ($yr[$r],$mo[$r],$dy[$r],@tmp) = split;
  $r++;
}
close(FL);
$rt_skip = 0;  # counter and skip any overlapping days between near RT and RT
open(FL, "<$RTDir/$cell[0]") or die "can't open $RTDir/$cell[0]: $!\n";
while(<FL>) {
  ($yy,$mm,$dd,@tmp) = split;
  if(Delta_Days($yr[$r-1],$mo[$r-1],$dy[$r-1],$yy,$mm,$dd) < 1) {
    $rt_skip++;  # read an overlapping day
  } else {
    ($yr[$r],$mo[$r],$dy[$r]) = ($yy, $mm, $dd);
    if($yy == $Cyr && $mm == $Cmon && $dd == $Cday) {
      $fut_rec_start = $r;  # save so that future portion of fcsts can be re-read
    }                       #   while looping through ensembles
    $r++;
  }
}
close(FL);
($yr0, $mon0, $day0) = ($yr[0],$mo[0],$dy[0]);  # data start date

# ====== make matrix of start & end dates for all periods desired ========
print "making matrix of start & end records for accumulations periods\n";

# start & end records for FUTURE period accumulations -------------
# future period starts *after* current day
for($p=0;$p<@PER;$p++) {
  ($tyr, $tmo, $tdy) = Add_Delta_YM($Cyr, $Cmon, $Cday, 0, $PER[$p]-6); # start of 3 mon per
  ($ty, $tm, $td) = Add_Delta_Days($tyr, $tmo, $tdy, 1); # move forward 1 day
  $recbnd1a[$p] = Delta_Days($yr0,$mon0,$day0,$ty, $tm, $td);
  ($tyr, $tmo, $tdy) = Add_Delta_YM($Cyr, $Cmon, $Cday, 0, $PER[$p]-3); # start of 3 mon per
  ($ty, $tm, $td) = Add_Delta_Days($tyr, $tmo, $tdy, 1); # move forward 1 day
  $recbnd1b[$p] = Delta_Days($yr0,$mon0,$day0,$ty, $tm, $td);
  ($tyr, $tmo, $tdy) = Add_Delta_YM($Cyr, $Cmon, $Cday, 0, $PER[$p]);
  $recbnd2[$p] = Delta_Days($yr0,$mon0,$day0,$tyr, $tmo, $tdy); # end of 3 mon period

#  if($recbnd2[$ny][$p]<0 || $recbnd1[$ny][$p]<0 ||
#     $recbnd2[$ny][$p]>=$datarecs || $recbnd1[$ny][$p]>=$datarecs) {
#    die "ERROR:  accum. period exceeds data bounds -- check climatology period\n";
#  }
}

# check matrix by printing out -------
#for($y=0;$y<=$ny;$y++) {
#  printf "%d\t",$Clim_Syr+$y;
#  for($p=0;$p<@PER;$p++) {
#    printf "%d %d\t",$recbnd1[$y][$p], $recbnd2[$y][$p];
#  }
#  printf "\n";
#}

# ========== loop through cells/stations and get recent data for each cell ============
#   this is later concatenated with future ensemble data iteratively
@qnt_ro_3 = @qnt_ro_6 = @qnt_sm = @qnt_swe = ();  # init. array to store data until final write
@ro = @all_sm = @all_swe = ();

for($c=0;$c<$Ncells;$c++) {
#  print "$c $cell[$c]\n";
  Read_Data_One_Cell_Spinup($c, $cell[$c], $rt_skip, \@ro, \@all_sm, \@all_swe);  # get data for one cell
} # finished working on climatology for all cells
print "read spinup data for $c cells\n";

# ============== loop through ensembles to get and analyze future data ======================

$dirname = $FutDir . "flux/";

for($e=0;$e<$NENS;$e++) {
  print "Ensemble: " . $SUBSET_YRS[$e] . " ------------------\n";

  # unpack ensemble data
  $fname = $FutArchive . "fluxes." . $SUBSET_YRS[$e] . "pnw.tar.gz";
  system("rm -R $dirname");
  `tar -xzf $fname -C $FutDir`;
  system("tar -xzf $fname -C $FutDir");

  # now loop through the forecasts for each cell and append them to climatology
  # each new forecast overwrites old forecast, but spinup part of arrays doesn't change

  for($c=0;$c<$Ncells;$c++) {
#    print "$c $cell[$c]\n";

    $name = $FutDir . "flux/pnw" . $cell[$c];
    Read_Data_One_Cell_Fut($c, $name, $fut_rec_start, \@ro, \@all_sm, \@all_swe);  # get data for one cell
  }
  print "read future data for $c cells\n";

  # done reading all data - now loop through cells for this ensemble and calculate and store percentiles
  for($c=0;$c<$Ncells;$c++) {
    # get accumulations for future periods
    for($p=0;$p<@PER;$p++) {  # work backward, adding rest of periods
      $cum_ro_6 = 0;
      for($r=$recbnd1a[$p];$r<$recbnd2[$p];$r++) {
#        if(!(defined($ro[$c][$r]))) {
#          print "something undefined\n";
#        }
        $cum_ro_6 += $ro[$c][$r];
      }
      $cum_ro_3 = 0;
      for($r=$recbnd1b[$p];$r<$recbnd2[$p];$r++) {
        $cum_ro_3 += $ro[$c][$r];
      }
      $sm = $all_sm[$c][$r-1];    # note $r now = $recbnd2[$y][$p]
      $swe = $all_swe[$c][$r-1];  # need to decrement by 1

      # ------------- calc percentile, store results for this ensemble ------------------
      @tmp=();
      for($y=0;$y<$NCLIM;$y++) {
        $tmp[$y] = $climdist[$c][0][$p][$y];  # SM
      }
      $qnt_sm[$e][$c][$p] = F_given_val($sm, \@tmp);

      @tmp=();
      for($y=0;$y<$NCLIM;$y++) {
        $tmp[$y] = $climdist[$c][1][$p][$y];  # SWE
      }
      $qnt_swe[$e][$c][$p] = F_given_val($swe, \@tmp);

      @tmp=();
      for($y=0;$y<$NCLIM;$y++) {
        $tmp[$y] = $climdist[$c][2][$p][$y];  # CUMUL RO 6
      }
      $qnt_ro_6[$e][$c][$p] = F_given_val($cum_ro_6, \@tmp);

      @tmp=();
      for($y=0;$y<$NCLIM;$y++) {
        $tmp[$y] = $climdist[$c][3][$p][$y];  # CUMUL RO 3
      }
      $qnt_ro_3[$e][$c][$p] = F_given_val($cum_ro_3, \@tmp);

#      print "ens $e cell $c period $p qnts: $qnt_ro[$e][$c][$p] $qnt_sm[$e][$c][$p] $qnt_swe[$e][$c][$p]\n";
    } # end percentile period loop

  }  # end looping through stations/cells

} # end looping though ensembles

# ==================================================================================

# now calculate clim. percentiles of forecast quantile values:  min 0.25, 0.50, 0.75 max
# also calculate fraction of traces falling within various portions of clim. distribution
#   as set by @LIM array.  don't calculate first one (since it's 1-sum of the rest)

print  "calculating percentiles (bounds) for all cells...\n";
@bounds_ro_3_qnt = @bounds_ro_6_qnt = @bounds_sm_qnt = @bounds_swe_qnt = ();
@prob_return_ro_3 = @prob_return_ro_6 = @prob_return_sm = @prob_return_swe = ();

for($c=0;$c<$Ncells;$c++) {
  for($p=0;$p<@PER;$p++) {  # loop through accum periods

    # ------- sm ---------
    @tmp = ();
    for($b=0;$b<@LIM;$b++) {
      $prob_return_sm[$c][$p][$b] = 0;  # initialize
    }
    for($e=0;$e<$NENS;$e++) {
      $tmp[$e] = $qnt_sm[$e][$c][$p];
      # calculate probability of being between 2 bounds, e.g, middle tercile, at a forecast date
      for($b=0;$b<@LIM-1;$b++) {
        if($tmp[$e] >= $LIM[$b] && $tmp[$e] <= $LIM[$b+1]) {
          $prob_return_sm[$c][$p][$b]++;
        }
      }
      if($tmp[$e] > $LIM[$b]) {  # highest boundary
        $prob_return_sm[$c][$p][$b]++;
      }
    }
    for($b=0;$b<@LIM;$b++) {
      if($prob_return_sm[$c][$p][$b] > 0) {
        $prob_return_sm[$c][$p][$b] /= $NENS;
      }
    }
    for($q=0;$q<@QNT;$q++) {
      $bounds_sm_qnt[$q][$c][$p] = val_given_F($QNT[$q], \@tmp);
    }

    # ------- swe ---------
    @tmp = ();
    for($b=0;$b<@LIM;$b++) {
      $prob_return_swe[$c][$p][$b] = 0;  # initialize
    }
    for($e=0;$e<$NENS;$e++) {
      $tmp[$e] = $qnt_swe[$e][$c][$p];
      # calculate probability of being between 2 bounds, e.g, middle tercile, at a forecast date
      for($b=0;$b<@LIM-1;$b++) {
        if($tmp[$e] >= $LIM[$b] && $tmp[$e] <= $LIM[$b+1]) {
          $prob_return_swe[$c][$p][$b]++;
        }
      }
      if($tmp[$e] > $LIM[$b]) {  # highest boundary
        $prob_return_swe[$c][$p][$b]++;
      }
    }
    for($b=0;$b<@LIM;$b++) {
      if($prob_return_swe[$c][$p][$b] > 0) {
        $prob_return_swe[$c][$p][$b] /= $NENS;
      }
    }
    for($q=0;$q<@QNT;$q++) {
      $bounds_swe_qnt[$q][$c][$p] = val_given_F($QNT[$q], \@tmp);
    }

    # ------- ro 6 mon ---------
    @tmp=();
    for($b=0;$b<@LIM;$b++) {
      $prob_return_ro_6[$c][$p][$b] = 0;  # initialize
    }
    for($e=0;$e<$NENS;$e++) {
      $tmp[$e] = $qnt_ro_6[$e][$c][$p];
      # calculate probability of being between 2 bounds, e.g, middle tercile, at a forecast date
      for($b=0;$b<@LIM-1;$b++) {
        if($tmp[$e] >= $LIM[$b] && $tmp[$e] <= $LIM[$b+1]) {
          $prob_return_ro_6[$c][$p][$b]++;
        }
      }
      if($tmp[$e] > $LIM[$b]) {  # highest boundary
        $prob_return_ro_6[$c][$p][$b]++;
      }
    }
    for($b=0;$b<@LIM;$b++) {
      if($prob_return_ro_6[$c][$p][$b] > 0) {
        $prob_return_ro_6[$c][$p][$b] /= $NENS;
      }
    }
    for($q=0;$q<@QNT;$q++) {
      $bounds_ro_6_qnt[$q][$c][$p] = val_given_F($QNT[$q], \@tmp);
    }

    # ------- ro 3 mon ---------
    @tmp=();
    for($b=0;$b<@LIM;$b++) {
      $prob_return_ro_3[$c][$p][$b] = 0;  # initialize
    }
    for($e=0;$e<$NENS;$e++) {
      $tmp[$e] = $qnt_ro_3[$e][$c][$p];
      # calculate probability of being between 2 bounds, e.g, middle tercile, at a forecast date
      for($b=0;$b<@LIM-1;$b++) {
        if($tmp[$e] >= $LIM[$b] && $tmp[$e] <= $LIM[$b+1]) {
          $prob_return_ro_3[$c][$p][$b]++;
        }
      }
      if($tmp[$e] > $LIM[$b]) {  # highest boundary
        $prob_return_ro_3[$c][$p][$b]++;
      }
    }
    for($b=0;$b<@LIM;$b++) {
      if($prob_return_ro_3[$c][$p][$b] > 0) {
        $prob_return_ro_3[$c][$p][$b] /= $NENS;
      }
    }
    for($q=0;$q<@QNT;$q++) {
      $bounds_ro_3_qnt[$q][$c][$p] = val_given_F($QNT[$q], \@tmp);
    }
  }
}

# ========================================================================

# ---- now write out format file --------------------------
#$Outfl = "/raid/forecast/sw_monitor/output/ESP/analysis/$datestr/wb_qnts.xyzz";
open(OUT, ">$Outfl") or die "can't open $Outfl: $!\n";
open(OUT2, ">$Outfl2") or die "can't open $Outfl2: $!\n";
print "writing...\n";

for($c=0;$c<$Ncells;$c++) {
#  @tmp = split("_",$cell[$c]);
  printf OUT "%.4f %.4f   ", $lon[$c],$lat[$c];
  printf OUT2 "%.4f %.4f   ", $lon[$c],$lat[$c];

  for($p=0;$p<@PER;$p++) {  # loop through accum periods
    for($q=0;$q<@QNT;$q++) {
      printf OUT "%6.3f ", $bounds_sm_qnt[$q][$c][$p];
    }
    printf OUT "  ";
    for($b=0;$b<@LIM;$b++) {
      printf OUT2 "%6.1f ", $prob_return_sm[$c][$p][$b]*100;
    }
  }
  printf OUT "    ";
  printf OUT2 "  ";

  for($p=0;$p<@PER;$p++) {  # loop through accum periods
    for($q=0;$q<@QNT;$q++) {
      printf OUT "%6.3f ", $bounds_swe_qnt[$q][$c][$p];
    }
    printf OUT "  ";
    for($b=0;$b<@LIM;$b++) {
      printf OUT2 "%6.1f ", $prob_return_swe[$c][$p][$b]*100;
    }
  }
  printf OUT "    ";
  printf OUT2 "  ";

  for($p=0;$p<@PER;$p++) {  # loop through accum periods
    for($q=0;$q<@QNT;$q++) {
      printf OUT "%6.3f ", $bounds_ro_6_qnt[$q][$c][$p];
    }
    printf OUT "  ";
    for($b=0;$b<@LIM;$b++) {
      printf OUT2 "%6.1f ", $prob_return_ro_6[$c][$p][$b]*100;
    }
  }
  printf OUT "    ";
  printf OUT2 "  ";

  for($p=0;$p<@PER;$p++) {  # loop through accum periods
    for($q=0;$q<@QNT;$q++) {
      printf OUT "%6.3f ", $bounds_ro_3_qnt[$q][$c][$p];
    }
    printf OUT "  ";
    for($b=0;$b<@LIM;$b++) {
      printf OUT2 "%6.1f ", $prob_return_ro_3[$c][$p][$b]*100;
    }
  }
  printf OUT "\n";
  printf OUT2 "\n";

}
close(OUT);
close(OUT2);


# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#                                    SUBROUTINES
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# subroutine to read recent data from one cell, uses global vars for directory names
sub Read_Data_One_Cell_Spinup {
  ($c, $cname, $skip_rec, $ro_ref, $sm_ref, $swe_ref) = @_;

  $r=0;
  open(FL, "<$NearRTDir/$cname") or die "can't open $NearRTDir/$cname: $!\n";
  while(<FL>) {
    @tmp = split;
    $ro_ref->[$c][$r]  = $tmp[5]+$tmp[6];
    $sm_ref->[$c][$r]  = $tmp[8]+$tmp[9]+$tmp[10];  # reference this way to pass back values
    $swe_ref->[$c][$r] = $tmp[11];  # reference this way to pass back values
    $r++;
  }
  close(FL);
  $cnt=0;
  open(FL, "<$RTDir/$cname") or die "can't open $RTDir/$cname: $!\n";
  while(<FL>) {
    if($cnt>=$skip_rec) {
      @tmp = split;
      $ro_ref->[$c][$r]  = $tmp[5]+$tmp[6];
      $sm_ref->[$c][$r]  = $tmp[8]+$tmp[9]+$tmp[10];  # reference this way to pass back values
      $swe_ref->[$c][$r] = $tmp[11];  # reference this way to pass back values
      $r++;
    } else {
      $cnt++;
    }
  }
  close(FL);
}

# just adds to and later rewrite future part of cell data arrays
# the same arrays contain both clim and future data to facilitate cumulative
#   variable calculations
sub Read_Data_One_Cell_Fut {
  ($c, $cname,  $startrec, $ro_ref, $sm_ref, $swe_ref) = @_;

  $r=$startrec;
  open(FL, "<$cname") or die "can't open $cname: $!\n";
  while(<FL>) {
    @tmp = split;
    $ro_ref->[$c][$r] = $tmp[5]+$tmp[6];
    $sm_ref->[$c][$r] = $tmp[8]+$tmp[9]+$tmp[10];  # reference this way to pass back values
    $swe_ref->[$c][$r] = $tmp[11];  # reference this way to update values in main prog
    $r++;
  }
  close(FL);
}

# set sort logic
sub numer { $a <=> $b; }

# given an unsorted array and value, return the associated non-exceed. %-ile.
# not much checking in here
sub F_given_val {
  # allows crude percentile extrapolation; returns void for zero distrib.
  my ($val, $array_ref) = @_;
  @array = @$array_ref;
  $LEN = @array;  # dimension of array
  $min_p = 1/($LEN+1)*0.5;  # def. p-val for targ below dist
  $max_p = $LEN/($LEN+1) + $min_p;  # ditto for above dist

  # sort array (using logic set in other subroutine)
  #print "F_given_val: val=$val\n";
  @srt_arr = sort numer @array;

  # trap all-zero case, e.g., for swe
  if( (mean @srt_arr) == 0) {
    return $Void;
  }

  $i=0;
  while($i < $LEN) {
    if($srt_arr[$i]>=$val && $i==0) {
      # handles zero precip case, but gives lowest percentile (!!)
      $qnt = $min_p;
      last;
    } elsif ($srt_arr[$i] < $val && $i==$LEN-1) {
      $qnt = $max_p;
      last;
    } elsif ($srt_arr[$i]>=$val) {
      # note, i as counter in qnt eq. must start at 1 not 0
      # whereas in arrays, starts at 0
      $qnt = ($val-$srt_arr[$i-1]) / ($srt_arr[$i]-$srt_arr[$i-1]) *
        (($i+1)/($LEN+1) - $i/($LEN+1)) + $i/($LEN+1);
      last;
    }
    $i++;
    }  # done calc'ing percentiles

  return $qnt;
  }

# given an unsorted array and non-exceed. %-ile, return the associated value.
# note, giving F=0 returns minimum value and F=1 returns maximum value
sub val_given_F {
  my ($qnt, $array_ref) = @_;
  @array = @$array_ref;
  $LEN = @array;  # dimension of array
  $val = 0;

  # sort array (using logic set in other subroutine)
  @srt_arr = sort numer @array;

  # trap all-zero case, e.g., for swe
  if( (mean @srt_arr) == 0) {
    return $Void;
  }

  for($i=0;$i<$LEN;$i++) {  # nonexceed. prob arrays go low to high
    $weib[$i] = ($i+1)/($LEN+1);
  }
  # check for sample size problems (no extrapolation allowed) or default F values
  if($qnt == 0) {
    return $srt_arr[0];

  } elsif ($qnt == 1.0) {
    return $srt_arr[$LEN-1];

  } elsif ($weib[0] > $qnt || $weib[$LEN -1] < $qnt) {
    printf STDERR "array too small for quant. calc; need larger sample or diff. quant.\n";
    printf STDERR "qnt: $qnt   dist bounds: $weib[0], $weib[$LEN -1]\n";
    die;

  } else {

    # find interpolation weight and index of values to interpolate
    $ndx = $weight = 0;
    for($i=1;$i<$LEN;$i++) { # start from one, since no extrapolation
      if($weib[$i] >= $qnt) {
        #weight multiplies upper value, (1-weight) mult. lower value
        $weight = ($qnt-$weib[$i-1])/($weib[$i]-$weib[$i-1]);
        $ndx = $i-1; # lower one
        last;
      }
    }
    #  print "val_given_F: F=$qnt\n";
    # calculate quantile-associated value
    $val = $srt_arr[$ndx]*(1-$weight) + $srt_arr[$ndx+1]*($weight);
    return $val;

  }
}
