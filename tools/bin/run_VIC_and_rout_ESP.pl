#!/usr/bin/env perl
use warnings;

# A. Wood August 2007
# run a set of ESP forecasts, given existing state files & forcings, etc.
# this version:  for SW Monitor, on sere, in aww dirs

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
use Date::Calc qw(leap_year Days_in_Month Delta_Days Add_Delta_Days
  Add_Delta_YM);
use Statistics::Lite qw(mean);
use POSIX qw(strftime);

#-------------------------------------------------------------------------------
# Command-line arguments
#-------------------------------------------------------------------------------
# Get the Project name and Current date from nowcast_model.pl
$PROJECT  = shift;
$MODEL    = shift;
$RUN_ESP  = shift;  ### 1 or 0
$RUN_ROUT = shift;  ### 1 or 0
$Cyr      = shift;
$Cmon     = shift;
$Cday     = shift;
$METYR    = shift;  ### Start of ensemble
$FEYR     = shift;  ### End of ensemble

# Derived variables
$PROJECT_UC = $PROJECT;
$PROJECT    =~ tr/A-Z/a-z/;
$PROJECT_UC =~ tr/a-z/A-Z/;
$FLEN = 367;        ### Number of days to run the model for in future

# Unique identifier for this job
$JOB_ID = strftime "%y%m%d-%H%M%S", localtime;

# Read project configuration info
$ConfigProject        = "$CONFIG_DIR/config.project.$PROJECT";
$var_info_project_ref = &read_config($ConfigProject);
%var_info_project     = %{$var_info_project_ref};

# Read model configuration info
$ConfigModel        = "$CONFIG_DIR/config.model.$MODEL";
$var_info_model_ref = &read_config($ConfigModel);
%var_info_model     = %{$var_info_model_ref};

# Substitute model-specific information into project variables
foreach $key_proj (keys(%var_info_project)) {
  foreach $key_model (keys(%var_info_model)) {
    $var_info_project{$key_proj} =~
      s/<$key_model>/$var_info_model{$key_model}/g;
  }
}

#-------------------------------------------------------------------------------
$ResultsModelAscDir = $var_info_project{"RESULTS_MODEL_ASC_DIR"};
$var_info_project{"LOGS_MODEL_DIR"} =~ s/<LOGS_SUBDIR>/esp/g;
$LogDir = $var_info_project{"LOGS_MODEL_DIR"};
foreach $dir ($LogDir) {
  $status = &make_dir($dir);
  if ($status != 0) {
    die "Error: Failed to create $dir\n";
  }
}

# The final processed model results will be stored in the ascii dir
$ResultsModelFinalDir = $ResultsModelAscDir;

# Directories and files
$RetroDir = $ResultsModelFinalDir;
$RetroDir =~ s/<RESULTS_SUBDIR>/retro/g;
$NearRTDir = $ResultsModelFinalDir;
$NearRTDir =~ s/<RESULTS_SUBDIR>/spinup_nearRT/g;
$RTDir = $ResultsModelFinalDir;
if ($results_subdir_override) {
  $RTDir =~ s/<RESULTS_SUBDIR>/$results_subdir_override/g;
} else {
  $RTDir =~ s/<RESULTS_SUBDIR>/curr_spinup/g;
}
$ESP_START_TIME = localtime;
while ($METYR <= $FEYR) {  # forecast year loop
  $SDAY = $Cday;
  $FORC_START_DATE = sprintf "%04d-%02d-%02d", $METYR, $Cmon, $SDAY;

  # move forward for FLEN days
  ($Eyr, $Emon, $Eday) = Add_Delta_Days($METYR, $Cmon, $SDAY, $FLEN);
  $FORC_UPD_END_DATE = sprintf "%04d-%02d-%02d", $Eyr, $Emon, $Eday;

  ### The statefile is of the same day as the forecast initialization since
  ### currently VIC 4.0.5 is being used
  ($Stateyr, $Statemon, $Stateday) = Add_Delta_Days($Cyr, $Cmon, $Cday, 0);
  $datestr = sprintf("%04d%02d%02d", $Stateyr, $Statemon, $Stateday);

  #### Will have to change this for other models
  $LogFile = "$LogDir/log.$PROJECT.$MODEL.model_run.$datestr.$METYR.pl.$JOB_ID";

  ####### ESP PART ##########################################
  if ($RUN_ESP == 1) {
    print "Running ensembles intialized on $FORC_START_DATE\n ";

    #### ESP_STORAGE = 1 (when the routing part is inactivated ($RUN_ROUT ==
    #### 0). if $RUN_ROUT == 1 then it means ESP output does not needed to be
    #### zipped and stored becasue it's needed by the routing part
    #### (run_rout_model.pl))
    $ESP_STORAGE = 1 - $RUN_ROUT;
    $cmd =
      "$TOOLS_DIR/run_model_ESP.pl -m $MODEL -p $PROJECT -f retro " .
      "-r esp.$datestr.$FORC_START_DATE -s $FORC_START_DATE " .
      "-e $FORC_UPD_END_DATE -st curr_spinup -i $datestr -z $ESP_STORAGE " .
      ">& $LogFile.tmp";
    print "$cmd\n";
    (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
    $cmd = "cat $LogFile.tmp >> $LogFile";
    print "$cmd\n";
    (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
    $cmd = "rm -f $LogFile.tmp";
    print "$cmd\n";
    (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
  }

  #################### Routing  Part ###########################
  if ($RUN_ROUT == 1) {
    $ESP_STORAGE = 0;
    if ($RUN_ESP == 0) {

      #### ESP_STORAGE = 1 (when the ESP part has not been activated. This
      #### always assumes that ESP part has been run before when rout was not
      #### activated so it means that ESP output must be Zipped already.
      $ESP_STORAGE = 1;
    }

    #### Route start and end day should have the year same as the year(s) of
    #### actual forecast not the year of climatology Hence both dates are
    #### derived from the current date and the length of forecast period
    #### i.e. FLEN
    $ROUT_START_DATE = sprintf "%04d-%02d-%02d", $Cyr, $Cmon, $Cday;
    ($Rout_Eyr, $Rout_Emon, $Rout_Eday) =
      Add_Delta_Days($Cyr, $Cmon, $Cday, $FLEN);
    $ROUT_END_DATE = sprintf "%04d-%02d-%02d", $Rout_Eyr, $Rout_Emon,
      $Rout_Eday;

    # HACK to sidestep clutting the results directory. See issue 27.
    # Bart - Fri Sep 28 2012
    $cmd =
      "$TOOLS_DIR/run_rout_model.pl -m $MODEL -p $PROJECT " .
      "-f curr_spinup -r esp/esp.$datestr.$FORC_START_DATE " .
      "-s $ROUT_START_DATE -e $ROUT_END_DATE -i $datestr " .
      "-en $METYR -z $ESP_STORAGE >& $LogFile.tmp";
    print "$cmd\n";
    (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
    $cmd = "cat $LogFile.tmp >> $LogFile";
    print "$cmd\n";
    (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
    $cmd = "rm -f $LogFile.tmp";
    print "$cmd\n";
    (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
  }
  $METYR = $METYR + 1;
}
$ESP_END_TIME = localtime;
$subject =
  "\"$PROJECT $MODEL: " .
  "Forecast Runs for DATE $datestr started at $ESP_START_TIME and ended " .
  "at $ESP_END_TIME Ensembles $METYR -  $FEYR\"";
if (exists $var_info_project{"EMAIL_LIST"} and $var_info_project{"EMAIL_LIST"})
{
  ($addresses = $var_info_project{"EMAIL_LIST"}) =~ s/,/ /g;
  $cmd = "echo Completed | /bin/mail -s $subject $addresses";
  print "$cmd\n";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
}
