#!/usr/bin/env perl
use warnings;

# Wrapper script for advancing the trusted state for the multi-model nowcast
# system
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# Determine tools and config directories
#-------------------------------------------------------------------------------
$TOOLS_DIR  = "<SYSTEM_INSTALLDIR>/bin";
$CONFIG_DIR = "<SYSTEM_INSTALLDIR>/config";

#-------------------------------------------------------------------------------
# Include external modules
#-------------------------------------------------------------------------------
use lib "<SYSTEM_SITEPERL_LIB>";
# Subroutine for reading config files
use simma_util;

# Date computation
use Date::Calc qw(Days_in_Month Delta_Days Add_Delta_Days);

# Access to environment variables
use Env;
use POSIX qw(strftime);

#-------------------------------------------------------------------------------
# Command-line arguments
#-------------------------------------------------------------------------------
$PROJECT = shift;

# This next argument is optional
$stage = shift;
if (!$stage) {
  $stage = 1;
}

#-------------------------------------------------------------------------------
# Set up constants
#-------------------------------------------------------------------------------
# Unique identifier for this job
$JOB_ID = strftime "%y%m%d-%H%M%S", localtime;

# Set up netcdf access
$ENV{INC_NETCDF} = "<SYSTEM_NETCDF_INC>";
$ENV{LIB_NETCDF} = "<SYSTEM_NETCDF_LIB>";

# Configuration files
$ConfigProject = "$CONFIG_DIR/config.project.$PROJECT";

# Project configuration info
$var_info_project_ref = &read_config($ConfigProject);
%var_info_project     = %{$var_info_project_ref};
$ProjectType          = $var_info_project{"PROJECT_TYPE"};
if ($ProjectType !~ /real/i) {
  die "$0: ERROR: Advancement of trusted state not supported for projects of " .
    "type $ProjectType\n";
}
$ModelList = $var_info_project{"MODEL_LIST"};
@models    = split /,/, $ModelList;
$EmailList = $var_info_project{"EMAIL_LIST"};
@emails    = split /,/, $EmailList;
$LogDir    = $var_info_project{"LOGS_CURRSPIN_DIR"} . "/advance_state";
$CurrspinStartDateFile = $var_info_project{"FORCING_CURRSPIN_START_DATE_FILE"};
$CurrspinEndDateFile   = $var_info_project{"FORCING_CURRSPIN_END_DATE_FILE"};
$LogFile               = "$LogDir/log.advance_state.pl.$JOB_ID";

# Check for directories; create if necessary & appropriate
foreach $dir ($LogDir) {
  (($status = &make_dir($dir)) == 0) or die "Error: Cannot make $dir: $status";
}

#-------------------------------------------------------------------------------
# Read dates from files
#-------------------------------------------------------------------------------
# Date of beginning of current spinup forcings
open(FILE, $CurrspinStartDateFile) or
  die "$0: ERROR: cannot open file $CurrspinStartDateFile\n";
foreach (<FILE>) {
  if (/^(\d+)\s+(\d+)\s+(\d+)\s+/) {
    ($Syr, $Smon, $Sday) = ($1, $2, $3);
  }
}
close(FILE);

# Date of end of current spinup forcings
open(FILE, $CurrspinEndDateFile) or
  die "$0: ERROR: cannot open file $CurrspinEndDateFile\n";
foreach (<FILE>) {
  if (/^(\d+)\s+(\d+)\s+(\d+)\s+/) {
    ($Eyr, $Emon, $Eday) = ($1, $2, $3);
  }
}
close(FILE);

# Set various dates
$OldStartDate = sprintf "%04d-%02d-%02d", $Syr, $Smon, $Sday;
@month_days = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
$TmpSday = $month_days[$Smon - 1];
if ($Syr % 4 == 0 && $Smon * 1 == 2) {
  $TmpSday++;
}
$TmpEndDate = sprintf "%04d-%02d-%02d", $Syr, $Smon, $TmpSday;
$Smon++;
if ($Smon > 12) {
  $Smon = "01";
  $Syr++;
}
$NewStartDate = sprintf "%04d-%02d-%02d", $Syr, $Smon, $Sday;
$NewEndDate   = sprintf "%04d-%02d-%02d", $Eyr, $Emon, $Eday;

#-------------------------------------------------------------------------------
# END settings
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# Clear out the current forcings and replace with "dummy" record corresponding
# to the first day of the current period.
#
# Reset the forcings to 1 record corresponding to OldStartDate (actual forcing
# data will come from last day of nearRT forcings; this will be replaced by real
# forcings in next stage)
#
#-------------------------------------------------------------------------------
if ($stage == 1) {
  $cmd =
    "$TOOLS_DIR/clear_curr_forcings.pl $PROJECT $OldStartDate >& " .
    "$LogFile.tmp";
  print "$cmd\n";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
  $cmd = "cat $LogFile.tmp >> $LogFile";
  print "$cmd\n";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
  $cmd = "rm -f $LogFile.tmp";
  print "$cmd\n";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
  $stage++;
}

#-------------------------------------------------------------------------------
# Update ascii forcings to consist of 1 month of gridded forcings starting on
# NewStartDate
#-------------------------------------------------------------------------------
if ($stage == 2) {
  $cmd =
    "$TOOLS_DIR/update_forcings_asc_advance_state.pl $PROJECT " .
    "$OldStartDate  $OldStartDate $TmpEndDate >& $LogFile.tmp";
  print "$cmd\n";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
  $cmd = "cat $LogFile.tmp >> $LogFile";
  print "$cmd\n";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
  $cmd = "rm -f $LogFile.tmp";
  print "$cmd\n";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
  $stage++;
}

#-------------------------------------------------------------------------------
# Run nowcast for models that use vic-style ascii forcings
#-------------------------------------------------------------------------------
if ($stage == 3) {
  foreach $model (@models) {
    $ConfigModel        = "$CONFIG_DIR/config.model.$model";
    $var_info_model_ref = &read_config($ConfigModel);
    %var_info_model     = %{$var_info_model_ref};
    $ForcingType        = $var_info_model{"FORCING_TYPE"};
    if ($ForcingType ne "nc") {
      $cmd =
        "$TOOLS_DIR/nowcast_model.pl $PROJECT $model model >& " .
        "$LogFile.tmp";
      print "$cmd\n";
      (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
      $cmd = "cat $LogFile.tmp >> $LogFile";
      print "$cmd\n";
      (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
      $cmd = "rm -f $LogFile.tmp";
      print "$cmd\n";
      (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
    }
  }

  # This should be generalized - Bart - Tue Sep 25 13:45:31 PDT 2012
  # Skipping netcdf forcings part and running model. Since we are not using any
  # other model but VIC. Needs top be changed when we are running multimodel
  $stage = 6;
}

#-------------------------------------------------------------------------------
# Generate netcdf forcings
#-------------------------------------------------------------------------------
if ($stage == 4) {

  # Check whether netcdf forcings are needed
  $need_netcdf = 0;
  foreach $model (@models) {

    # Read model configuration info
    $ConfigModel        = "$CONFIG_DIR/config.model.$model";
    $var_info_model_ref = &read_config($ConfigModel);
    %var_info_model     = %{$var_info_model_ref};
    $ForcingType        = $var_info_model{"FORCING_TYPE"};
    if ($ForcingType eq "nc") {
      $need_netcdf = 1;
    }
  }

  # Generate the netcdf forcings
  if ($need_netcdf) {
    $cmd = "$TOOLS_DIR/update_forcings_nc.pl $PROJECT >& $LogFile.tmp";
    print "$cmd\n";
    (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
    $cmd = "cat $LogFile.tmp >> $LogFile";
    print "$cmd\n";
    (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
    $cmd = "rm -f $LogFile.tmp";
    print "$cmd\n";
    (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
  }
  $stage++;
}

#-------------------------------------------------------------------------------
# Run nowcast for models that use netcdf forcings
#-------------------------------------------------------------------------------
if ($stage == 5) {
  foreach $model (@models) {

    # Read model configuration info
    $ConfigModel        = "$CONFIG_DIR/config.model.$model";
    $var_info_model_ref = &read_config($ConfigModel);
    %var_info_model     = %{$var_info_model_ref};
    $ForcingType        = $var_info_model{"FORCING_TYPE"};
    if ($ForcingType eq "nc") {
      $cmd =
        "$TOOLS_DIR/nowcast_model.pl $PROJECT $model model >& " .
        "$LogFile.tmp";
      print "$cmd\n";
      (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
      $cmd = "cat $LogFile.tmp >> $LogFile";
      print "$cmd\n";
      (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
      $cmd = "rm -f $LogFile.tmp";
      print "$cmd\n";
      (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
    }
  }
  $stage++;
}

#-------------------------------------------------------------------------------
# Shift forcings, results, and state files for this month into the
# near-real-time archive
#-------------------------------------------------------------------------------
if ($stage == 6) {
  $cmd = "$TOOLS_DIR/shift_data_to_nearRT.pl $PROJECT >& $LogFile.tmp";
  print "$cmd\n";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
  $cmd = "cat $LogFile.tmp >> $LogFile";
  print "$cmd\n";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
  $cmd = "rm -f $LogFile.tmp";
  print "$cmd\n";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
  $stage++;
}

#-------------------------------------------------------------------------------
# Announce completion of state advancement
#-------------------------------------------------------------------------------
####$subject = "\"[Surface Water Monitor] State Advance $PROJECT complete\"";
###$addresses = join " ", @emails;
###$cmd = "echo OK | /bin/mail $addresses -s $subject";
#`echo $cmd >> $LogFile`;
#if (system($cmd)!=0) {
#  `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
#  die "$0: ERROR: $cmd failed: $?\n";
#}
###print "$cmd\n";
####(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
# Clean up tmp files
`rm -f $LogFile.tmp`;
