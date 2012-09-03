#!/usr/bin/perl -w
# Shrad Shukla May 2011
# processes ESP/CPC forecast result for the specific basin
# this script will calculate the statics, make forecast streamflow plots for stations in the basin,
# and write the BAS.htm and BAS_diff.htm under ./w_reg/summ_stats.
# use up1bas.scr to do the copy
use lib "/usr/lib/perl5/site_perl/5.6.1";
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
$FCST = shift;
$SENS = shift;
$EENS = shift;

$COMMON = "/raid8/forecast/common";
$BIN_DIR = "/raid8/forecast/bin";
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
$ROUT                = $var_info_project{"rout"};

if ($MODEL eq "vic") {
$Flist              = $var_info_project{"FLUX_FLIST"};}
else { $Flist       = $var_info_project{"WB_FLIST"};
}
$Latlonlist 	    = $var_info_project{"LONLAT_LIST"};
$Clim_Syr           = $var_info_project{"RO_CLIM_START_YR"}; # Climatology start year
$Clim_Eyr           = $var_info_project{"RO_CLIM_END_YR"}; # Climatology end year
$Ens_Syr           = $var_info_project{"ENS_START_YR"}; # Climatology start year
$Ens_Eyr           = $var_info_project{"ENS_END_YR"}; # Climatology end year	
$ROUT_SAVED         = $var_info_project{"ROUT_SAVED_DIR"}; ## Directory to save ensemble of rout flow
$ESP                = $var_info_project{"ESP"};  #### Directory where ESP outputs are saved ## Shrad added this

$LogDir = $var_info_project{"LOGS_MODEL_DIR"};
$LogDir =~ s/<LOGS_SUBDIR>/route/;
$LogFile = "$LogDir/log.rout_process.$DATE.pl.$JOB_ID";
# The final processed model results will be stored in the ascii dir
$ResultsModelFinalDir = $ResultsModelAscDir;
$ROUT_PARAM_DIR     = $var_info_project{"PARAMS_ROUT_DIR"}; #### Directory where Rout parameters reside        
$INPUTDIR = "$ROUT_PARAM_DIR/input"; #### Directory where all the input for the routed flow processing are located
$STATION_INFO_FILE = "$INPUTDIR/$PROJECT.stn";
$OBS_CLIM_DIR = "$INPUTDIR/obs_clim";
$OBS_SPATIAL_CLIM = "$INPUTDIR/obs_clim_spatial";
$ROUT_ENS_DIR = "$ROUT_SAVED/$DATE/sflow";
$ROUT_XYZZ_DIR      = "$ROUT_SAVED/$DATE/stats"; ## Directory to save route statistics
$ROUT_PLOT_DIR      = "$ROUT_SAVED/$DATE/plots"; ## Directory to plot route statistics
$ROUT_WEB_DIR       = "$ROUT_SAVED/$DATE/web";
### 1: Processing rout forecast
$ESP_XYZZDIR        = "$ESP/$MODEL/$DATE/spatial"; #### ESP FLUXOUTPUT storage directory
$ESP_PLOT_DIR       = "$ESP/$MODEL/$DATE/plots"; #### For ESP Spatial plots
$XYZZDir            = $var_info_project{"XYZZ_DIR"};
$OBS_XYZZDIR        = "$XYZZDir";
$XYZZFILE           = "$PROJECT_UC.$MODEL.f-c_mean.a-m_anom.qnt.xyzz"; ### Prefix of SM and SWE percentile files use for plotting.
# Model parameters
$Basin_control_file_Template = "$INPUTDIR/input_TEMPLATE.ctr";
$ESP_control_file_Template = "$INPUTDIR/input_TEMPLATE_ESPsflow";


#### Creating a basin control file for current forecasts
open (PARAMS_TEMPLATE, $Basin_control_file_Template) or die "$0: ERROR: cannot open parameter template file $Basin_control_file_Template\n";
@ParamsInfo = <PARAMS_TEMPLATE>;
close (PARAMS_TEMPLATE);
# Create Basin control file for forecasted streamflow processing
$BASIN_CONTROL_FILE = "$INPUTDIR/$PROJECT.ctr";
  @MyParamsInfo = @ParamsInfo;
  foreach (@MyParamsInfo) {
    s/<BASIN>/$PROJECT/g;
    s/<OBS_CLIM>/$OBS_CLIM_DIR/g;
    s/<STATION_INFO_FILE>/$STATION_INFO_FILE/g;
    s/<XYZZ_DIR>/$ROUT_XYZZ_DIR/g;
    s/<ROUTE_SAVED>/$ROUT_ENS_DIR/g;
    if ($UNCOMP_OUTPUT) {
      s/^(.*COMP_OUTPUT=).*/$1.FALSE./;
    }
  }
  open (BAS_CONTROLFILE, ">$BASIN_CONTROL_FILE") or die "$0: ERROR: cannot open current controlfile $BASIN_CONTROL_FILE\n";
  foreach (@MyParamsInfo) {
    print BAS_CONTROLFILE;
  }


#### Creating a basin control file for ESP forecasts and ENSO subsets
open (PARAMS_TEMPLATE, $ESP_control_file_Template) or die "$0: ERROR: cannot open parameter template file $ESP_control_file_Template\n";
@ParamsInfo = <PARAMS_TEMPLATE>;
close (PARAMS_TEMPLATE);
$ESP_CONTROL_FILE = "$INPUTDIR/ESPsflow.ctr";
  @MyParamsInfo = @ParamsInfo;
  foreach (@MyParamsInfo) {
    s/<MET_YR>/$SENS/g;
    s/<OBS_CLIM>/$OBS_CLIM_DIR/g;
    if ($UNCOMP_OUTPUT) {
      s/^(.*COMP_OUTPUT=).*/$1.FALSE./;
    }
  }
  open (ESP_CONTROLFILE, ">$ESP_CONTROL_FILE") or die "$0: ERROR: cannot open current controlfile $ESP_CONTROL_FILE\n";
  foreach (@MyParamsInfo) {
    print ESP_CONTROLFILE;
}



### Creating Directories
foreach $dir ($ROUT_XYZZ_DIR, $ESP_XYZZ_DIR, $ROUT_PLOT_DIR, $ESP_PLOT_DIR, $LogDir, $ROUT_WEB_DIR) {
  $status = &make_dir($dir);
}

$cmd = "$TOOLS_DIR/FCST_Process_Scripts/fcst_sflow $FCST $ESP_CONTROL_FILE $BASIN_CONTROL_FILE $Cyr $Cmon $Cday >& $LogFile.tmp";
print "$cmd\n";
##(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
(system($cmd)==0);
$cmd = "cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";


## Usage <BAS> <INPUT> <SYR> <SMO> <SDY> <DATAPATH> <OBS_CLIM> <PLOTDIR>
$cmd = "$TOOLS_DIR/FCST_Process_Scripts/PLOT_SCRIPTS/plot.boxwh.rout.FCST.scr $PROJECT $INPUTDIR $Cyr $Cmon $Cday $ROUT_XYZZ_DIR $OBS_CLIM_DIR $ROUT_PLOT_DIR >& $LogFile.tmp";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
$cmd = "cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

### Usage <FCST> <BAS> <DATE> <LONLAT> <XYZZDIR> <S_AVGPER> <E_AVGPER>
$cmd = "$TOOLS_DIR/FCST_Process_Scripts/proc.xtr_vars.fcst.scr $FCST $PROJECT $DATE $Latlonlist $ESP_XYZZDIR $SENS $EENS >& $LogFile.tmp"; 
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
$cmd = "cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

#### Change log files 

## Usage <FCST> <MON> <DAY> <BAS> <LONLAT> <BIN> <OBSCLIM> <XYZZDIR>
$cmd = "$TOOLS_DIR/FCST_Process_Scripts/calc_fcst_stats.6var.fcst.scr $FCST $Cmon $Cday $PROJECT $Latlonlist $BIN_DIR $OBS_SPATIAL_CLIM $ESP_XYZZDIR >& $LogFile.tmp"; 
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
$cmd = "cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

## Usage <BAS> <FCST> <DATE> <MON> <XYZZDIR> <PLOTDIR> <PLOT SCRIPT DIR> <COMMON>

$cmd = "$TOOLS_DIR/FCST_Process_Scripts/PLOT_SCRIPTS/plot_many.scr $PROJECT $FCST $Cday $Cmon $Cyr $ESP_XYZZDIR $ESP_PLOT_DIR $TOOLS_DIR/FCST_Process_Scripts/PLOT_SCRIPTS $COMMON >& $LogFile.tmp";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
$cmd = "cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

## Usage <CURRFCST> <LASTFCST> <BAS> <COMMON> <XYZZDIR> <XYZZFILE> <PLOTDIR> <PLOT_SCRIPT>
($L_fcst_yr, $L_fcst_mon, $L_fcst_day) = Add_Delta_Days($Cyr, $Cmon, $Cday, -7); ### Assuming that last forecast was made a week before the current one
$LAST_FCST_DATE = sprintf("%04d%02d%02d",$L_fcst_yr, $L_fcst_mon, $L_fcst_day);

$cmd = "$TOOLS_DIR/FCST_Process_Scripts/PLOT_SCRIPTS/plots_spatial_initcond.WREG.scr $DATE $LAST_FCST_DATE $PROJECT $COMMON $OBS_XYZZDIR $XYZZFILE $ESP_PLOT_DIR $TOOLS_DIR/FCST_Process_Scripts/PLOT_SCRIPTS>& $LogFile.tmp";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
$cmd = "cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";


##$HTML = "$ROUT_WEB_DIR/$PROJECT";
##$STAT = ./$BAS/$DATE.$FCST/$BAS.$FCST"stats"

###update_stats.pl $HTML.htm $STAT $FCST
###update_stats.pl $HTML"_diff.htm" $STAT"_DIFF" $FCST

