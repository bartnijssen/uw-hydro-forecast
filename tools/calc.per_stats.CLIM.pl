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


# ---------- ARGS ------------------------------
if(@ARGV != 11) {
  die "Usage:  calc.per_stats.clim.pl <YYYY> <MM> <DD> <Clim_Syr> <Clim_Eyr> <Flist> <RetroDir> <NearRTDir> <RTDir> <EspDir> <MODEL>\n";
} else {
  ($Cyr, $Cmon, $Cday) = ($ARGV[0],$ARGV[1],$ARGV[2]);  # MUST HAVE
}
$datestr = sprintf("%04d%02d%02d",$Cyr,$Cmon,$Cday);

# ---------- SETTINGS ------------------------------
@PER = (1, 2, 3);  # calculation intervals, in months
($Clim_Syr, $Clim_Eyr) = ($ARGV[3], $ARGV[4]); 
$Latlonlist  = "$ARGV[5]";
$RetroDir = "$ARGV[6]"; #phobic
$NearRTDir = "$ARGV[7]";
$RTDir = "$ARGV[8]";
$EspDir = "$ARGV[9]";
$MODEL = "$ARGV[10]";
# read file/station list ----------------------

`mkdir -p $EspDir/xyzz/$datestr`;
$Outfl = "$EspDir/xyzz/$datestr/wb_vals.CLIM.$MODEL.$datestr.xyzz";

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



#### Initialize variables

$Flist = "$MODEL.flist"; ### Temp. model file list
open (LATLON, "<$Latlonlist") or die "can't open $Latlonlist $!\n";
open (FLIST, ">$Flist") or die "can't open $Flist $!\n";

if ($MODEL eq "vic")
  { $prefix = "fluxes_"; 
  }
else
  {$prefix = "wb_";
  }
while (<LATLON>)
  { ($lon, $lat) = split;
    $fname = "$prefix" . "$lat" . '_' . "$lon";
    print FLIST "$fname\n";
  }


@cell = `cat $Flist`;
chomp(@cell);

$ro_col = $sm_col = $swecol = 0;

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
  }
  $ny++;
}

$curr_ndx = $ny;  # array index of current record boundaries for periods

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
   foreach $col (@ROCols) {
         $ro_col = $col;
         $ro_ref->[$r] += $tmp[$ro_col];
  } 

   foreach $col (@SMCols) {
         $sm_col = $col;
         $sm_ref->[$r] += $tmp[$sm_col];
      }

    $swecol = $SWECol;
    $swe_ref->[$r] = $tmp[$swecol];  # reference this way to pass back values
$r++;
 }
  close(FL);
  open(FL, "<$NearRTDir/$cname") or die "can't open $NearRTDir/$cname: $!\n";
  while(<FL>) {
    @tmp = split;
    foreach $col (@ROCols) {
         $ro_col = $col;
         $ro_ref->[$r] += $tmp[$ro_col];
      }
   foreach $col (@SMCols) {
         $sm_col = $col;
         $sm_ref->[$r] += $tmp[$sm_col];
      }
     $swecol = $SWECol;
    $swe_ref->[$r] = $tmp[$swecol];  # reference this way to pass back values
    $r++;
  }
  close(FL);
  open(FL, "<$RTDir/$cname") or die "can't open $RTDir/$cname: $!\n";
  while(<FL>) {
    @tmp = split;
    
foreach $col (@ROCols) {
         $ro_col = $col;
         $ro_ref->[$r] += $tmp[$ro_col];
      }
   foreach $col (@SMCols) {
         $sm_col = $col;
         $sm_ref->[$r] += $tmp[$sm_col];
      }
    $swecol = $SWECol;
    
    $swe_ref->[$r] = $tmp[$swecol];  # reference this way to pass back values

    $r++;
  }
  close(FL);
}

