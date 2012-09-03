#!/usr/bin/perl 
# Shrad 2009
# This script is used to generate a statefile at any given date
#
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
$Eyr = shift;
$Emon = shift;
$Eday = shift;

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

$FORC_START_DATE = sprintf "%04d-%02d-%02d",$Cyr,$Cmon,$Cday;
$FORC_UPD_END_DATE = sprintf "%04d-%02d-%02d", $Eyr, $Emon, $Eday;
$datestr = sprintf("%04d%02d%02d",$Cyr,$Cmon,$Cday);
      #### Will have to change this for other models


$cmd = "$TOOLS_DIR/run_model_ESP.pl -m $MODEL -p $PROJECT -f retro -r esp -s $FORC_START_DATE -e $FORC_UPD_END_DATE -st spinup.retro -i 20041231 >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
print "$cmd\n";

(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

