#!/usr/bin/perl -w
# get_stats.pl: Script to convert model results into percentiles of model climatology
#
# Author: Ted Bohn
#
# Modifications:
# 2008-12-08 Modified to read previously-compiled distributions of the various variables
#            instead of going through the retrospective results and computing these
#            distributions on the fly.						TJB
#
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

$MODEL = shift;
$PROJECT = shift;
$fyear = shift;
$fmonth = shift;
$fday = shift;
$results_subdir_override = shift; # By default, results are taken from curr_spinup, but this can be overridden here

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
$swe_thresh         = $var_info_project{"SWE_THRESH"};
$ResultsModelAscDir = $var_info_project{"RESULTS_MODEL_ASC_DIR"};
$ResultsModelDistDir= $var_info_project{"RESULTS_MODEL_DIST_DIR"};
$XYZZDir            = $var_info_project{"XYZZ_DIR"};
$LONLAT             = $var_info_project{"LONLAT_LIST"};
$FLIST              = $var_info_project{"FLUX_FLIST"};
$SYR                = $var_info_project{"CLIM_START_YR"}; # Climatology start year
$EYR                = $var_info_project{"CLIM_END_YR"}; # Climatology end year
$width              = $var_info_project{"WINDOW_WIDTH"}; # width of window (days) about forecast day for grand distribution
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
$StatVarList = $var_info_model{"STAT_VARS"};
@varnames = split /,/, $StatVarList;
$var_idx_sm = -1;
$var_idx_sm1 = -1;
$var_idx_sm2 = -1;
$var_idx_sm3 = -1;
$var_idx_swe = -1;
$var_idx_stot = -1;
for ($var_idx=0; $var_idx<@varnames; $var_idx++) {
  if ($varnames[$var_idx] eq "sm") {
    $var_idx_sm = $var_idx;
  }
  if ($varnames[$var_idx] eq "sm1") {
    $var_idx_sm1 = $var_idx;
  }
  if ($varnames[$var_idx] eq "sm2") {
    $var_idx_sm2 = $var_idx;
  }
  if ($varnames[$var_idx] eq "sm3") {
    $var_idx_sm3 = $var_idx;
  }
  if ($varnames[$var_idx] eq "swe") {
    $var_idx_swe = $var_idx;
  }
  if ($varnames[$var_idx] eq "stot") {
    $var_idx_stot = $var_idx;
  }
}

# Directories and files
$CURRPATH = $ResultsModelFinalDir;
if ($results_subdir_override) {
  $CURRPATH =~ s/<RESULTS_SUBDIR>/$results_subdir_override/g;
}
else {
  $CURRPATH =~ s/<RESULTS_SUBDIR>/curr_spinup/g;
}
$DISTPATH = $ResultsModelDistDir;
$DISTPATH =~ s/<RESULTS_SUBDIR>/retro/g;
$OUTD = "$XYZZDir/$DATE";
if ($MODEL =~ /multimodel/i) {
  $CURRPATH = $OUTD;
}

$nodata = -9999;

#----------------------------------------------------------------------------------------------
# END settings
#----------------------------------------------------------------------------------------------

# Check for directories; create if necessary & possible
foreach $dir ($CURRPATH, $DISTPATH) {
  if (!-d $dir) {
    die "$0: ERROR: directory $dir not found\n";
  }
}
foreach $dir ($OUTD) {
  $status = &make_dir($dir);
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
  elsif ($day > 365) {
    $day -= 365;
  }
  push @days_to_get, $day; 
}

#------------------------------------------------------------------------------------------
# Get current & historic distribution for sm & snow for specified date, sorted
#------------------------------------------------------------------------------------------

# For multimodel, current values are average of other models' pctls;
# Pctls have different format than model results
if ($MODEL =~ /multimodel/i) {
  for ($var_idx=0; $var_idx<@varnames; $var_idx++) {
    $first = 1;
    foreach $ens_model (@ENS_MODELS) {
      $PCTL_FILE = "$OUTD/$varnames[$var_idx].$PROJECT_UC.$ens_model.f-c_mean.a-m_anom.qnt.xyzz";
      open(PCTL_FILE, $PCTL_FILE) or die "$0: ERROR: cannot open file $PCTL_FILE for reading\n";
      $cell_idx = 0;
      foreach (<PCTL_FILE>) {
        chomp;
        @fields = split /\s+/;
        if ($varnames[$var_idx] eq "swe") {
          if ($first) {
    	    $count[$cell_idx] = 0;
            $CurrData[$var_idx][$cell_idx] = -9999;
          }
          if ($fields[2] > $swe_thresh) {
            if ($count[$cell_idx]==0) {
              $CurrData[$var_idx][$cell_idx] = $fields[6];
            }
            else {
              $CurrData[$var_idx][$cell_idx] += $fields[6];
            }
       	    $count[$cell_idx]++;
          }
	}
	else {
          if ($first) {
            $CurrData[$var_idx][$cell_idx] = $fields[6];
          }
          else {
            $CurrData[$var_idx][$cell_idx] += $fields[6];
          }
        }
        $cell_idx++;
      }
      close(PCTL_FILE);
      $nCells = $cell_idx;
      $first = 0;
    }
    if ($varnames[$var_idx] eq "swe") {
      for ($cell_idx=0; $cell_idx<$nCells; $cell_idx++) {
        if ($count[$cell_idx] > 0) {
          $CurrData[$var_idx][$cell_idx] /= $count[$cell_idx];
        }
        else {
          $CurrData[$var_idx][$cell_idx] = -9999;
        }
      }
    }
    else {
      for ($cell_idx=0; $cell_idx<$nCells; $cell_idx++) {
        $CurrData[$var_idx][$cell_idx] /= $nModels;
      }
    }
  }
}

# For individual models, read model ascii output files to get current values
else {

  # Loop over grid cells
  open(FLIST,$FLIST) or die "$0: ERROR: cannot open file $FLIST for reading\n";
  $cell_idx = 0;
  foreach $F (<FLIST>) {
    chomp $F;
    $F =~ s/fluxes/$OutputPrefix/g;
    $CFILE = "$CURRPATH/$F";

    # Initialize data
    for ($var_idx=0; $var_idx<@varnames; $var_idx++) {
      $CurrData[$var_idx][$cell_idx] = -1;
    }

    # Get current day's data
    open(CFILEH, $CFILE) or die "$0: ERROR: cannot open file $CFILE for reading\n";
    foreach (<CFILEH>) {
      chomp;
      @fields = split /\s+/;
      if ($fields[0]*1 == $fyear*1 && $fields[1]*1 == $fmonth*1 && $fields[2]*1 == $fday*1) {
        $CurrData[$var_idx_sm][$cell_idx] = 0;
        foreach $col (@SMCols) {
          $CurrData[$var_idx_sm][$cell_idx] += $fields[$col];
        }
        if ($MODEL =~ /vic/i) {
          $CurrData[$var_idx_sm1][$cell_idx] = $fields[8];
          $CurrData[$var_idx_sm2][$cell_idx] = $fields[9];
          $CurrData[$var_idx_sm3][$cell_idx] = $fields[10];
        }
        $CurrData[$var_idx_swe][$cell_idx] = $fields[$SWECol];
        if ($CurrData[$var_idx_sm][$cell_idx] >= 0 && $CurrData[$var_idx_swe][$cell_idx] >= 0) {
          $CurrData[$var_idx_stot][$cell_idx] = $CurrData[$var_idx_sm][$cell_idx] + $CurrData[$var_idx_swe][$cell_idx];
        }
      }
    }
    close(CFILEH);
    if ($CurrData[$var_idx_sm][$cell_idx] == -1 || $CurrData[$var_idx_swe][$cell_idx] == -1) {
      die "$0: ERROR: no info for $fyear-$fmonth-$fday found in file $CFILE\n";
    }
    $cell_idx++;

  }
  $nCells = $cell_idx;

}

# Climatological distributions
# Grand distribution of all values in the $width-day window centered on the current day.
# For each variable, read distrib files for the days to get, sort the distributions,
# add the current values, and write to temp file
for ($var_idx=0; $var_idx<@varnames; $var_idx++) {

  # Read distributions of this variable for all days in window around current day
  # Combine the distributions of the individual days to form a grand distribution for the window
  @DistData = ();
  foreach $day_to_get (@days_to_get) {
    $DistFile = sprintf "%s/%s.%03d.txt", $DISTPATH, $varnames[$var_idx], $day_to_get;
    open (DFILE, $DistFile) or die "$0: ERROR: cannot open $DistFile for reading\n";
    $cell_idx = 0;
    foreach (<DFILE>) {
      chomp;
      push @{$DistData[$cell_idx]}, split /\s+/;
      $cell_idx++;
    }
    close(DFILE);
  }

  # Sort grand distribution, add current values, and write to tmp file
  $CurrAndDistFile = "$OUTD/$PROJECT_UC.$MODEL.$varnames[$var_idx].curr-srt_hist";
  open (CURRDIST, ">$CurrAndDistFile") or die "$0: ERROR: cannot open $CurrAndDistFile for writing\n";
  for ($cell_idx=0; $cell_idx<$nCells; $cell_idx++) {

    # Sort the grand distribution
    @DistDataSorted = sort { $a <=> $b; } @{$DistData[$cell_idx]};
#$ndist = @DistDataSorted;
#print "var $var_idx cell $cell_idx ndist $ndist\n";

    # Write to tmp file
    print CURRDIST "$CurrData[$var_idx][$cell_idx]";
    foreach $data (@DistDataSorted) {
      print CURRDIST " $data";
    }
    print CURRDIST "\n";

  }
  close(CURRDIST);

}

# Find percentiles, anomalies
for ($var_idx=0; $var_idx<@varnames; $var_idx++) {
  $CurrAndDistFile = "$OUTD/$PROJECT_UC.$MODEL.$varnames[$var_idx].curr-srt_hist";
  $cmd = "$TOOLS_DIR/fcst_stats.pl $CurrAndDistFile $OUTD/$varnames[$var_idx].$PROJECT_UC.$MODEL.stats $nodata";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
  $cmd = "/usr/bin/paste $LONLAT $OUTD/$varnames[$var_idx].$PROJECT_UC.$MODEL.stats > $OUTD/$varnames[$var_idx].$PROJECT_UC.$MODEL.f-c_mean.a-m_anom.qnt.xyzz";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
}

# Clean up
$cmd = "\\rm -f $OUTD/*.stats";
(system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
for ($var_idx=0; $var_idx<@varnames; $var_idx++) {
  $CurrAndDistFile = "$OUTD/$PROJECT_UC.$MODEL.$varnames[$var_idx].curr-srt_hist";
  $cmd = "\\rm -f $CurrAndDistFile.gz";
  (system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
  $cmd = "gzip $CurrAndDistFile";
  (system($cmd)==0) or die "$0: ERROR: cmd $cmd failed: $?\n";
}

