#!/usr/bin/perl 
# A. Wood August 2007
# run a set of ESP forecasts, given existing state files & forcings, etc.
# this version of this script is used when drought forecast is desired to run in retro mode
# this version:  for SW Monitor, on sere, in aww dirs

use Date::Calc qw(leap_year Days_in_Month Delta_Days Add_Delta_Days Add_Delta_YM);
use Statistics::Lite ("mean");

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

#----------------------------------------------------------------------------------------------
# Include external modules
#----------------------------------------------------------------------------------------------
# Subroutine for reading config files
require "$TOOLS_DIR/simma_util.pl";

#----------------------------------------------------------------------------------------------

# Get the Project name and Current date from nowcast_model.pl
$PROJECT = shift;
$MODEL = shift;
$Cyr = shift;
$Cmon = shift;
$Cday = shift;

# Derived variables
$PROJECT_UC = $PROJECT;
$PROJECT =~ tr/A-Z/a-z/;
$PROJECT_UC =~ tr/a-z/A-Z/;
$DATE = sprintf("%04d%02d%02d",$Cyr,$Cmon,$Cday);
$FLEN = 180; ### Number of days to run the model for in future

# Unique identifier for this job
$JOB_ID = `date +%y%m%d-%H%M%S`;
if ($JOB_ID =~ /(\S+)/) {
  $JOB_ID = $1;
}


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


#------------------------------------------------------------------------------------------------------
$ResultsModelAscDir = $var_info_project{"RESULTS_MODEL_ASC_DIR"};
$ESP                = $var_info_project{"ESP"};
$Flist              = $var_info_project{"FLUX_FLIST"};
$Clim_Syr           = $var_info_project{"RO_CLIM_START_YR"}; # Climatology start year
$Clim_Eyr           = $var_info_project{"RO_CLIM_END_YR"}; # Climatology end year
$Ens_Syr           = $var_info_project{"ENS_START_YR"}; # Climatology start year
$Ens_Eyr           = $var_info_project{"ENS_END_YR"}; # Climatology end year
$LogDir = $var_info_project{"LOGS_MODEL_DIR"};
$LogDir =~ s/<LOGS_SUBDIR>/curr_spinup/;
$LogFile = "$LogDir/log.ESP_run_model.pl.$JOB_ID";

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
}
else {
  $RTDir =~ s/<RESULTS_SUBDIR>/curr_spinup/g;
}



$STORDIR = "$ESP/saved/$MODEL/$DATE";
 
`mkdir -p $STORDIR`;
# only run if state file is copied...

$METYR = $Ens_Syr; ### Start of ensemble
$FEYR = $Ens_Eyr;  ### End of ensemble

while ($METYR <= $FEYR) # forecast year loop

{   $FORC_START_DATE = sprintf "%04d-%02d-%02d",$METYR,$Cmon,$Cday;
    ($Eyr, $Emon, $Eday) = Add_Delta_Days($METYR, $Cmon, $Cday, $FLEN); # move forward for FLEN days
    $FORC_UPD_END_DATE = sprintf "%04d-%02d-%02d", $Eyr, $Emon, $Eday;
    $datestr = sprintf("%04d%02d%02d",$Cyr,$Cmon,$Cday);
      #### Will have to change this for other models

print "Running ensembles intialized on $FORC_START_DATE\n ";


$cmd = "$TOOLS_DIR/run_model_ESP.pl -m $MODEL -p $PROJECT -f retro -r esp -s $FORC_START_DATE -e $FORC_UPD_END_DATE -st spinup_nearRT -i $datestr >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
print "$cmd\n";

(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

$METYR = $METYR+1;
}
