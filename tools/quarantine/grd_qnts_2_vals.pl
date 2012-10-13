#!<SYSTEM_PERL_EXE> -w
# AWW-1104
# transforming gridded MONTHLY quantiles to gridded values
# using existing 1/8-degree daily archive of forcings each grid cell
#   for precip only; note forcings have no VOIDS in them.
# inputs: monthly qnt. grid for spinup period data (cols=cells, 1 row per tstep)
#          monthly dist. file (one row per cell <mon1 dist><mon2 dist>
# output:  monthly amount grid for spinup data (rows=cells, cols=months)
#          note, this is transposed relative to the input qnt grid
# note, last month may be partial, so need to account for that AWW-013104
#use Date::Calc qw(Days_in_Month Delta_Days Add_Delta_Days leap_year);
use lib qw(<SYSTEM_INSTALLDIR>/lib <SYSTEM_PERL_LIBS>);
use UWTime;  # Use this for Days_In_Month
use Date::Manip;

# ------------- ARGUMENTS ----------------
$Fperqnt       = shift;  # input
$Syr           = shift;
$Smon          = shift;
$Fyr           = shift;
$Fmon          = shift;
$Fday          = shift;
$Clim_Syr      = shift;
$Clim_Eyr      = shift;
$RetroForcSyr  = shift;
$RetroForcSmon = shift;
$RetroForcSday = shift;
$RetroForcDir  = shift;
$DataFlist     = shift;
$Fperamt       = shift;  # output
open(OUT, ">$Fperamt") or die "$0: ERROR: Cannot open $Fperamt : $!\n";

# ===== open, read in obs recent quantiles ================
print "reading in observed monthly quantile tser\n";
open(INF, "<$Fperqnt") or die "$0: ERROR: Cannot open $Fperqnt : $!\n";
$nPer = 0;
while (<INF>) {
  @tmp = split;
  for ($c = 0 ; $c < @tmp ; $c++) {
    $perqnt[$nPer][$c] = $tmp[$c];
  }
  $nPer++;
}
close(INF);
print " In program $0\n";
print "Number of periods is $nPer\n";
print "RetroForcDir $RetroForcDir\n";
print "DataFlist $DataFlist\n";

# assign start & end dates to periods ----------------
#   NOTE:  must use different end dates in non-leap years, if em/ed=2/29
if ($nPer == 1) {

  # calc percentiles for just one period
  @sy     = ($Syr);
  @sm     = ($Smon);
  @sd     = (1);
  @ey     = ($Fyr);
  @em     = ($Fmon);
  @ed     = ($Fday);
  @daycnt = (Delta_Days($Syr, $Smon, 1, $Fyr, $Fmon, $Fday) + 1);
} else {

  # calc percentiles for 2 periods; first is one month long
  $S1 = $Syr . $Smon . "01";
  $S2 = DateCalc($S1, "+1 months", 0);
  ($S2yr, $S2mon, $S2day) = unpack "a4a2a2", $S2;
  $S2day = 1;
  print "Period 2 starts at $S2\n";
  @sy = ($Syr,  $S2yr);
  @sm = ($Smon, $S2mon);
  @sd = (1, 1);
  @ey = ($Syr,  $Fyr);
  @em = ($Smon, $Fmon);
  @ed = (Days_In_Month($Syr, $Smon), $Fday);
  @daycnt = (
             Delta_Days(
                        $Syr, $Smon, 1, $Syr, $Smon, Days_In_Month($Syr, $Smon)
               ) + 1,
             Delta_Days($S2yr, $S2mon, 1, $Fyr, $Fmon, $Fday) + 1
            );
}
print "Daycnt is @daycnt\n";

# ===== open, read in flux file list ================
print "reading in data file list $DataFlist\n";
@flist = `cat $DataFlist`;
chomp(@flist);

# %%%%%%%%%%%%%% loop through gridcells %%%%%%%%%%%%%%%%%%%%%%%%
for ($c = 0 ; $c < @flist ; $c++) {

  # read in retrospective forcings data
  open(RETRO, "<$RetroForcDir/$flist[$c]") or
    die "$0: ERROR: cannot open $RetroForcDir/$flist[$c]: $!\n";
  $r = 0;
  while (<RETRO>) {
    ($p[$r], @tmp) = split;
    $r++;
  }
  close(RETRO);

  # calculate dates of retrospective forcings
  if ($c == 0) {
    ($y[0], $m[0], $d[0]) = ($ly, $lm, $ld) =
      ($RetroForcSyr, $RetroForcSmon, $RetroForcSday);
    for ($n = 0 ; $n < $r - 1 ; $n++) {
      ($y[$n + 1], $m[$n + 1], $d[$n + 1]) = Add_Delta_Days($ly, $lm, $ld, 1);
      ($ly, $lm, $ld) = ($y[$n + 1], $m[$n + 1], $d[$n + 1]);
    }
  }

  # loop through periods (1 or 2) -------------------------------
  for ($per = 0 ; $per < @sm ; $per++) {

    # get TOTALS, sorted clim for period
    $flag = $cntper = 0;
    @clim_pav = ();
    for ($r = 0 ; $r < @p ; $r++) {
      if ($y[$r] >= $Clim_Syr && $y[$r] <= $Clim_Eyr) {  # in clim period
        if ($m[$r] == $sm[$per] && $d[$r] == $sd[$per]) {
          $flag    = 1;       # in desired daily-period
          $tmp_sum = $p[$r];  # inits var clim_pav[]
        } elsif ($flag == 1) {  # in calendar period
          $tmp_sum += $p[$r];
        }

        # check for end date
        # NOTE: if one of the end dates is feb29, use mar1 in non-leap years
        if ($em[$per] == 2 && $ed[$per] == 29 && !(leap_year($y[$r]))) {
          $tmp_em = 3;
          $tmp_ed = 1;
        } else {
          $tmp_em = $em[$per];
          $tmp_ed = $ed[$per];
        }
        if ($m[$r] == $tmp_em && $d[$r] == $tmp_ed && $flag == 1)
        {  # end cal period
          $clim_pav[$cntper] = $tmp_sum;
          $flag = 0;
          $cntper++;
        }
      }  # end IF within clim totalling period
    }  # end reading through clim data for current station
    if ($cntper < 1) {
      print "WARNING!!\n";
      print "cntper is $cntper - you have NO DATA for r $r\n";
    }

    # get value from looking up percentile in distribution
    #    print STDERR "cell $c per $per qnt $perqnt[$per][$c]\n";
    unless (defined $perqnt[$per][$c]) {
      print "WARNING!!!! GRD_QNTS_VALS\n";
      print "PASSING undef perqnt at per $per c $c\n";
    }

    #    if ( $#clim_pavg < 2 ){
    #      print "WARNING!!!! GRD_QNTS_VALS\n";
    #      print "PASSING short array clim_pavg with len $#clim_pavg\n";
    #    }
    $peramt[$per][$c] = val_given_F_bounded($perqnt[$per][$c], @clim_pav);
  }  # end looping through periods
}  # %%%%%%%%%%%%% end looping through grid cells %%%%%%%%%%%

# ==== assign amounts and write out amount grd ========
print "writing amount grid\n";
for ($c = 0 ; $c < @flist ; $c++) {  # loop through cells
  for ($per = 0 ; $per < @sm ; $per++) {  # write tser months along row
      # NOTE this is the transpose of other tabular datafiles used in this
      # process can facilitate plotting of percentiles if desired
    printf OUT "%.3f ", $peramt[$per][$c];
  }
  printf OUT "\n";
}
close(OUT);
print "\n Finishing script $0 \n";
print "####\n";

# END program
# %%%%%%%%%%%%%%%%%%%% SUBROUTINES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# set sort logic
sub numer {$a <=> $b;}

# given an unsorted array and non-exceed. %-ile, return the associated value.
# for this case, bound results by distribution (don't extrapolate at ends). one
# 'upgrade' would be to add extrapolation, but that requires distrib. fitting
sub val_given_F_bounded {
  my ($qnt, @array) = @_;
  $LEN = @array;  # dimension of array

  # sort array (using logic set in other subroutine)
  @srt_arr = sort numer @array;
  for ($i = 0 ; $i < $LEN ; $i++) {  # nonexceed. prob arrays go low to high
    $weib[$i] = ($i + 1) / ($LEN + 1);
  }

  # check for sample size problems (no extrapolation allowed) - replace w/
  # following
  #  if($weib[0] > $qnt || $weib[$LEN -1] < $qnt) {
  #    printf STDERR "array too small for quant. calc;\n";
  #    printf STDERR "need larger sample or diff. quant.\n";
  #    printf STDERR "qnt: $qnt   dist bounds: $weib[0], $weib[$LEN -1]\n";
  #    die;
  #  }
  # check for sample size problems (don't extrapolate - just use array bounds)
  if ($weib[0] > $qnt) {
    return $srt_arr[0];  # if quant too low, return lowest val
  } elsif ($weib[$LEN - 1] < $qnt) {
    return $srt_arr[$LEN - 1];  # if quant too high, return highest val
  } else {                      # quantile w/in bounds

    # find interpolation weight and index of values to interpolate
    $ndx = $weight = 0;
    for ($i = 1 ; $i < $LEN ; $i++) {  # start from one, since no extrapolation
      if ($weib[$i] >= $qnt) {

        #weight multiplies upper value, (1-weight) mult. lower value
        $weight = ($qnt - $weib[$i - 1]) / ($weib[$i] - $weib[$i - 1]);
        $ndx = $i - 1;                 # lower one
        last;
      }
    }

    # calculate quantile-associated value
    $val = $srt_arr[$ndx] * (1 - $weight) + $srt_arr[$ndx + 1] * ($weight);
    return $val;
  }
}
