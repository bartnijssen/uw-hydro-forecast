#!/usr/bin/env perl
use warnings;

# Script for merging the model output statistics from a list of project domains into one
# larger domain.
#
#----------------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------
# Determine tools config directories
#----------------------------------------------------------------------------------------------
$TOOLS_DIR = "<SYSTEM_INSTALLDIR>/bin";
$CONFIG_DIR = "<SYSTEM_INSTALLDIR>/config";

#----------------------------------------------------------------------------------------------
# Include external modules
#----------------------------------------------------------------------------------------------
# Subroutine for reading config files
require "$TOOLS_DIR/simma_util.pl";

# Date arithmetic
use Date::Calc qw(Days_in_Month Delta_Days Add_Delta_Days);
use POSIX qw(strftime);

#----------------------------------------------------------------------------------------------
# Command-line arguments
#----------------------------------------------------------------------------------------------
$PROJECT = shift;
$MODEL = shift;
$fyear = shift;  # Output forecast date
$fmonth = shift; # Output forecast date
$fday = shift;   # Output forecast date
$explicit = shift;  # 0 (or omitted) = get sub-project forecasts from "merge_depot"; 1 = get them
                    # from directories of the exact same date as the output forecast date

if (!$fyear || !$fmonth || !$fday) {
  die "$0: ERROR: forecast year, month, and day must be supplied as command-line arguments\n";
}

#----------------------------------------------------------------------------------------------
# Set up constants
#----------------------------------------------------------------------------------------------

# Unique identifier for this job
$JOB_ID = strftime "%y%m%d-%H%M%S", localtime;

# Derived variables
$PROJECT_UC = $PROJECT;
$PROJECT =~ tr/A-Z/a-z/;
$PROJECT_UC =~ tr/a-z/A-Z/;
$DateOut = sprintf "%04d%02d%02d", $fyear, $fmonth, $fday;

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

# Save relevant info
$ProjectType = $var_info_project{"PROJECT_TYPE"};
if ($ProjectType =~ /merge/i) {
  $SubProjectList = $var_info_project{"PROJECT_MERGE_LIST"};
  @SubProjects = split /,/, $SubProjectList;
}
$CurrspinEndDateFile   = $var_info_project{"FORCING_CURRSPIN_END_DATE_FILE"};
$XYZZDir               = $var_info_project{"XYZZ_DIR"};
########### $LogDir = $var_info_project{"LOGS_MODEL_DIR"};
########### $LogDir =~ s/<LOGS_SUBDIR>/curr_spinup/;

$StatVarList = $var_info_model{"STAT_VARS"};
$PlotVarList = $var_info_model{"PLOT_VARS"};
@varnames = split /,/, $StatVarList;
@varnames_tmp = split /,/, $PlotVarList;
foreach $varname_tmp (@varnames_tmp) {
  $found = 0;
  INNER_LOOP: foreach $varname (@varnames) {
    if ($varname eq $varname_tmp) {
      $found = 1;
      last INNER_LOOP;
    }
  }
  if (!$found) {
    push @varnames, $varname_tmp;
  }
}

########### $LogFile = "$LogDir/log.nowcast_model.pl.$JOB_ID";

########### # Check for directories; create if necessary & appropriate
########### foreach $dir ($LogDir) {
###########   $status = &make_dir($dir);
########### }

# Get info for each subproject in the list
for ($proj_idx=0; $proj_idx<@SubProjects; $proj_idx++) {

  # Read subproject config file
  $ConfigProject = "$CONFIG_DIR/config.project.$SubProjects[$proj_idx]";
  $var_info_project_ref = &read_config($ConfigProject);
  %var_info_project = %{$var_info_project_ref};

  # Substitute model-specific information into project variables
  foreach $key_proj (keys(%var_info_project)) {
    foreach $key_model (keys(%var_info_model)) {
      $var_info_project{$key_proj} =~ s/<$key_model>/$var_info_model{$key_model}/g;
    }
  }

  # Save relevant info
#  $CurrspinEndDateFileSub[$proj_idx]   = $var_info_project{"FORCING_CURRSPIN_END_DATE_FILE"};
  $XYZZDirSub[$proj_idx]               = $var_info_project{"XYZZ_DIR"};
  $MergeDepotDirSub[$proj_idx]         = $var_info_project{"MERGE_DEPOT_DIR"};
#  $LogDir = $var_info_project{"LOGS_MODEL_DIR"};
#  $LogDir =~ s/<LOGS_SUBDIR>/curr_spinup/;

  # Check for directories; create if necessary & appropriate
#  foreach $dir ($LogDir) {
#    $status = &make_dir($dir);
#  }

    $SubProjectUC[$proj_idx] = $SubProjects[$proj_idx];
    $SubProjectUC[$proj_idx] =~ tr/a-z/A-Z/;
}

# Directories
for ($proj_idx=0; $proj_idx<@SubProjects; $proj_idx++) {
  if ($explicit) {
    $IND[$proj_idx] = "$XYZZDirSub[$proj_idx]/$DateOut";
  }
  else {
    $IND[$proj_idx] = "$MergeDepotDirSub[$proj_idx]";
  }
  if (!-e $IND[$proj_idx]) {
    die "$0: ERROR: input directory $IND[$proj_idx] not found\n";
  }
}
$OUTD = "$XYZZDir/$DateOut";
$status = &make_dir($OUTD);

#----------------------------------------------------------------------------------------------
# END settings
#----------------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------
# Loop over all stats variables for the given model, merging stats files from all projects
#----------------------------------------------------------------------------------------------
for ($var_idx=0; $var_idx<@varnames; $var_idx++) {

  if ($varnames[$var_idx] ne "ro") {
    $ext = "f-c_mean.a-m_anom.qnt.xyzz";
  }
  else {
    $ext = "qnt.xyzz";
  }

  $first = 1;
  for ($proj_idx=0; $proj_idx<@SubProjects; $proj_idx++) {
    if ($first) {
      $cmd = "cp $IND[$proj_idx]/$varnames[$var_idx].$SubProjectUC[$proj_idx].$MODEL.$ext $OUTD/$varnames[$var_idx].$PROJECT_UC.$MODEL.$ext";
      $first = 0;
    }
    else {
      $cmd = "cat $IND[$proj_idx]/$varnames[$var_idx].$SubProjectUC[$proj_idx].$MODEL.$ext >> $OUTD/$varnames[$var_idx].$PROJECT_UC.$MODEL.$ext";
    }
#    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
  }
 
}

## Clean up tmp files
#`rm -f $LogFile.tmp`;

