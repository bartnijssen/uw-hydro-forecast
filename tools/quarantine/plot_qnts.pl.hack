#!/usr/bin/perl -w
# Ali Akanda, 041805, 050505
# A.Wood, jul07, modified to make runoff plots too
# 2008-05-22 Generalized for multimodel sw monitor.	TJB

use LWP::Simple;
use Date::Calc qw(Add_Delta_YM Add_Delta_Days Days_in_Month Delta_Days);

# Command-line arguments
$PROJECT = shift; # project name, e.g. conus mexico
$MODEL = shift; # model name, e.g. vic noah sac clm multimodel
$yr = shift;
$mon = shift;
$day = shift;
$CLIM_START_YR = shift;
$CLIM_END_YR = shift;

# Constants
$ROOT_DIR = "/raid8/forecast/sw_monitor";
$TOOLS_DIR = "$ROOT_DIR/tools";
$CONFIG_DIR = "$ROOT_DIR/config";
$COMMON_DIR = "$ROOT_DIR/../common";
@month_days = (31,28,31,30,31,30,31,31,30,31,30,31);
if ($MODEL eq "vic") {
  @varnames = ("sm","swe","stot","ro");
  if ($PROJECT eq "conus") {
    push @varnames, ("smDM","smw","smc","sme");
  }
}
else {
  @varnames = ("sm");
}
$swe_thresh = 10; # mm
# HACK
@varnames = ("smDM");

# Derived constants
$PROJECT_DIR = "$ROOT_DIR/data/$PROJECT";
$PLOT_DIR = "$PROJECT_DIR/spatial/plots";
$XYZZ_DIR = "$PROJECT_DIR/spatial/xyzz.all";
$MODEL_UC = $MODEL;
$MODEL_UC =~ tr/a-z/A-Z/;
$CONFIG_FILE = "$CONFIG_DIR/config.project.$PROJECT";
$PROJECT_UC = $PROJECT;
$PROJECT_UC =~ tr/a-z/A-Z/;

# Read config file to get climatology start/end years, other plot info
open (CONFIG_FILE, $CONFIG_FILE) or die "$0: ERROR: cannot open file $CONFIG_FILE\n";
foreach (<CONFIG_FILE>) {
#  if (/^CLIM_START_YR\s+(\d+)/) {
#    $CLIM_START_YR = $1;
#  }
#  if (/^CLIM_END_YR\s+(\d+)/) {
#    $CLIM_END_YR = $1;
#  }
  if (/^MAP_PROJ\s+(\S+)/) {
    $PROJ = $1;
  }
  if (/^MAP_COORD\s+(\S+)/) {
    $COORD = $1;
  }
  if (/^MAP_ANNOT\s+(\S+)/) {
    $ANNOT = $1;
  }
  if (/^MAP_XX\s+(\S+)/) {
    $XX = $1;
  }
  if (/^MAP_YY\s+(\S+)/) {
    $YY = $1;
  }
  if (/^MAP_SCALE_X\s+(\S+)/) {
    $SCALE_X = $1;
  }
}
close(CONFIG_FILE);

## Read nowcast date from file
#$Enddatefile = "$XYZZ_DIR/RESULTS.END_DATE";
#open(EDF, $Enddatefile) or die "$0: ERROR: cannot open end date file $Enddatefile\n";
#$line = <EDF>;
#close(EDF);
#@tmp = split( /\s+/, $line );
#($yr, $mon, $day ) = ( $tmp[0], $tmp[1], $tmp[2] );

# Set date string for filenames
$datenow = sprintf("%04d%02d%02d", $yr, $mon, $day);

# Make output directory
if (!-e "$PLOT_DIR/$datenow") {
  $cmd = "mkdir $PLOT_DIR/$datenow";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
}

# Loop over variables
foreach $varname (@varnames) {

  # Set up map parameters
  if ($varname eq "smw") {
    $current_PROJ = "-JM6.5";
    $current_COORD = "-126/-100/28/50";
    $current_ANNOT = "-B4/4:.:WEsN";
    $current_XX = 0;
    $current_YY = 1;
    $current_SCALE_X = 3.25;
  }
  elsif ($varname eq "smc") {
    $current_PROJ = "-JM6";
    $current_COORD = "-110/-86/24/50";
    $current_ANNOT = "-B4/4:.:WEsN";
    $current_XX = 0;
    $current_YY = 0.25;
    $current_SCALE_X = 3.00;
  }
  elsif ($varname eq "sme") {
    $current_PROJ = "-JM7";
    $current_COORD = "-94/-66/24/50";
    $current_ANNOT = "-B4/4:.:WEsN";
    $current_XX = -0.25;
    $current_YY = 0.25;
    $current_SCALE_X = 3.5;
  }
  else {
    $current_PROJ = $PROJ;
    $current_COORD = $COORD;
    $current_ANNOT = $ANNOT;
    $current_XX = $XX;
    $current_YY = $YY;
    $current_SCALE_X = $SCALE_X;
  }

  # Set up periods to loop over
  if ($varname eq "sm" || $varname eq "swe") {
    @periods = ("","1day","1wk","2wk","1mo");
  }
  elsif ($varname eq "ro") {
    @periods = ("1mo","2mo","3mo","6mo","9mo","12mo","18mo","24mo","36mo","48mo","60mo","WY");
    @periodlbls = ("1-Month","2-Month","3-Month","6-Month","9-Month","1-Year","18-Month","2-Year","3-Year","4-Year","5-Year","Water Year");
  }
  else {
    @periods = ("");
  }

  # Loop over periods
  for ($pidx=0; $pidx<@periods; $pidx++) {

    # First (and/or only) data file
    if ($varname eq "ro") {
      $srcfile1 = "$XYZZ_DIR/$datenow/$varname.$PROJECT_UC.$MODEL.qnt.xyzz";
    }
    elsif ($varname =~ /^sm(DM|w|c|e)$/) {
      $srcfile1 = "$XYZZ_DIR/$datenow/sm.$PROJECT_UC.$MODEL.f-c_mean.a-m_anom.qnt.xyzz";
    }
    else {
      $srcfile1 = "$XYZZ_DIR/$datenow/$varname.$PROJECT_UC.$MODEL.f-c_mean.a-m_anom.qnt.xyzz";
    }

    # (optional) second data file
    $srcfile2 = "NODATA";
    if ( ($varname eq "sm" || $varname eq "swe") & $periods[$pidx] ne "" ) {
      if ($periods[$pidx] eq "1day") {
        ($yr2,$mon2,$day2) = Add_Delta_Days($yr, $mon, $day,-1);
        $otherdate = sprintf("%04d%02d%02d", $yr2, $mon2, $day2);
      }
      elsif ($periods[$pidx] eq "1wk") {
        ($yr2,$mon2,$day2) = Add_Delta_Days($yr, $mon, $day,-7);
        $otherdate = sprintf("%04d%02d%02d", $yr2, $mon2, $day2);
      }
      elsif ($periods[$pidx] eq "2wk") {
        ($yr2,$mon2,$day2) = Add_Delta_Days($yr, $mon, $day,-14);
        $otherdate = sprintf("%04d%02d%02d", $yr2, $mon2, $day2);
      }
      elsif ($periods[$pidx] eq "1mo") {
        $day2 = $day;
        $mon2 = $mon-1;
        $yr2 = $yr;
        if ($mon2 < 1) {
          $mon2 = 12;
          $yr2--;
        }
        $days_in_month = $month_days[$mon2-1];
        if ( ($yr2 % 4) == 0 && $mon2 == 2) {
          $days_in_month++;
        }
        if ($day2 > $days_in_month) {
          $day2 = $days_in_month;
        }
        $otherdate = sprintf("%04d%02d%02d", $yr2, $mon2, $day2);
      }
      if (-e "$XYZZ_DIR/$otherdate") {
        $srcfile2 = "$XYZZ_DIR/$otherdate/$varname.$PROJECT_UC.$MODEL.f-c_mean.a-m_anom.qnt.xyzz";
	if (! -e $srcfile2) {
          print "$0: WARNING: $srcfile2 not found\n";
	  next;
	}
      }
      else {
        print "$0: WARNING: $XYZZ_DIR/$otherdate not found\n";
	next;
      }
    }

    #  Output filename
    if ($periods[$pidx] eq "") {
      $periodstr = "";
    }
    else {
      $periodstr = "." . $periods[$pidx];
    }
    $outfile = "$PLOT_DIR/$datenow/$PROJECT_UC.$MODEL." . $varname . "_qnt" . $periodstr . ".ps";
    if ($varname eq "smw") {
      $outfile = "$PLOT_DIR/$datenow/west.$MODEL.sm_qnt.ps";
    }
    elsif ($varname eq "smc") {
      $outfile = "$PLOT_DIR/$datenow/cent.$MODEL.sm_qnt.ps";
    }
    elsif ($varname eq "sme") {
      $outfile = "$PLOT_DIR/$datenow/east.$MODEL.sm_qnt.ps";
    }
    elsif ($varname eq "smDM") {
      $outfile = "$PLOT_DIR/$datenow/$PROJECT_UC.$MODEL.sm_qnt.DM.ps";
    }

    # First title line
    if ($varname =~ /^sm(DM|w|c|e)?$/) {
      $longname = "Soil Moisture";
    }
    elsif ($varname eq "swe") {
      $longname = "Snow Water Equivalent";
    }
    elsif ($varname eq "ro") {
      $longname = "Cumulative $periodlbls[$pidx] Runoff";
    }
    $title1 = "$MODEL_UC $longname Percentiles (wrt/ $CLIM_START_YR-$CLIM_END_YR)";

    # Second title line
    if ( ($varname eq "sm" || $varname eq "swe") && $periods[$pidx] ne "" ) {
      $title2 = "for the period:   $otherdate  to  $datenow";
      if ($varname eq "swe") {
        $title2 = "$title2   threshold = $swe_thresh mm";
      }
    }
    elsif ($varname eq "smw") {
      $title2 = "Western United States - $datenow";
    }
    elsif ($varname eq "smc") {
      $title2 = "Central United States - $datenow";
    }
    elsif ($varname eq "sme") {
      $title2 = "Eastern United States - $datenow";
    }
    else {
      $title2 = $datenow;
    }

    # Color scale
    if ( ($varname eq "sm" || $varname eq "swe") && $periods[$pidx] ne "" ) {
      $cptlabel1 = "change in percentile";
      $cptlabel2 = "NODATA";
      $cptfile = "$COMMON_DIR/cpt/BR_YWG_BL.mod.cpt";
    }
    else {
      $cptlabel1 = "percentile";
      if ($varname eq "swe") {
        $cptfile = "$COMMON_DIR/cpt/sw_mon.SWE.cpt";
        $cptlabel2 = "NODATA";
      }
      elsif ($varname eq "smDM") {
        $cptfile = "$COMMON_DIR/cpt/DM_sm_scale.cpt";
        $cptlabel2 = "0.4 -0.022 12 0 5 6 \\t           D4               D3               D2               D1               D0";
      }
      else {
        $cptfile = "$COMMON_DIR/cpt/CPC_smplot.cpt";
        $cptlabel2 = "NODATA";
      }
    }

    # Temporary data file for plotting purposes
    $datafile = "$XYZZ_DIR/$datenow/$varname.$PROJECT_UC.$MODEL.tmp.xyzz";
    if ($varname =~ /^sm(DM|w|c|e)?$/) {
      if ($periods[$pidx] eq "" ) {
        $cmd = "awk \'{print \$1,\$2,\$7*100}\' $srcfile1 > $datafile";
        (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
      }
      else {
        $cmd = "paste $srcfile1 $srcfile2 > $datafile.tmp";
        (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
        $cmd = "awk \'{print \$1,\$2,(\$7-\$14)*100}\' $datafile.tmp > $datafile";
        (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
      }
    }
    elsif ($varname eq "swe") {
      if ($periods[$pidx] eq "" ) {
        $cmd = "awk \'{if (\$3 > $swe_thresh || \$4 > $swe_thresh) print \$1,\$2,\$7*100}\' $srcfile1 > $datafile";
        (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
      }
      else {
        $cmd = "paste $srcfile1 $srcfile2 > $datafile.tmp";
        (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
        $cmd = "awk \'{if (\$3 > $swe_thresh || \$4 > $swe_thresh) print \$1,\$2,(\$7-\$14)*100}\' $datafile.tmp > $datafile";
        (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
      }
    }
    else {
      $col = $pidx+1;
      $cmd = "awk \'{print \$1,\$2,\$(\'$col\'+2)*100}\' $srcfile1 > $datafile";
      (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
    }

    # Plot-specific layers
    if ($varname =~ /^sm(w|c|e)$/) {
      $polyfile1 = "$COMMON_DIR/basdln/us_county.poly";
      $polyfile2 = "$COMMON_DIR/basdln/lower48.poly";
    }
    else {
      $polyfile1 = "NODATA";
      $polyfile2 = "NODATA";
    }

    # Call the generic plotting script
    $plot_scr = "$TOOLS_DIR/plot.var_qnt.scr";
    $cmd = "$plot_scr $datafile $outfile $current_COORD $current_PROJ $current_ANNOT $current_XX $current_YY $current_SCALE_X \"$title1\" \"$title2\" $cptfile \"$cptlabel1\" \"$cptlabel2\" $polyfile1 $polyfile2";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

    # Clean up temp data file
    $cmd = "rm -f $datafile $datafile.tmp";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

  }

}

print "Done with all plots!\n";
