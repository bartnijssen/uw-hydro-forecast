#!<SYSTEM_PERL_EXE> -w
# AWW-1104
# from the recent daily station fmt (spinup period),
# make a format (.fmt) file of precip percentiles
# this output file will be either for 1 or 2 periods:
#   if 2, the first is one month long, second varies
#   if 1, the period is combined
use lib qw(<SYSTEM_INSTALLDIR>/lib <SYSTEM_PERL_LIBS>);
use Date::Calc qw(Add_Delta_YM);
use Statistics::Lite ("mean");
use UWTime;  # Use this for Days_In_Month

# ---------- ARGS / SETTINGS ------------------------------
$p_stnvals = shift;
$Syr       = shift;
$Smon      = shift;
$Fyr       = shift;
$Fmon      = shift;
$Fday      = shift;
$MinDays   = shift;
$FractReq  = shift;
$StnList   = shift;
$RetroDir  = shift;
$Clim_Syr  = shift;
$Clim_Eyr  = shift;
$Void      = shift;
$p_qnt     = shift;

# ----------------------------------------------------------
print "FMT start $Syr $Smon\n";
print "FMT end $Fyr $Fmon $Fday\n";
print "StnList $StnList\n";
print "RetroDir $RetroDir\n";
print "p_vals is $p_stnvals\n";
print "Clim Syr is $Clim_Syr and Clim Eyr $Clim_Eyr\n";
@y = 0;

# Number of periods is decided by comparing the current day with the start of
# spinup period Until $Mindays th day of the current month, all the days in the
# current month + past month is considered to be the 2nd period and the first
# month is considered to be the 1st period Advance state runs on $Min_days th
# day of the month and moves the start of the current spinup period to the first
# day of the last month
if (Delta_Days($Syr, $Smon, 1, $Fyr, $Fmon, $Fday) + 1 < $MinDays ||
    ($Syr == $Fyr && $Smon == $Fmon)) {

  # calc percentiles for just one period
  @sy = ($Syr);
  @sm = ($Smon);
  @sd = (1);
  @ey = ($Fyr);
  @em = ($Fmon);
  @ed = ($Fday);
  @daycnt_thresh =
    (int($FractReq * Delta_Days($Syr, $Smon, 1, $Fyr, $Fmon, $Fday)));
} else {

  # calc percentiles for 2 periods; first is one month long
  # Shrad added this
  # 20120806 The following line estimates the parameter of the second month of
  # the spinup (i.e. the month before the current period)
  if (Delta_Days($Fyr, $Fmon, 1, $Fyr, $Fmon, $Fday) + 1 < $MinDays) {
    ($ty, $tm, $td) = Add_Delta_YM($Fyr, $Fmon, $Fday, 0, -1);
    @daycnt_thresh = (
              int($FractReq * Days_In_Month($Syr, $Smon)),
              int($FractReq * Days_In_Month($ty,  $tm)) + int($FractReq * $Fday)
                     );
  } else {
    ($ty, $tm, $td) = ($Fyr, $Fmon, $Fday);
    @daycnt_thresh =
      (int($FractReq * Days_In_Month($Syr, $Smon)), int($FractReq * $Fday));
  }
  $td = 1;
  @sy = ($Syr, $ty);
  @sm = ($Smon, $tm);
  @sd = (1, 1);
  @ey = ($Syr, $Fyr);
  @em = ($Smon, $Fmon);
  @ed = (Days_In_Month($Syr, $Smon), $Fday);
}
$nPer = @sm;
print "Number of periods is $nPer $daycnt_thresh[0] $daycnt_thresh[1]\n";
print "First period: $Syr, $Smon, 01 to the last day of that month\n";
print "Second period: $ty, $tm, 01 to $Fyr, $Fmon, $Fday\n";

# read station list
open(STNF, "<$StnList") or die "$0: ERROR: cannot open $StnList: $!\n";
$junk = <STNF>;  # skip header line;
$s    = 0;
while (<STNF>) {
  ($junk, $junk, $junk, $ID[$s], $junk, $junk) = split;
  $s++;
}
close(STNF);

# read in station values from format file produced by update_fmt.pl
open(PINF, "<$p_stnvals") or die "$0: ERROR: cannot open $p_stnvals: $!\n";
$r = 0;
($curr_y[$r], $curr_m[$r], $curr_d[$r]) = ($ly, $lm, $ld) = ($Syr, $Smon, 1);
while (<PINF>) {
  @tmp = split;
  for ($s = 0 ; $s < @tmp ; $s++) {
    $p_dlyval[$r][$s] = $tmp[$s];
  }

  # calculate dates of retrospective forcings
  ($curr_y[$r + 1], $curr_m[$r + 1], $curr_d[$r + 1]) =
    Add_Delta_Days($ly, $lm, $ld, 1);
  ($ly, $lm, $ld) = ($curr_y[$r + 1], $curr_m[$r + 1], $curr_d[$r + 1]);
  $r++;
}
close(PINF);
$recent_per = $r;

# open output file ------
open(OUT, ">$p_qnt") or die "$0: ERROR: cannot open $p_qnt: $!\n";

# %%%%%%%%%%%%%% loop through stations %%%%%%%%%%%%%%%%%%%%%%%%
for ($s = 0 ; $s < @ID ; $s++) {

  # read in archive data
  open(RETRO, "<$RetroDir/$ID[$s]") or
    die "$0: ERROR: cannot open $RetroDir/$ID[$s]: $!\n";
  $r = 0;
  while (<RETRO>) {
    if (/^\d/) {
      ($y[$r], $m[$r], $d[$r], $p[$r], @tmp) = split;
      $r++;
    }
  }
  close(RETRO);

  # loop through periods -------------------------------
  for ($per = 0 ; $per < @sm ; $per++) {

    # get avgd, sorted clim for period
    $flag = $daycnt = $cntper = 0;
    $tmp_ptot  = 0;
    @clim_ptot = ();
    for ($r = 0 ; $r < @p ; $r++) {
      if (($y[$r] >= $Clim_Syr) && ($y[$r] <= $Clim_Eyr)) {  # in clim period
        if ($m[$r] == $sm[$per] && $d[$r] == $sd[$per]) {

          ###print "Reading Started $sm[$per] $sd[$per]\n";
          $flag = 1;  # in desired daily-period
          if ($p[$r] != $Void) {
            $tmp_ptot = $p[$r];  # restarts var tmp_ptot
            $daycnt++;
          }
        } elsif ($flag == 1) {  # within calendar period
          if ($p[$r] != $Void) {
            $tmp_ptot += $p[$r];
            $daycnt++;
          }
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
        if ($m[$r] == $tmp_em && $d[$r] == $tmp_ed && $flag == 1) {  # end
            ###print "Reading ended $tmp_em $tmp_ed\n";
          $flag = 0;  # end desired daily-period
          if ($daycnt >= $daycnt_thresh[$per]) {
            $clim_ptot[$cntper] = $tmp_ptot / $daycnt;
          } else {
            $clim_ptot[$cntper] = $Void;
          }
          $cntper++;
          $daycnt = 0;  # reset
        }
      }  # END if within clim averging period
    }  # end reading through clim data for current station

    # now get current period average in recent data
    # data should contain ONLY the days for the 1 or 2 periods
    $flag = $daycnt = 0;
    $tmp_ptot = 0;
    for ($r = 0 ; $r < $recent_per ; $r++) {
      if ($curr_m[$r] == $sm[$per] && $curr_d[$r] == $sd[$per]) {
        $flag = 1;  # in desired daily-period
        if ($p_dlyval[$r][$s] != $Void) {
          $tmp_ptot = $p_dlyval[$r][$s];  # resets tmp_ptot
          $daycnt++;
        }
      } elsif ($flag == 1) {
        if ($p_dlyval[$r][$s] != $Void) {
          $tmp_ptot += $p_dlyval[$r][$s];
          $daycnt++;
        }
      }
      if ($curr_m[$r] == $em[$per] && $curr_d[$r] == $ed[$per] && $flag == 1) {
        $flag = 0;                        # end desired daily-period
        if ($daycnt >= $daycnt_thresh[$per]) {
          $curr_ptot = $tmp_ptot / $daycnt;
        } else {
          $pqnt[$s][$per] = $curr_ptot = $Void;
        }
        $daycnt = 0;                      # reset
      }
    }  # end reading through recent data

    #if ($flag) {
    #  print "never reached end of period\n";
    #}
    # ------------- calc percentile ----------------------
    # add to output .fmt file
    #print "$per $s $curr_ptot\n";
    #exit;
    if ($curr_ptot != $Void) {

      # extract non-voids from clim array matching historical period
      @tmp = ();
      $x   = 0;
      for ($r = 0 ; $r < @clim_ptot ; $r++) {
        if ($clim_ptot[$r] != $Void) {
          $tmp[$x] = $clim_ptot[$r];
          $x++;
        }
      }
      $pqnt[$s][$per] = F_given_val($curr_ptot, @tmp);
    }
    print "station $s $ID[$s] period $per qnt $pqnt[$s][$per]\n";
  }  # end percentile period loop (1 or 2) ---
}  # end looping through stations %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# ---- now write out format file --------------------------
for ($per = 0 ; $per < @sm ; $per++) {
  for ($s = 0 ; $s < @ID ; $s++) {
    printf OUT "%6.3f ", $pqnt[$s][$per];
  }
  printf OUT "\n";
}
close(OUT);

# %%%%%%%%%%%%%%%%%%%% SUBROUTINES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# set sort logic
sub numer {$a <=> $b;}

# given an unsorted array and value, return the associated non-exceed. %-ile.
sub F_given_val {

  # allows crude percentile extrapolation; returns void for zero distrib.
  my ($val, @array) = @_;
  $LEN = @array;  # dimension of array
  if ($LEN == 0) {
    return $Void;
  }
  $min_p = 1 / ($LEN + 1) * 0.5;  # def. p-val for targ below dist
  $max_p = $LEN / ($LEN + 1) + $min_p;  # ditto for above dist

  # sort array (using logic set in other subroutine)
  #print "F_given_val: val=$val\n";
  @srt_arr = sort numer @array;
  if ((mean @srt_arr) == 0) {
    return $Void;
  } else {                              # non-zero distribution mean case
    $i = 0;
    while ($i < $LEN) {
      if ($srt_arr[$i] >= $val && $i == 0) {

        # handles zero precip case, but gives lowest percentile (!!)
        $qnt = $min_p;
        last;
      } elsif ($srt_arr[$i] < $val && $i == $LEN - 1) {
        $qnt = $max_p;
        last;
      } elsif ($srt_arr[$i] >= $val) {

        # note, i as counter in qnt eq. must start at 1 not 0
        # whereas in arrays, starts at 0
        $qnt =
          ($val - $srt_arr[$i - 1]) /
          ($srt_arr[$i] - $srt_arr[$i - 1]) *
          (($i + 1) / ($LEN + 1) - $i / ($LEN + 1)) + $i /
          ($LEN + 1);
        last;
      }
      $i++;
    }  # done calc'ing percentiles
  }  # end if non-zero mean case
  return $qnt;
}
