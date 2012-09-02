#!/usr/bin/perl -w
# Script that shifts data from the current spinup area to the near-real-time archive.
#
#----------------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------
# Determine tools, root, and config directories - assume this script lives in ROOT_DIR/tools/
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

#----------------------------------------------------------------------------------------------
# Command-line arguments
#----------------------------------------------------------------------------------------------
$PROJECT = shift;

#----------------------------------------------------------------------------------------------
# Set up constants
#----------------------------------------------------------------------------------------------

# Unique identifier for this job
$JOB_ID = `date +%y%m%d-%H%M%S`;
if ($JOB_ID =~ /(\S+)/) {
  $JOB_ID = $1;
}

# Read project configuration info
$ConfigProject = "$CONFIG_DIR/config.project.$PROJECT";
$var_info_project_ref = &read_config($ConfigProject);
%var_info_project = %{$var_info_project_ref};

# Save relevant info
$NearRTSubDir  = $var_info_project{"NEAR_RT_SUBDIR"};
$CurrSubDir  = $var_info_project{"CURR_SUBDIR"};
$ForcNearRTDir  = $var_info_project{"FORCING_NEAR_RT_DIR"};
$ForcCurrDir  = $var_info_project{"FORCING_CURRSPIN_DIR"};
$AscVicSubDir  = $var_info_project{"FORCING_TYPE_ASC_VIC"};
$AscDisSubDir  = $var_info_project{"FORCING_TYPE_ASC_DIS"};
$StateNearRTDir  = $var_info_project{"STATE_MODEL_DIR"};
$StateNearRTDir =~ s/<STATE_SUBDIR>/$NearRTSubDir/;
$StateCurrDir  = $var_info_project{"STATE_MODEL_DIR"};
$StateCurrDir =~ s/<STATE_SUBDIR>/$CurrSubDir/;
$ResultsNearRTAscDir  = $var_info_project{"RESULTS_MODEL_RAW_DIR"};
$ResultsNearRTAscDir =~ s/<STATE_SUBDIR>/$NearRTSubDir/;
$ResultsNearRTAscDir =~ s/<RESULTS_TYPE>/asc/;
$ResultsCurrAscDir  = $var_info_project{"RESULTS_MODEL_RAW_DIR"};
$ResultsCurrAscDir =~ s/<STATE_SUBDIR>/$CurrSubDir/;
$ResultsCurrAscDir =~ s/<RESULTS_TYPE>/asc/;
$NCSubDir  = $var_info_project{"FORCING_TYPE_NC"};
$ModelList    = $var_info_project{"MODEL_LIST"};
@models = split /,/, $ModelList;

# Check for directories
##foreach $dir ($ForcCurrDir, "$ForcCurrDir/$AscVicSubDir", "$ForcCurrDir/$NCSubDir", $ForcNearRTDir, "$ForcNearRTDir/$AscVicSubDir", "$ForcNearRTDir/$NCSubDir") {
foreach $dir ($ForcCurrDir, "$ForcCurrDir/$AscVicSubDir", $ForcNearRTDir, "$ForcNearRTDir/$AscVicSubDir") {
  if (!-d $dir) {
    die "$0: ERROR: directory $dir not found\n";
  }
}

#----------------------------------------------------------------------------------------------
# END settings
#----------------------------------------------------------------------------------------------


#----------------------------------------------------------------------------------------------
# Shift forcings
#----------------------------------------------------------------------------------------------
# Append ascii forcings
$cmd = "$TOOLS_DIR/wrap_append.pl $ForcCurrDir/$AscVicSubDir $ForcNearRTDir/$AscVicSubDir";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

# Move netcdf forcings
###$cmd = "mv $ForcCurrDir/$NCSubDir/* $ForcNearRTDir/$NCSubDir/";
###print "$cmd\n";
##(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";


#----------------------------------------------------------------------------------------------
# Shift model state files, results, and other miscellaneous files
#----------------------------------------------------------------------------------------------
foreach $model (@models) {
  # Read model configuration info
  $ConfigModel = "$CONFIG_DIR/config.model.$model";
  $var_info_model_ref = &read_config($ConfigModel);
  %var_info_model = %{$var_info_model_ref};
  if ($var_info_model{"MODEL_TYPE"} eq "real")
  {$ForcingType = $var_info_model{"FORCING_TYPE"};
  $ModelType = $var_info_model{"MODEL_TYPE"};
  $StateNearRTModelDir = $StateNearRTDir;
  $StateNearRTModelDir =~ s/<MODEL_SUBDIR>/$var_info_model{"MODEL_SUBDIR"}/;
  $StateCurrModelDir = $StateCurrDir;
  $StateCurrModelDir =~ s/<MODEL_SUBDIR>/$var_info_model{"MODEL_SUBDIR"}/;
  $ResultsNearRTModelAscDir = $ResultsNearRTAscDir;
  $ResultsNearRTModelAscDir =~ s/<MODEL_SUBDIR>/$var_info_model{"MODEL_SUBDIR"}/;
  $ResultsNearRTModelAscDir =~ s/<RESULTS_SUBDIR>/spinup_nearRT/;
  $ResultsNearRTModelNCDir = $ResultsNearRTModelAscDir;
  $ResultsNearRTModelNCDir =~ s/asc/nc/;
  $ResultsCurrModelAscDir = $ResultsCurrAscDir;
  $ResultsCurrModelAscDir =~ s/<MODEL_SUBDIR>/$var_info_model{"MODEL_SUBDIR"}/;
  $ResultsCurrModelAscDir =~ s/<RESULTS_SUBDIR>/curr_spinup/;
  $ResultsCurrModelNCDir = $ResultsCurrModelAscDir;
  $ResultsCurrModelNCDir =~ s/asc/nc/;

  # Move state files to nearRT
  $cmd = "mv $StateCurrModelDir/* $StateNearRTModelDir/";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

  # Append ascii results to nearRT
  $cmd = "$TOOLS_DIR/wrap_append.pl $ResultsCurrModelAscDir $ResultsNearRTModelAscDir";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

  # Move netcdf results to nearRT
  ##if ($ForcingType eq "nc" && $ModelType eq "real" ) {
    ###$cmd = "mv $ResultsCurrModelNCDir/* $ResultsNearRTModelNCDir/";
    ##print "$cmd\n";
    ##(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
  ##}
}
}

