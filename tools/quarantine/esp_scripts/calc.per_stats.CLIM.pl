#!/usr/bin/perl -w
# A. Wood August 2007
# works on climatology only

# calculate climatology for predicted daily SM & SWE and cumulative
#  3- and 6- month RO percentile after 1 month, 2 months, 3 months

# output format:  one row per cell
#   lon lat [smqnt at N future dates] [swe qnt at dates] [cum RO-3 qnt at dates] [cum RO-6 ...]
#
#  NOTE:  supply climatology period for calculating percentiles.
#    Set start of climatology period so that accumulation periods do not
#    precede start of data.

use Date::Calc qw(leap_year Days_in_Month Delta_Days Add_Delta_Days Add_Delta_YM);

# ---------- ARGS ------------------------------
if(@ARGV != 10) {
  die "Usage:  calc.per_stats.clim.pl <YYYY> <MM> <DD> <Clim_Syr> <Clim_Eyr> <Flist> <RetroDir> <NearRTDir> <RTDir> <EspDir>\n";
} else {
  ($Cyr, $Cmon, $Cday) = ($ARGV[0],$ARGV[1],$ARGV[2]);  # MUST HAVE
}
$datestr = sprintf("%04d%02d%02d",$Cyr,$Cmon,$Cday);

# ---------- SETTINGS ------------------------------
@PER = (1, 2, 3);  # calculation intervals, in months
($Clim_Syr, $Clim_Eyr) = ($ARGV[3], $ARGV[4]); 
$Flist  = "$ARGV[5]";
$RetroDir = "$ARGV[6]"; #phobic
$NearRTDir = "$ARGV[7]";
$RTDir = "$ARGV[8]";
$EspDir = "$ARGV[9]";
# read file/station list ----------------------
@cell = `cat $Flist`;
chomp(@cell);
$Outfl = "$EspDir/xyzz/$datestr/wb_vals.CLIM.$datestr.xyzz";
# check adequacy of data records ---------------
open(FL, "<$RetroDir/$cell[0]") or die "can't open $RetroDir/$cell[0]: $!\n";
$r=0;
while(<FL>) {
  ($yr[$r],$mo[$r],$dy[$r],@tmp) = split;
  $r++;
}
close(FL);
open(FL, "<$NearRTDir/$cell[0]") or die "can't open $NearRTDir/$cell[0]: $!\n";
while(<FL>) {
  ($yr[$r],$mo[$r],$dy[$r],@tmp) = split;
  $r++;
}
close(FL);
open(FL, "<$RTDir/$cell[0]") or die "can't open $RTDir/$cell[0]: $!\n";
while(<FL>) {
  ($yr[$r],$mo[$r],$dy[$r],@tmp) = split;
  $r++;
}
close(FL);
#$datarecs = $r;  # save so that future portion of fcsts can be re-read
                  #   while looping through ensembles
($yr0, $mon0, $day0) = ($yr[0],$mo[0],$dy[0]);  # data start date

# ====== first make matrix of start & end dates for all periods desired ========
print "making matrix of start & end records for accumulations periods\n";

# calculate records bounding CLIM period accumulations -------------
$ny = 0;  # counter for years, working forward
for($y=$Clim_Syr; $y<=$Clim_Eyr; $y++) {
  for($p=0;$p<@PER;$p++) {
    ($tyr, $tmo, $tdy) = Add_Delta_YM($y, $Cmon, $Cday, 0, $PER[$p]-6); # start of 6 mon period
    ($ty, $tm, $td) = Add_Delta_Days($tyr, $tmo, $tdy, 1); # move forward 1 day
    $recbnd1a[$ny][$p] = Delta_Days($yr0,$mon0,$day0,$ty, $tm, $td);
    ($tyr, $tmo, $tdy) = Add_Delta_YM($y, $Cmon, $Cday, 0, $PER[$p]-3); # start of 3 mon period
    ($ty, $tm, $td) = Add_Delta_Days($tyr, $tmo, $tdy, 1); # move forward 1 day
    $recbnd1b[$ny][$p] = Delta_Days($yr0,$mon0,$day0,$ty, $tm, $td);
    ($tyr, $tmo, $tdy) = Add_Delta_YM($y, $Cmon, $Cday, 0, $PER[$p]);
    $recbnd2[$ny][$p] = Delta_Days($yr0,$mon0,$day0,$tyr, $tmo, $tdy); # end of 3 mon period
    # note:  record boundary 2 as an array index will be one more than the desired date
    #        handle this later when extracting data from arrays

#    if($recbnd2[$ny][$p]<0 || $recbnd1a[$ny][$p]<0 ||
#       $recbnd2[$ny][$p]>=$datarecs || $recbnd1a[$ny][$p]>=$datarecs) {
#      die "ERROR:  accum. period exceeds data bounds -- check climatology period\n";
#    }
  }
  $ny++;
}

$curr_ndx = $ny;  # array index of current record boundaries for periods

# check matrix by printing out -------
#for($y=0;$y<$ny;$y++) {
#  printf "%d\t",$Clim_Syr+$y;
#  for($p=0;$p<@PER;$p++) {
#    printf "%d %d\t",$recbnd1a[$y][$p], $recbnd2[$y][$p];
#  }
#  printf "\n";
#}

# ========== loop through cells/stations and calculate predictand climatology ============

@ro = @all_sm = @all_swe = @sm = @swe = @cum_ro_6 = @cum_ro_3 = ();  # store datea until final write
for($c=0;$c<@cell;$c++) {
#for($c=0;$c<10;$c++) {
  print "$c $cell[$c]\n";

  Read_Data_One_Cell_Clim($cell[$c], \@ro, \@all_sm, \@all_swe);  # get data for one cell

  # should write this out in sorted order...will save time after the forecast...

  # loop through years & periods and get accumulations (could do this more efficiently...)
  for($p=0;$p<@PER;$p++) {
    for($y=0;$y<$curr_ndx;$y++) {
      $cum_ro_6[$c][$p][$y] = 0;
      for($r=$recbnd1a[$y][$p];$r<$recbnd2[$y][$p];$r++) {
        $cum_ro_6[$c][$p][$y] += $ro[$r];
      }
      $cum_ro_3[$c][$p][$y] = 0;
      for($r=$recbnd1b[$y][$p];$r<$recbnd2[$y][$p];$r++) {
        $cum_ro_3[$c][$p][$y] += $ro[$r];
      }
      $sm[$c][$p][$y] = $all_sm[$r-1];    # note $r now = $recbnd2[$y][$p]
      $swe[$c][$p][$y] = $all_swe[$r-1];  # need to decrement by 1
    }
  }
} # finished working on climatology for all cells

# -- now write out climatology for use by curr and fcst analysis programs ---------------
open(OUT, ">$Outfl") or die "can't open $Outfl: $!\n";
print "writing...\n";

#for($c=0;$c<10;$c++) {
for($c=0;$c<@cell;$c++) {
  @tmp = split("_",$cell[$c]);
  printf OUT "%.4f %.4f   ", $tmp[2],$tmp[1];

  for($p=0;$p<@PER;$p++) {  # loop through accum periods
    for($y=0;$y<$curr_ndx;$y++) {
      printf OUT "%.2f ", $sm[$c][$p][$y];
    }
    printf OUT "  ";
  }
  printf OUT "    ";
  for($p=0;$p<@PER;$p++) {  # loop through accum periods
    for($y=0;$y<$curr_ndx;$y++) {
      printf OUT "%.2f ", $swe[$c][$p][$y];
    }
    printf OUT "  ";
  }
  printf OUT "    ";

  for($p=0;$p<@PER;$p++) {  # loop through accum periods
    for($y=0;$y<$curr_ndx;$y++) {
      printf OUT "%.2f ", $cum_ro_6[$c][$p][$y];
    }
    printf OUT "  ";
  }

  for($p=0;$p<@PER;$p++) {  # loop through accum periods
    for($y=0;$y<$curr_ndx;$y++) {
      printf OUT "%.2f ", $cum_ro_3[$c][$p][$y];
    }
    printf OUT "  ";
  }

  printf OUT "\n";
}
close(OUT);



# %%%%%%%%%%%%%%%%%%%% SUBROUTINES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# subroutine to read runoff from one cell
#   uses global variables for directory names
sub Read_Data_One_Cell_Clim {
  ($cname, $ro_ref, $sm_ref, $swe_ref) = @_;

  open(FL, "<$RetroDir/$cname") or die "can't open $RetroDir/$cname: $!\n";
  $r=0;
  while(<FL>) {
    @tmp = split;
    $ro_ref->[$r] = $tmp[5]+$tmp[6];  # reference this way to pass back values
    $sm_ref->[$r] = $tmp[8]+$tmp[9]+$tmp[10];  # reference this way to pass back values
    $swe_ref->[$r] = $tmp[11];  # reference this way to pass back values
    $r++;
  }
  close(FL);
  open(FL, "<$NearRTDir/$cname") or die "can't open $NearRTDir/$cname: $!\n";
  while(<FL>) {
    @tmp = split;
    $ro_ref->[$r] = $tmp[5]+$tmp[6];
    $sm_ref->[$r] = $tmp[8]+$tmp[9]+$tmp[10];  # reference this way to pass back values
    $swe_ref->[$r] = $tmp[11];  # reference this way to pass back values
    $r++;
  }
  close(FL);
  open(FL, "<$RTDir/$cname") or die "can't open $RTDir/$cname: $!\n";
  while(<FL>) {
    @tmp = split;
    $ro_ref->[$r] = $tmp[5]+$tmp[6];
    $sm_ref->[$r] = $tmp[8]+$tmp[9]+$tmp[10];  # reference this way to pass back values
    $swe_ref->[$r] = $tmp[11];  # reference this way to pass back values
    $r++;
  }
  close(FL);
}

