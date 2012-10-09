#!/usr/bin/env perl
use warnings;

# Script that "clears" or "resets" the current spinup forcings to 1 "dummy"
# record corresponding to a date specified by the user.  This prepares the
# current spinup forcing directory for regeneration of forcings.
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
use POSIX qw(strftime);

#-------------------------------------------------------------------------------
# Command-line arguments
#-------------------------------------------------------------------------------
$PROJECT      = shift;
$NewStartDate = shift;  # yyyy-mm-dd

#-------------------------------------------------------------------------------
# Set up constants
#-------------------------------------------------------------------------------
# Unique identifier for this job
$JOB_ID = strftime "%y%m%d-%H%M%S", localtime;

# Read project configuration info
$ConfigProject        = "$CONFIG_DIR/config.project.$PROJECT";
$var_info_project_ref = &read_config($ConfigProject);
%var_info_project     = %{$var_info_project_ref};

# Save relevant info
$NearRTForcDir         = $var_info_project{"FORCING_NEAR_RT_DIR"};
$CurrForcDir           = $var_info_project{"FORCING_CURRSPIN_DIR"};
$AscVicSubDir          = $var_info_project{"FORCING_TYPE_ASC_VIC"};
$AscDisSubDir          = $var_info_project{"FORCING_TYPE_ASC_DIS"};
$NCSubDir              = $var_info_project{"FORCING_TYPE_NC"};
$CurrspinStartDateFile = $var_info_project{"FORCING_CURRSPIN_START_DATE_FILE"};
$CurrspinEndDateFile   = $var_info_project{"FORCING_CURRSPIN_END_DATE_FILE"};

# Check for directories
foreach $dir (
              $NearRTForcDir, "$NearRTForcDir/$AscVicSubDir",
              $CurrForcDir,   "$CurrForcDir/$AscVicSubDir"
  ) {
  if (!-d $dir) {
    die "$0: ERROR: directory $dir not found\n";
  }
}

# Parse the date string
($year, $month, $day) = split /-/, $NewStartDate;

#-------------------------------------------------------------------------------
# END settings
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# Replace forcings with 1 dummy record taken from final near-real-time record
#-------------------------------------------------------------------------------
$cmd =
  "$TOOLS_DIR/wrap_tail.pl $NearRTForcDir/$AscVicSubDir 1 " .
  "$CurrForcDir/$AscVicSubDir";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";

#-------------------------------------------------------------------------------
# Modify start/end dates in the relevant files
#-------------------------------------------------------------------------------
# Start date
open(START_DATE_TMP, ">$CurrspinStartDateFile.tmp") or
  die "$0: ERROR: cannot open start_date file $CurrspinStartDateFile.tmp " .
  "for writing\n";
print START_DATE_TMP "$year $month $day    # DATE CURRENT RT FORCINGS START\n";
print START_DATE_TMP "# THIS IS A GENERATED FILE; DO NOT EDIT DATE ABOVE\n";
close(START_DATE_TMP);
$cmd = "mv $CurrspinStartDateFile.tmp $CurrspinStartDateFile";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";

# End date
open(END_DATE_TMP, ">$CurrspinEndDateFile.tmp") or
  die "$0: ERROR: cannot open end_date file $CurrspinEndDateFile.tmp " .
  "for writing\n";
print END_DATE_TMP "$year $month $day    # DATE CURRENT RT FORCINGS END\n";
print END_DATE_TMP "# THIS IS A GENERATED FILE; DO NOT EDIT DATE ABOVE\n";
close(END_DATE_TMP);
$cmd = "mv $CurrspinEndDateFile.tmp $CurrspinEndDateFile";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";

#-------------------------------------------------------------------------------
# Clean out other forcing directories
#-------------------------------------------------------------------------------
# Disaggregated ascii forcings
###$cmd = "/bin/rm -rf $CurrForcDir/$AscDisSubDir";
###print "$cmd\n";
##(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
# NetCDF forcings
##$cmd = "/bin/rm -rf $CurrForcDir/$NCSubDir";
##print "$cmd\n";
###(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
