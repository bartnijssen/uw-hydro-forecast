#!/usr/bin/env perl
use warnings;

# Wrapper script that calls programs to convert ascii forcings to netcdf
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
use POSIX qw(strftime);

#-------------------------------------------------------------------------------
# Command-line arguments
#-------------------------------------------------------------------------------
$PROJECT = shift;

# These next arguments are optional - can be omitted
$currspin_start_date_override = shift;
$currspin_end_date_override   = shift;

#-------------------------------------------------------------------------------
# Set up constants
#-------------------------------------------------------------------------------
# Unique identifier for this job
$JOB_ID = strftime "%y%m%d-%H%M%S", localtime;

# Configuration files
$ConfigProject = "$CONFIG_DIR/config.project.$PROJECT";

# Project configuration info
$var_info_project_ref = &read_config($ConfigProject);
%var_info_project     = %{$var_info_project_ref};

# HACK -- not sure why these hardwired paths are here - Bart
# Should be moved to config Tue Sep 25 2012
$ForcAscVicDir = $var_info_project{"FORCING_CURRSPIN_DIR"} . "/asc_vicinp";
$ForcAscDisDir = $var_info_project{"FORCING_CURRSPIN_DIR"} . "/asc_disagg";
$ForcNCDir     = $var_info_project{"FORCING_CURRSPIN_DIR"} . "/nc";
$ParamsDir     = $var_info_project{"PARAMS_DIR"};
$ControlDir    = $var_info_project{"CONTROL_DIR"};
$LogDir        = $var_info_project{"LOGS_GRID_DIR"};
$CurrspinStartDateFile = $var_info_project{"FORCING_CURRSPIN_START_DATE_FILE"};
$CurrspinEndDateFile   = $var_info_project{"FORCING_CURRSPIN_END_DATE_FILE"};
$LogFile               = "$LogDir/log.update_forcings_nc.pl.$JOB_ID";

# Check for directories; create if necessary & appropriate
foreach $dir ($ForcAscVicDir, $ParamsDir) {
  if (!-d $dir) {
    die "$0: ERROR: directory $dir not found\n";
  }
}
foreach $dir ($ForcAscDisDir, $ForcNCDir, $ControlDir, $LogDir) {
  $status = &make_dir($dir);
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
    ($Forc_Eyr, $Forc_Emon, $Forc_Eday) = ($1, $2, $3);
  }
}
close(FILE);

# Optional overriding of dates in files
if ($currspin_start_date_override) {
  ($Syr, $Smon, $Sday) = split /-/, $currspin_start_date_override;
}
if ($currspin_end_date_override) {
  ($Forc_Eyr, $Forc_Emon, $Forc_Eday) = split /-/, $currspin_end_date_override;
}

# Date strings
$start_date_str = sprintf "%04d-%02d-%02d", $Syr,      $Smon,      $Sday;
$end_date_str   = sprintf "%04d-%02d-%02d", $Forc_Eyr, $Forc_Emon, $Forc_Eday;

#-------------------------------------------------------------------------------
# END settings
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# Conversion of Forcings
#-------------------------------------------------------------------------------
# Disaggregate forcings from daily to sub-daily
$cmd =
  "$TOOLS_DIR/run_vicDisagg.pl $TOOLS_DIR $ParamsDir/vicDisagg " .
  "$ControlDir/vicDisagg $ForcAscVicDir $ForcAscDisDir $start_date_str " .
  "$end_date_str $start_date_str >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";

# Convert sub-daily forcings to netcdf format
# Needs to go to config - Bart - Tue Sep 25 2012
$prefix = "full_data";  # Put this in config file?
$cmd =
  "$TOOLS_DIR/run_vic2nc.pl $TOOLS_DIR " .
  "$ParamsDir/vic2nc/metadata.forcing.template $ControlDir/vic2nc " .
  "$ForcAscDisDir $ForcNCDir $start_date_str $end_date_str $prefix " .
  ">& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";

# Clean up tmp files
`rm -f $LogFile.tmp`;
