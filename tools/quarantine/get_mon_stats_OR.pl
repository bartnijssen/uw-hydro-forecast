#!/usr/bin/perl -w
# SGE commands
#$ -cwd
#$ -j y
#$ -S /usr/bin/perl
#$ -q forecast.q

# get_stats.pl: Script to convert model results into percentiles of model climatology
#
# Author: Ted Bohn
# $Id: $
#-------------------------------------------------------------------------------

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
require "$TOOLS_DIR/simma_util.pl";

# Date arithmetic
use Date::Calc qw(Days_in_Month Delta_Days Add_Delta_Days);

#-------------------------------------------------------------------------------
# Parse the command line
#-------------------------------------------------------------------------------

$MODEL = "vic";
$PROJECT = "pnw";
$CDATE = shift;

if ($CDATE =~ /(\d\d\d\d)(\d\d)(\d\d)/) {
    ($fyear, $fmonth, $fday) = ($1,$2,$3);
    }

$results_subdir_override = "retro"; # By default, results are taken from curr_spinup, but this can be overridden here

#----------------------------------------------------------------------------------------------
# Set up constants
#----------------------------------------------------------------------------------------------

# Derived variables
$PROJECT_UC = $PROJECT;
$PROJECT =~ tr/A-Z/a-z/;
$PROJECT_UC =~ tr/a-z/A-Z/;
$DATE = sprintf "%04d%02d%02d", $fyear, $fmonth, $fday;

# Unique identifier for this job
$JOB_ID = `date +%y%m%d-%H%M%S`;
if ($JOB_ID =~ /(\S+)/) {
  $JOB_ID = $1;
}

# Miscellaneous
@month_days = (31,28,31,30,31,30,31,31,30,31,30,31);

# Read project configuration info
$ConfigProject = "$CONFIG_DIR/config.project.$PROJECT";
$var_info_project_ref = &read_config($ConfigProject);
%var_info_project = %{$var_info_project_ref};

# Read model configuration info
$ConfigModel = "$CONFIG_DIR/config.model.$MODEL";
$var_info_model_ref = &read_config($ConfigModel);
%var_info_model = %{$var_info_model_ref};

# Substitute model-specific information into project variables
foreach $key_proj (keys(%var_info_project)) {
  foreach $key_model (keys(%var_info_model)) {
    $var_info_project{$key_proj} =~ s/<$key_model>/$var_info_model{$key_model}/g;
  }
}

# Save relevant project info in variables
$ResultsModelAscDir = $var_info_project{"RESULTS_MODEL_ASC_DIR"};
$XYZZDir            = $var_info_project{"XYZZ_DIR"};
$LONLAT             = "/raid8/forecast/shrad_misc/OR_DATA/OR_lon_lat.list";
$FLIST              = "/raid8/forecast/shrad_misc/OR_DATA/OR.125.fluxfiles.maskorder.xyzz"; 
$SYR                = $var_info_project{"CLIM_START_YR"}; # Climatology start year
$EYR                = $var_info_project{"CLIM_END_YR"}; # Climatology end year
$width              = $month_days[$fmonth-1]; # width of window (days) about forecast day for grand distribution ## Equal to number of days in the month
# The final processed model results will be stored in the ascii dir
$ResultsModelFinalDir = $ResultsModelAscDir;

# Save relevant model info in variables
$OutputPrefixList = $var_info_model{"OUTPUT_PREFIX"};
($OutputPrefix,$tmp) = split /,/, $OutputPrefixList;
if ($var_info_model{"ENS_MODEL_LIST"}) {
  $ENS_MODEL_LIST = $var_info_model{"ENS_MODEL_LIST"};
  @ENS_MODELS = split /,/, $ENS_MODEL_LIST;
  $nModels = @ENS_MODELS;
}
$SMCOL_LIST = $var_info_model{"SMCOL"};
@SMCols = split /,/, $SMCOL_LIST;
$SWECol = $var_info_model{"SWECOL"};
$STOTCol = $var_info_model{"STOTCOL"};

# Directories and files
$CURRPATH = $ResultsModelFinalDir;
if ($results_subdir_override) {
  $CURRPATH =~ s/<RESULTS_SUBDIR>/$results_subdir_override/g;
}
else {
  $CURRPATH =~ s/<RESULTS_SUBDIR>/curr_spinup/g;
}
$HISTPATH = $ResultsModelFinalDir;
$HISTPATH =~ s/<RESULTS_SUBDIR>/retro/g;
$XYZZDir = "/raid8/forecast/shrad_misc/OR_DATA/OR_RETRO_SM_PCNTL"; 
$OUTD = "$XYZZDir/$DATE";
if ($MODEL =~ /multimodel/i) {
  $CURRPATH = $OUTD;
}
$SMFILE = "$OUTD/$PROJECT_UC.$MODEL.sm.curr-srt_hist";
$SWEFILE = "$OUTD/$PROJECT_UC.$MODEL.swe.curr-srt_hist";
$STOTFILE = "$OUTD/$PROJECT_UC.$MODEL.stot.curr-srt_hist";
if ($MODEL =~ /vic/i) {
  $SM1FILE = "$OUTD/$PROJECT_UC.$MODEL.sm1.curr-srt_hist";
  $SM2FILE = "$OUTD/$PROJECT_UC.$MODEL.sm2.curr-srt_hist";
  $SM3FILE = "$OUTD/$PROJECT_UC.$MODEL.sm3.curr-srt_hist";
}

#----------------------------------------------------------------------------------------------
# END settings
#----------------------------------------------------------------------------------------------

# Check for directories; create if necessary & possible
foreach $dir ($CURRPATH, $HISTPATH) {
  if (!-d $dir) {
    die "$0: ERROR: directory $dir not found\n";
  }
}
foreach $dir ($OUTD) {
  $status = &make_dir($dir);
}

# Remove old files
if (-e $SMFILE) {
  $cmd = "rm -f $SMFILE";
  (system($cmd)==0) or die "$0: ERROR: cannot remove file $SMFILE\n";
}
if (-e $SWEFILE) {
  $cmd = "rm -f $SWEFILE";
  (system($cmd)==0) or die "$0: ERROR: cannot remove file $SWEFILE\n";
}
if ($MODEL =~ /vic/i) {
  if (-e $SM1FILE) {
    $cmd = "rm -f $SM1FILE";
    (system($cmd)==0) or die "$0: ERROR: cannot remove file $SM1FILE\n";
  }
  if (-e $SM2FILE) {
    $cmd = "rm -f $SM2FILE";
    (system($cmd)==0) or die "$0: ERROR: cannot remove file $SM2FILE\n";
  }
  if (-e $SM3FILE) {
    $cmd = "rm -f $SM3FILE";
    (system($cmd)==0) or die "$0: ERROR: cannot remove file $SM3FILE\n";
  }
}

# Compute current day of year
# Indexing starts at 1
$julian_day = $fday*1;
for ($mon=1; $mon<$fmonth; $mon++) {
  $days_in_month = $month_days[$mon-1];
  if ($fyear % 4 == 0 && $fmonth == 2) {
    $days_in_month++;
  }
  $julian_day += $days_in_month;
}
if ($julian_day == 366) {
  $julian_day--;
}

# Figure out which days of the year are in the window
@days_to_get = ();
for ($i=-int($width/2); $i<int($width/2)+1; $i++) {
  $day = $julian_day+$i;
  if ($day < 1) {
    $day += 365;
  }
  elsif ($day >= 365) {
    $day -= 365;
  }
  push @days_to_get, $day; 
}

# Open output files
open(SMFILE, ">$SMFILE") or die "$0: ERROR: cannot open file $SMFILE for writing\n";
open(SWEFILE, ">$SWEFILE") or die "$0: ERROR: cannot open file $SWEFILE for writing\n";
open(STOTFILE, ">$STOTFILE") or die "$0: ERROR: cannot open file $STOTFILE for writing\n";
if ($MODEL =~ /vic/i) {
  open(SM1FILE, ">$SM1FILE") or die "$0: ERROR: cannot open file $SM1FILE for writing\n";
  open(SM2FILE, ">$SM2FILE") or die "$0: ERROR: cannot open file $SM2FILE for writing\n";
  open(SM3FILE, ">$SM3FILE") or die "$0: ERROR: cannot open file $SM3FILE for writing\n";
}

#------------------------------------------------------------------------------------------
# Get current & historic distribution for sm & snow for specified date, sorted
#------------------------------------------------------------------------------------------

# For multimodel, current values are average of other models' pctls;
# Pctls have different format than model results
if ($MODEL =~ /multimodel/i) {
  $first = 1;
  foreach $ens_model (@ENS_MODELS) {
    $PCTL_FILE = "$OUTD/sm.$PROJECT_UC.$ens_model.f-c_mean.a-m_anom.qnt.xyzz";
    open(PCTL_FILE, $PCTL_FILE) or die "$0: ERROR: cannot open file $PCTL_FILE for reading\n";
    $cell_idx = 0;
    foreach (<PCTL_FILE>) {
      chomp;
      @fields = split /\s+/;
      if ($first) {
        $MMSoilMoist[$cell_idx] = $fields[6];
      }
      else {
        $MMSoilMoist[$cell_idx] += $fields[6];
      }
      $cell_idx++;
    }
    close(PCTL_FILE);
    $nCells = $cell_idx;
    $first = 0;
  }
  for ($cell_idx=0; $cell_idx<$nCells; $cell_idx++) {
    $MMSoilMoist[$cell_idx] /= $nModels;
  }
  $first = 1;
  foreach $ens_model (@ENS_MODELS) {
    $PCTL_FILE = "$OUTD/swe.$PROJECT_UC.$ens_model.f-c_mean.a-m_anom.qnt.xyzz";
    open(PCTL_FILE, $PCTL_FILE) or die "$0: ERROR: cannot open file $PCTL_FILE for reading\n";
    $cell_idx = 0;
    foreach (<PCTL_FILE>) {
      chomp;
      @fields = split /\s+/;
      if ($first) {
	$count[$cell_idx] = 0;
      }
      if ($fields[6] > 0) {
        if ($count[$cell_idx]==0) {
          $MMSWE[$cell_idx] = $fields[6];
        }
        else {
          $MMSWE[$cell_idx] += $fields[6];
        }
	$count[$cell_idx]++;
      }
      $cell_idx++;
    }
    close(PCTL_FILE);
    $nCells = $cell_idx;
    $first = 0;
  }
  for ($cell_idx=0; $cell_idx<$nCells; $cell_idx++) {
    if ($count[$cell_idx] > 0) {
      $MMSWE[$cell_idx] /= $count[$cell_idx];
    }
    else {
      $MMSWE[$cell_idx] = -9999;
    }
  }
  $first = 1;
  foreach $ens_model (@ENS_MODELS) {
    $PCTL_FILE = "$OUTD/stot.$PROJECT_UC.$ens_model.f-c_mean.a-m_anom.qnt.xyzz";
    open(PCTL_FILE, $PCTL_FILE) or die "$0: ERROR: cannot open file $PCTL_FILE for reading\n";
    $cell_idx = 0;
    foreach (<PCTL_FILE>) {
      chomp;
      @fields = split /\s+/;
      if ($first) {
        $MMSTOT[$cell_idx] = $fields[6];
      }
      else {
        $MMSTOT[$cell_idx] += $fields[6];
      }
      $cell_idx++;
    }
    close(PCTL_FILE);
    $nCells = $cell_idx;
    $first = 0;
  }
  for ($cell_idx=0; $cell_idx<$nCells; $cell_idx++) {
    $MMSTOT[$cell_idx] /= $nModels;
  }
}

# Loop over grid cells
open(FLIST,$FLIST) or die "$0: ERROR: cannot open file $FLIST for reading\n";
$cell_idx = 0;
foreach $F (<FLIST>) {
  chomp $F;
  $F =~ s/fluxes/$OutputPrefix/g;
  $HFILE = "$HISTPATH/$F";
  $CFILE = "$CURRPATH/$F";
  print "$cell_idx $F\n";
  # Current day's values
  # For individual models, read ascii model results
  if ($MODEL !~ /multimodel/i) {
    $CurrSoilMoist = -1;
    $CurrSoilMoist1 = -1;
    $CurrSoilMoist2 = -1;
    $CurrSoilMoist3 = -1;
    $CurrSWE = -1;
    $CurrSTOT = -1;
    open(CFILEH, $CFILE) or die "$0: ERROR: cannot open file $CFILE for reading\n";
    foreach (<CFILEH>) {
      chomp;
      @fields = split /\s+/;
      if ($fields[0]*1 == $fyear*1 && $fields[1]*1 == $fmonth*1 && $fields[2]*1 == $fday*1) {
        $CurrSoilMoist = 0;
        foreach $col (@SMCols) {
          $CurrSoilMoist += $fields[$col];
        }
        if ($MODEL =~ /vic/i) {
          $CurrSoilMoist1 = $fields[8];
          $CurrSoilMoist2 = $fields[9];
          $CurrSoilMoist3 = $fields[10];
        }
        $CurrSWE = $fields[$SWECol];
        if ($CurrSoilMoist >= 0 && $CurrSWE >= 0) {
          $CurrSTOT = $CurrSoilMoist + $CurrSWE;
        }
      }
    }
    close(CFILEH);
    if ($CurrSoilMoist == -1 || $CurrSWE == -1) {
      die "$0: ERROR: no info for $fyear-$fmonth-$fday found in file $CFILE\n";
    }
  }
  # For multimodel, use values computed before this loop over grid cells
  else {
    $CurrSoilMoist = $MMSoilMoist[$cell_idx];
    $CurrSWE = $MMSWE[$cell_idx];
    $CurrSTOT = $MMSTOT[$cell_idx];
  }
  $cell_idx++;

  # climatological distributions
  # Grand distribution of all values in the $width-day window centered on the current day.
  @HistSoilMoist = ();
  @HistSoilMoist1 = ();
  @HistSoilMoist2 = ();
  @HistSoilMoist3 = ();
  @HistSWE = ();
  @HistSTOT = ();
  @year = ();
  @month = ();
  @day = ();
  $i = 0;
  open(HFILEH, $HFILE) or die "$0: ERROR: cannot open file $HFILE for reading\n";
  foreach (<HFILEH>) {
    chomp;
    @fields = split /\s+/;
    ($year,$month,$day) = @fields[0..2];

    # Compute current day of year
    $julian_day = $day;
    for ($mon=1; $mon<$month; $mon++) {
      $days_in_month = $month_days[$mon-1];
      if ($year % 4 == 0 && $month == 2) {
        $days_in_month++;
      }
      $julian_day += $days_in_month;
    }

    # Check: is this record's day in the grand distribution?
    $found = 0;
    foreach $day_to_get (@days_to_get) {
      if ($day_to_get == $julian_day) {
        $found = 1;
      }
    }

    if ($year >= $SYR && $year <= $EYR && $found) {
      $HistSoilMoist[$i] = 0;
      foreach $col (@SMCols) {
        $HistSoilMoist[$i] += $fields[$col];
      }
      if ($MODEL =~ /vic/i) {
        $HistSoilMoist1[$i] = $fields[8];
        $HistSoilMoist2[$i] = $fields[9];
        $HistSoilMoist3[$i] = $fields[10];
      }
      $HistSWE[$i] = $fields[$SWECol];
      if ($MODEL !~ /multimodel/i) {
        $HistSTOT[$i] = $HistSoilMoist[$i] + $HistSWE[$i];
      }
      else {
        $HistSTOT[$i] = $fields[$STOTCol];
      }
      $i++;
    }
  }
  close(HFILEH);

  # Sort the distributions
  @HistSoilMoistSorted = sort { $a <=> $b; } @HistSoilMoist;
  if ($MODEL =~ /vic/i) {
    @HistSoilMoist1Sorted = sort { $a <=> $b; } @HistSoilMoist1;
    @HistSoilMoist2Sorted = sort { $a <=> $b; } @HistSoilMoist2;
    @HistSoilMoist3Sorted = sort { $a <=> $b; } @HistSoilMoist3;
  }
  @HistSWESorted = sort { $a <=> $b; } @HistSWE;
  @HistSTOTSorted = sort { $a <=> $b; } @HistSTOT;

  # Record the values
  # SoilMoist
  print SMFILE "$CurrSoilMoist";
  foreach (@HistSoilMoistSorted) {
    print SMFILE " $_";
  }
  print SMFILE "\n";
  # SWE
  print SWEFILE "$CurrSWE";
  foreach (@HistSWESorted) {
    print SWEFILE " $_";
  }
  print SWEFILE "\n";
  # STOT
  print STOTFILE "$CurrSTOT";
  foreach (@HistSTOTSorted) {
    print STOTFILE " $_";
  }
  print STOTFILE "\n";
  # Layer-specific SoilMoist
  if ($MODEL =~ /vic/i) {
    print SM1FILE "$CurrSoilMoist1";
    foreach (@HistSoilMoist1Sorted) {
      print SM1FILE " $_";
    }
    print SM1FILE "\n";
    print SM2FILE "$CurrSoilMoist2";
    foreach (@HistSoilMoist2Sorted) {
      print SM2FILE " $_";
    }
    print SM2FILE "\n";
    print SM3FILE "$CurrSoilMoist3";
    foreach (@HistSoilMoist3Sorted) {
      print SM3FILE " $_";
    }
    print SM3FILE "\n";
  }

}
close(FLIST);
close(SMFILE);
close(SWEFILE);
close(STOTFILE);
if ($MODEL =~ /vic/i) {
  close(SM1FILE);
  close(SM2FILE);
  close(SM3FILE);
}

# Find percentiles, anomalies
# SM
$cmd = "$TOOLS_DIR/fcst_stats.pl $SMFILE $OUTD/sm.$PROJECT_UC.$MODEL.stats";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
$cmd = "/usr/bin/paste $LONLAT $OUTD/sm.$PROJECT_UC.$MODEL.stats > $OUTD/sm.$PROJECT_UC.$MODEL.f-c_mean.a-m_anom.qnt.xyzz";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
# SWE
$cmd = "$TOOLS_DIR/fcst_stats.pl $SWEFILE $OUTD/swe.$PROJECT_UC.$MODEL.stats";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
$cmd = "/usr/bin/paste $LONLAT $OUTD/swe.$PROJECT_UC.$MODEL.stats > $OUTD/swe.$PROJECT_UC.$MODEL.f-c_mean.a-m_anom.qnt.xyzz";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
# STOT
$cmd = "$TOOLS_DIR/fcst_stats.pl $STOTFILE $OUTD/stot.$PROJECT_UC.$MODEL.stats";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
$cmd = "/usr/bin/paste $LONLAT $OUTD/stot.$PROJECT_UC.$MODEL.stats > $OUTD/stot.$PROJECT_UC.$MODEL.f-c_mean.a-m_anom.qnt.xyzz";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
# Layer-specific SoilMoist
if ($MODEL =~ /vic/i) {
  $cmd = "$TOOLS_DIR/fcst_stats.pl $SM1FILE $OUTD/sm1.$PROJECT_UC.$MODEL.stats";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
  $cmd = "/usr/bin/paste $LONLAT $OUTD/sm1.$PROJECT_UC.$MODEL.stats > $OUTD/sm1.$PROJECT_UC.$MODEL.f-c_mean.a-m_anom.qnt.xyzz";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
  $cmd = "$TOOLS_DIR/fcst_stats.pl $SM2FILE $OUTD/sm2.$PROJECT_UC.$MODEL.stats";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
  $cmd = "/usr/bin/paste $LONLAT $OUTD/sm2.$PROJECT_UC.$MODEL.stats > $OUTD/sm2.$PROJECT_UC.$MODEL.f-c_mean.a-m_anom.qnt.xyzz";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
  $cmd = "$TOOLS_DIR/fcst_stats.pl $SM3FILE $OUTD/sm3.$PROJECT_UC.$MODEL.stats";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
  $cmd = "/usr/bin/paste $LONLAT $OUTD/sm3.$PROJECT_UC.$MODEL.stats > $OUTD/sm3.$PROJECT_UC.$MODEL.f-c_mean.a-m_anom.qnt.xyzz";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
}

# Clean up
$cmd = "\\rm -f $OUTD/*.stats";
(system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
# SM
$cmd = "\\rm -f $SMFILE.gz";
(system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
$cmd = "gzip $SMFILE";
(system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
# SWE
$cmd = "\\rm -f $SWEFILE.gz";
(system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
$cmd = "gzip $SWEFILE";
(system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
# STOT
$cmd = "\\rm -f $STOTFILE.gz";
(system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
$cmd = "gzip $STOTFILE";
(system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
# Layer-specific SoilMoist
if ($MODEL =~ /vic/i) {
  $cmd = "\\rm -f $SM1FILE.gz";
  (system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
  $cmd = "gzip $SM1FILE";
  (system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
  $cmd = "\\rm -f $SM2FILE.gz";
  (system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
  $cmd = "gzip $SM2FILE";
  (system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
  $cmd = "\\rm -f $SM3FILE.gz";
  (system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
  $cmd = "gzip $SM3FILE";
  (system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
}

