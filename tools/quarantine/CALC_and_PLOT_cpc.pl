#!/usr/bin/perl -w
# A. Wood Dec 2007
# run processing scripts and plot results
# paths for sere


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
$CPC                = $var_info_project{"CPC"};

if ($MODEL eq "vic") {
$Flist              = $var_info_project{"FLUX_FLIST"};}
else { $Flist       = $var_info_project{"WB_FLIST"};
}
#$Flist		    = "/raid8/forecast/sw_monitor/data/conus/forcing/grid/grid_info/conus_0.5.fluxfiles.maskorder.shrad";
$Latlonlist 	    = $var_info_project{"LONLAT_LIST"};
$Clim_Syr           = $var_info_project{"RO_CLIM_START_YR"}; # Climatology start year
$Clim_Eyr           = $var_info_project{"RO_CLIM_END_YR"}; # Climatology end year
$Ens_Syr           = $var_info_project{"ENS_START_YR"}; # Climatology start year
$Ens_Eyr           = $var_info_project{"ENS_END_YR"}; # Climatology end year
$LogDir = $var_info_project{"LOGS_MODEL_DIR"};
$LogDir =~ s/<LOGS_SUBDIR>/curr_spinup/;
$LogFile = "$LogDir/log.CPC_run_model.pl.$JOB_ID";
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

# calc climatology for current date, if not already done -------------
# could be run in parallel to forecasts
$cmd = "$TOOLS_DIR/calc.per_stats.CLIM.pl.bak $Cyr $Cmon $Cday $Clim_Syr $Clim_Eyr $Flist $RetroDir $NearRTDir $RTDir $CPC $MODEL >& $LogFile.tmp";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
$cmd = "cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
$cmd = "rm -f $LogFile.tmp";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

# calc stats and make full ensemble plots ----------------------------
$cmd = "$TOOLS_DIR/calc.ens_fcst_stats.20-33.pl.bak $Cyr $Cmon $Cday $Clim_Syr $Clim_Eyr $Ens_Syr $Ens_Eyr $Flist $NearRTDir $RTDir $CPC $MODEL $PROJECT >& $LogFile.tmp";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
$cmd = "cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
$cmd = "rm -f $LogFile.tmp";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

## calc stats ENSO ensemble -------------

$cmd = "$TOOLS_DIR/calc.ens_fcst_stats.SUBSET.20-33.pl $Cyr $Cmon $Cday $Clim_Syr $Clim_Eyr $Flist $NearRTDir $RTDir $CPC $MODEL $PROJECT >& $LogFile.tmp";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
$cmd = "cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
$cmd = "rm -f $LogFile.tmp";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";


