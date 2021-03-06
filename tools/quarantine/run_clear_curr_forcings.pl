#!<SYSTEM_PERL_EXE> -w
# Stage 7 from old advance_state.pl
#-------------------------------------------------------------------------------
use lib qw(<SYSTEM_INSTALLDIR>/lib <SYSTEM_PERL_LIBS>);

#-------------------------------------------------------------------------------
# Determine tools and config directories
#-------------------------------------------------------------------------------
$TOOLS_DIR  = "<SYSTEM_INSTALLDIR>/bin";
$CONFIG_DIR = "<SYSTEM_INSTALLDIR>/config";

#-------------------------------------------------------------------------------
# Include external modules
#-------------------------------------------------------------------------------
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
$LogFile               = "$LogDir/log.clear_curr_forcings.pl.$JOB_ID";

# Check for directories; create if necessary & appropriate
foreach $dir ($LogDir) {
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
$cmd =
  "$TOOLS_DIR/clear_curr_forcings.pl $PROJECT $NewStartDate >& $LogFile.tmp";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
$cmd = "cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
$cmd = "rm -f $LogFile.tmp";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
