#!/usr/bin/env perl 
use warnings;

# SGE directives
#$ -cwd
#$ -j y
#$ -S /usr/bin/perl
#
# run_rout_model.pl: Script to rout FLUX OUTPUTS of each ensembles
#
# usage: see usage() function below
#
# Author: Shrad Shukla
# $Id: $
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# Determine tools and config directories
#-------------------------------------------------------------------------------
$TOOLS_DIR  = "<SYSTEM_INSTALLDIR>/bin";
$CONFIG_DIR = "<SYSTEM_INSTALLDIR>/config";

#-------------------------------------------------------------------------------
# Include external modules
#-------------------------------------------------------------------------------
# Subroutine for reading config files
require "$TOOLS_DIR/simma_util.pl";

# This allows us to use sophisticated command-line argument parsing
use Getopt::Long;

# Date arithmetic
use Date::Calc qw(Days_in_Month Delta_Days Add_Delta_Days Add_Delta_YM);

# Access to environment variables
use Env;
use POSIX qw(strftime);

# Model-specific subroutines
require "$TOOLS_DIR/rout_specific.pl";

#-------------------------------------------------------------------------------
# Parse the command line
#-------------------------------------------------------------------------------
# Default values
$forcing_subdir = "";
$results_subdir = "";
$UNCOMP_OUTPUT  = 0;
$extract_vars   = "";
$local_storage  = "1";
$rout_storage   = 1;

# Hash used in GetOptions function
# format: option => \$variable_to_set
%options_hash = (
                 h     => \$help,
                 m     => \$MODEL_NAME,
                 p     => \$PROJECT,
                 f     => \$forcing_subdir,
                 s     => \$start_date,
                 e     => \$end_date,
                 r     => \$results_subdir,
                 i     => \$DATE,
                 en    => \$ENS_YR,
                 z     => \$esp_storage,
                 uncmp => \$UNCOMP_OUTPUT,
                 l     => \$local_storage,
                 x     => \$extract_vars,
                 mspc  => \$model_specific,
                );

# This parses the command-line arguments and sets values for the variables in
# %option_hash
$status = &GetOptions(
                      \%options_hash, "h",    "m=s",  "p=s",
                      "f=s",          "s=s",  "e=s",  "r=s",
                      "i=s",          "st=s", "en=i", "z=i",
                      "uncmp",        "l",    "x=s",  "mspc=s"
                     );

#-------------------------------------------------------------------------------
# Validate the command-line arguments
#-------------------------------------------------------------------------------
# Help option
if ($help) {
  usage("full");
  exit(0);
}

# Validate required arguments
if (!$MODEL_NAME) {
  print STDERR "$0: ERROR: no model specified\n";
  usage("short");
  exit(-1);
}
if (!$PROJECT) {
  print STDERR "$0: ERROR: no project specified\n";
  usage("short");
  exit(-1);
}
if (!$start_date) {
  print STDERR "$0: ERROR: no simulation start date specified\n";
  usage("short");
  exit(-1);
}
if (!$end_date) {
  print STDERR "$0: ERROR: no simulation end date specified\n";
  usage("short");
  exit(-1);
}

# Parse & validate start/end dates
if ($start_date =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/) {
  ($start_year, $start_month, $start_day) = ($1, $2, $3);
} else {
  print STDERR "$0: ERROR: start date must have format YYYY-MM-DD.\n";
  usage("full");
  exit(-1);
}
if ($end_date =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/) {
  ($end_year, $end_month, $end_day) = ($1, $2, $3);
} else {
  print STDERR "$0: ERROR: end date must have format YYYY-MM-DD.\n";
  usage("full");
  exit(-1);
}
if ($start_year > $end_year) {
  print STDERR "$0: ERROR: start_date is later than end_date: " .
    "start_year > end_year.\n";
  usage("short");
  exit(-1);
} elsif ($start_year == $end_year) {
  if ($start_month > $end_month) {
    print STDERR "$0: ERROR: start_date is later than end_date: " .
      "start_year == end_year and start_month > end_month.\n";
    usage("short");
    exit(-1);
  } elsif ($start_month == $end_month) {
    if ($start_day > $end_day) {
      print STDERR "$0: ERROR: start_date is later than end_date: " .
        "start_year == end_year, start_month == end_month and " .
        "start_day > end_day.\n";
      usage("short");
      exit(-1);
    }
  }
}

# Default values of $spinup_subdir and results_subdir
if ($forcing_subdir) {
  $spinup_subdir = $forcing_subdir;
}
if ($results_subdir) {
  if (!$state_subdir) {
    $state_subdir = $results_subdir;
  }
}
if ($DATE =~ /(\d\d\d\d)(\d\d)(\d\d)/) {
  ($STATE_YR, $STATE_MON, $STATE_DAY) = Add_Delta_Days($1, $2, $3, 0);
  $FCST_DATE = sprintf "%04d%02d%02d", $STATE_YR, $STATE_MON, $STATE_DAY;

  #  Date of forecast initialization date.  Same as the day of state file It
  #  should be changed to a day after the state day for the VIC version 4.0.6
  #  and after
} else {
  print STDERR "$0: ERROR: State date must have format YYYYMMDD.\n";
  usage("full");
  exit(-1);
}

#-------------------------------------------------------------------------------
# Set up constants
#-------------------------------------------------------------------------------
# Unique identifier for this job
$JOB_ID = strftime "%y%m%d-%H%M%S", localtime;

# Set up netcdf access
$ENV{INC_NETCDF} = "<SYSTEM_NETCDF_INC>";
$ENV{LIB_NETCDF} = "<SYSTEM_NETCDF_LIB>";

# Miscellaneous
@month_days = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);

# Read project configuration info
$ConfigProject        = "$CONFIG_DIR/config.project.$PROJECT";
$var_info_project_ref = &read_config($ConfigProject);
%var_info_project     = %{$var_info_project_ref};

# Read model configuration info
$ConfigModel        = "$CONFIG_DIR/config.model.$MODEL_NAME";
$var_info_model_ref = &read_config($ConfigModel);
%var_info_model     = %{$var_info_model_ref};

# Read routing model info
$ConfigRoute        = "$CONFIG_DIR/config.model.$var_info_project{ROUT_MODEL}";
$var_info_route_ref = &read_config($ConfigRoute);
%var_info_route     = %{$var_info_route_ref};

# Substitute model-specific information into project variables
foreach $key_proj (keys(%var_info_project)) {
  foreach $key_model (keys(%var_info_model)) {
    $var_info_project{$key_proj} =~
      s/<$key_model>/$var_info_model{$key_model}/g;
  }
}

# Substitute user-specified information into project and model variables
$var_info_project{"FORCING_MODEL_DIR"} =~ s/<FORCING_SUBDIR>/$forcing_subdir/g;
$var_info_project{"RESULTS_MODEL_RAW_DIR"} =~
  s/<RESULTS_SUBDIR>/$results_subdir/g;
$var_info_project{"ROUT_MODEL_DIR"} =~ s/<RESULTS_SUBDIR>/$results_subdir/g;
$var_info_project{"RESULTS_MODEL_ASC_DIR"} =~
  s/<RESULTS_SUBDIR>/$results_subdir/g;
$var_info_project{"SPINUP_MODEL_ASC_DIR"} =~
  s/<FORCING_SUBDIR>/$forcing_subdir/g;
$var_info_project{"CONTROL_MODEL_DIR"} =~ s/<CONTROL_SUBDIR>/rout/g
  ;  #### Control file and Log file for routing model runs go in to subdirectory
     #### <rout>.
$var_info_project{"LOGS_MODEL_DIR"} =~ s/<LOGS_SUBDIR>/rout/g;

if ($var_info_model{"POSTPROC"}) {
  $var_info_model{"POSTPROC"} =~ s/<TOOLS_DIR>/$TOOLS_DIR/g;
  $var_info_model{"POSTPROC"} =~ s/<START_DATE>/$start_date/g;
  $var_info_model{"POSTPROC"} =~ s/<END_DATE>/$end_date/g;

  # The final processed model results will be stored in the ascii dir
  $var_info_model{"POSTPROC"} =~
    s/<RESULTS_DIR_FINAL>/$var_info_project{"RESULTS_MODEL_ASC_DIR"}/g;
}

# Save relevant project info in variables
$ParamsModelDir = $var_info_project{
  "PARAMS_ROUT_DIR"};  #### Directory where Rout parameters reside
$ForcingModelDir    = $var_info_project{"FORCING_MODEL_DIR"};
$ResultsModelRawDir = $var_info_project{"RESULTS_MODEL_RAW_DIR"};
$ResultsModelAscDir = $var_info_project{"RESULTS_MODEL_ASC_DIR"};
$Routdir            = $var_info_project{"ROUT_MODEL_DIR"};
$SpinupModelAscDir  = $var_info_project{ "SPINUP_MODEL_ASC_DIR"
  };  ### Spinup Directory which has flux output since Spinup_start_date
$ControlModelDir = $var_info_project{"CONTROL_MODEL_DIR"};
$LogsModelDir    = $var_info_project{"LOGS_MODEL_DIR"};

# The final processed model results will be stored in the ascii dir
$ResultsModelFinalDir = $ResultsModelAscDir;
$ForcTypeAscVic       = $var_info_project{"FORCING_TYPE_ASC_VIC"};
$ForcTypeNC           = $var_info_project{"FORCING_TYPE_NC"};
$ForcingAscVicPrefix  = $var_info_project{"FORCING_ASC_VIC_PREFIX"};
$ForcingNCPrefix      = $var_info_project{"FORCING_NC_PREFIX"};
$ESP                  = $var_info_project{
  "ESP"};  #### Directory where ESP outputs are saved ## Shrad added this
$ROUT = $var_info_project{"ROUT"};  #### Directory where ROUT outputs are saved
$STORDIR =
  "$ESP/$MODEL_NAME/$FCST_DATE/dly_flux";  #### ESP FLUXOUTPUT storage directory
$STOR_ROUT_DIR =
  "$ROUT/$MODEL_NAME/$FCST_DATE/sflow";    #### ESP Rout storage directory

# Save relevant model info in variables
$ROUTE_SRC_DIR  = $var_info_route{"MODEL_SRC_DIR"};
$ROUTE_EXE_DIR  = $var_info_route{"MODEL_EXE_DIR"};
$ROUTE_EXE_NAME = $var_info_route{"MODEL_EXE_NAME"};
if ($forcing_subdir =~ /retro/i) {
  $StartDateFile = $var_info_project{"FORCING_RETRO_START_DATE_FILE"};
} elsif ($forcing_subdir =~ /spinup_nearRT/i) {
  $StartDateFile = $var_info_project{"FORCING_NEAR_RT_START_DATE_FILE"};
} elsif ($forcing_subdir =~ /curr_spinup/i) {
  $StartDateFile = $var_info_project{"FORCING_CURRSPIN_START_DATE_FILE"};
}

# Estimate Spinup start and end Date here: Spinup start date is currently set to
# be the day 1 of curr_spinup, however for retro or spinup_nearRT, the date will
# be the first day of 2 months before the routing starts
if ($DATE =~ /(\d\d\d\d)(\d\d)(\d\d)/) {
  ($Spinup_Eyr, $Spinup_Emon, $Spinup_Eday) = Add_Delta_Days($1, $2, $3, -1);

  # The spinup is added until a day before the forecast initialization, since
  # for VIC 4.0.5 both day of state file and forecast inialization date is the
  # same. For other Version VIC 4.0.6 or VIC 4.1.X this end day of spinup will
  # be the same day as the day of state file hence
  # ($Spinup_Eyr,$Spinup_Emon,$Spinup_Eday) = Add_Delta_Days($1,$2,$3, 0);
}
($Spinup_Syr, $Spinup_Smon, $Spinup_Sday) =
  Add_Delta_YM($Spinup_Eyr, $Spinup_Emon, $Spinup_Eday, 0, -2);
$Spinup_Sday = "01";

### Only if forcing_subdir is curr_spinup
if ($forcing_subdir =~ /curr_spinup/i) {

  # Date of Spinup Start and END
  open(FILE, $StartDateFile) or
    die "$0: ERROR: cannot open file $StartDateFile\n";
  foreach (<FILE>) {
    if (/^(\d+)\s+(\d+)\s+(\d+)\s+/) {
      ($Spinup_Syr, $Spinup_Smon, $Spinup_Sday) = ($1, $2, $3);
    }
  }
  close(FILE);
}  ## if

#---------------------------------------------------
# HACK!
if ($local_storage) {
  $uname = `uname -a`;
  if ($uname =~ /compute-(...)/) {
    $nodename = $1;
  }

  #if (!$nodename) {
  # die "$0: ERROR: node name not found\n";
  #}
  # Determine local dir
  if ($nodename =~ /c-(0|1|2|3|4)/) {
    $local_root = "<SYSTEM_LOCAL_ROOT2>";
  } else {
    $local_root = "<SYSTEM_LOCAL_ROOT1>";
  }
  $PROJECT_DIR       = $var_info_project{"PROJECT_DIR"};
  $LOCAL_PROJECT_DIR = $var_info_project{"LOCAL_PROJECT_DIR"};
  $replace           = "<SYSTEM_ROOT>";
  $LOCAL_PROJECT_DIR =~ s/$replace/$local_root/;
  print "$0: LOCAL_PROJECT_DIR: $LOCAL_PROJECT_DIR\n";
}

#---------------------------------------------------
# Date of beginning of data forcings
# Model parameters
$ParamsTemplate = "$ParamsModelDir/input.rout.template";
open(PARAMS_TEMPLATE, $ParamsTemplate) or
  die "$0: ERROR: cannot open parameter template file $ParamsTemplate\n";
print "Rout input file is $ParamsTemplate\n";
@ParamsInfo = <PARAMS_TEMPLATE>;
close(PARAMS_TEMPLATE);

# Check for directories; create if necessary & appropriate
foreach $dir ($ParamsModelDir) {
  if (!-d $dir) {
    die "$0: ERROR: directory $dir not found\n";
  }
}
foreach $dir (
              $ResultsModelRawDir,   $ResultsModelAscDir,
              $ResultsModelFinalDir, $StateModelDir,
              $ControlModelDir,      $LogsModelDir
  ) {
  $status = &make_dir($dir);
}

# Output Directories
$results_dir     = $ResultsModelRawDir;
$results_dir_asc = $ResultsModelAscDir;
$state_dir       = $StateModelDir;
$control_dir     = $ControlModelDir;
$logs_dir        = $LogsModelDir;
print "LOG Dir is $logs_dir and control dir is $control_dir\n";
$LOGFILE     = "$logs_dir/log.rout.$PROJECT.$MODEL_NAME.$DATE.$ENS_YR";
$controlfile = "$control_dir/inp.rout.$MODEL_NAME.$DATE.$ENS_YR";

# Use local directories if specified
if ($local_storage) {
  $LOCAL_RESULTS_DIR = $ResultsModelRawDir;
  $LOCAL_RESULTS_DIR =~ s/$PROJECT_DIR/$LOCAL_PROJECT_DIR/g;
  $LOCAL_RESULTS_DIR_ASC = $ResultsModelAscDir;
  $LOCAL_RESULTS_DIR_ASC =~ s/$PROJECT_DIR/$LOCAL_PROJECT_DIR/g;
  $LOCAL_ROUT_DIR = $Routdir;
  $LOCAL_ROUT_DIR =~ s/$PROJECT_DIR/$LOCAL_PROJECT_DIR/g;

  #$LOCAL_STATE_DIR = $StateModelDir;
  #$LOCAL_STATE_DIR =~ s/$PROJECT_DIR/$LOCAL_PROJECT_DIR/g;
  $LOCAL_CONTROL_DIR = $ControlModelDir;
  $LOCAL_CONTROL_DIR =~ s/$PROJECT_DIR/$LOCAL_PROJECT_DIR/g;
  $results_dir     = $LOCAL_RESULTS_DIR;
  $results_dir_asc = $LOCAL_RESULTS_DIR_ASC;
  $Routdir         = $LOCAL_ROUT_DIR;

  # Clean out the directories if they exist
  foreach $dir ($LOCAL_ROUT_DIR, $LOCAL_CONTROL_DIR) {
    if (-e $dir) {
      $cmd = "rm -rf $dir";
      (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
    }
  }

  # Create the directories
  foreach $dir ($LOCAL_ROUT_DIR, $LOCAL_CONTROL_DIR, $logs_dir) {
    $status = &make_dir($dir);
  }
}
$LOGFILE = "$LogsModelDir/log.rout.$PROJECT.$MODEL_NAME.$DATE.$ENS_YR";

###### if ESP_STORAGE = 1
if ($esp_storage) {
  if (!-e $results_dir_asc) {
    $status = &make_dir($results_dir_asc);
  }
  $cmd = "tar -xzf $STORDIR/fluxes.$ENS_YR.tar.gz -C $results_dir_asc";
  (($status = &shell_cmd($cmd, $LOGFILE)) == 0) or
    die "$0: ERROR: $cmd failed: $status\n";
  $temp_results_dir = "$results_dir_asc" . '/ESP.' . "$ENS_YR";
  $results_dir_asc  = "$temp_results_dir";
}

####### Running routing model ####################
$func_name = "wrap_run_" . rout;
&{$func_name}($model_specific);

#-------------------------------------------------------------------------------
# ZIP and move FLuxoutput directory into ESP storage directory when specified if
# $esp_storage = 1
#-------------------------------------------------------------------------------
if (!-e $STORDIR) {
  $status = &make_dir($STORDIR);
}
if ($rout_storage) {
  $cmd =
    "mv $results_dir_asc ./ESP.$PROJECT.$ENS_YR >& $LOGFILE.tmp; " .
    "cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
  (($status = &shell_cmd($cmd, $LOGFILE)) == 0) or
    die "$0: ERROR: $cmd failed: $status\n";
  $cmd =
    "tar -czf $STORDIR/fluxes.$ENS_YR.tar.gz ./ESP.$PROJECT.$ENS_YR >& " .
    "$LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
  (($status = &shell_cmd($cmd, $LOGFILE)) == 0) or
    die "$0: ERROR: $cmd failed: $status\n";
  $cmd =
    "rm -rf ./ESP.$PROJECT.$ENS_YR >& $LOGFILE.tmp; cat $LOGFILE.tmp >> " .
    "$LOGFILE; rm $LOGFILE.tmp";
  (($status = &shell_cmd($cmd, $LOGFILE)) == 0) or
    die "$0: ERROR: $cmd failed: $status\n";
  $cmd =
    "rm -rf $results_dir_asc >& $LOGFILE.tmp; cat $LOGFILE.tmp >> " .
    "$LOGFILE; rm $LOGFILE.tmp";
  (($status = &shell_cmd($cmd, $LOGFILE)) == 0) or
    die "$0: ERROR: $cmd failed: $status\n";
}

#-------------------------------------------------------------------------------
# ZIP and move routing output directory into ESP rout storage directory when
# specified if $esp_storage = 1
#-------------------------------------------------------------------------------
if (!-e $STOR_ROUT_DIR) {
  $status = &make_dir($STOR_ROUT_DIR);
}
if ($rout_storage) {
  $cmd =
    "mv $Routdir ./SFLOW.$PROJECT.$ENS_YR >& $LOGFILE.tmp; " .
    "cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
  (($status = &shell_cmd($cmd, $LOGFILE)) == 0) or
    die "$0: ERROR: $cmd failed: $status\n";
  $cmd =
    "tar -czf $STOR_ROUT_DIR/sflow.$ENS_YR.tar.gz " .
    "./SFLOW.$PROJECT.$ENS_YR >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; " .
    "rm $LOGFILE.tmp";
  (($status = &shell_cmd($cmd, $LOGFILE)) == 0) or
    die "$0: ERROR: $cmd failed: $status\n";
  $cmd =
    "rm -rf ./SFLOW.$PROJECT.$ENS_YR >& $LOGFILE.tmp; " .
    "cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
  (($status = &shell_cmd($cmd, $LOGFILE)) == 0) or
    die "$0: ERROR: $cmd failed: $status\n";
  $cmd =
    "rm -rf $Routdir >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; " .
    "rm $LOGFILE.tmp";
  (($status = &shell_cmd($cmd, $LOGFILE)) == 0) or
    die "$0: ERROR: $cmd failed: $status\n";
}
exit(0);

#-------------------------------------------------------------------------------
# Usage
#-------------------------------------------------------------------------------
sub usage() {
  print "\n";
  print "$0: Script to run a model within the SIMMA framework\n";
  print "\n";
  print "usage:\n";
  print "\t$0 [-h] -m <model> -p <project> [-f <forcing_subdir>]\n";
  print "\t\t-s <start_date> -e <end_date> [-r <results_subdir>]\n";
  print "\t\t[-i <init_file>] [-st <state_subdir>] [-uncmp] [-x <varnames>]\n";
  print "\t\t[-mspc <model-specific parameters> ] [-l]\n";
  print "\n";

  if ($_[0] eq "full") {
    print "Given ALMA-compliant forcings in NetCDF format, runs a model\n";
    print "over the specified simulation period and produces ALMA-compliant\n";
    print "output files in NetCDF format.\n";
    print "\n";
    print "The forcing files are each assumed to contain 1 month of data.\n";
    print "The files are assumed to have names of the form:\n";
    print "  prefix.YYYYMM.nc\n";
    print "where\n";
    print "  prefix = some alphanumeric string\n";
    print "  YYYY   = 4-digit year\n";
    print "  MM     = 2-digit month\n";
    print "\n";
    print "The model output files will each contain 1 month of data\n";
    print "aggregated to daily intervals, and will have names following\n";
    print "the same convention as the forcing files.  The prefixes on\n";
    print "these files are defined in the model configuration file.\n";
    print "\n";
    print "Arguments:\n";
    print "\n";
    print "  -h\n";
    print "    prints this usage message\n";
    print "\n";
    print "  -m <model>\n";
    print "    <model>  = Name of model to run.\n";
    print "\n";
    print "  -p <project>\n";
    print "    <project>  = Name of project or basin to simulate.\n";
    print "    This script will look for project-specific parameters,\n";
    print "    including \$PROJECT_DIR, in the file \n";
    print "    <SYSTEM_INSTALLDIR>/config/config.<project>.\n";
    print "\n";
    print "  -f <forcing_subdir>\n";
    print "    <forcing_subdir>  = (optional) subdirectory, under\n";
    print "    \$PROJECT_DIR/forcing, where forcing file tree starts.\n";
    print "    Default: forcing file tree is directly under \n";
    print "    \$PROJECT_DIR/forcing.\n";
    print "\n";
    print "  -s <start_date>\n";
    print "    <start_date>  = Start date of the simulation. \n";
    print "    Format: YYYY-MM-DD.\n";
    print "\n";
    print "  -e <end_date>\n";
    print "    <end_date>  = End date of the simulation.\n";
    print "    Format: YYYY-MM-DD.\n";
    print "\n";
    print "  -r <results_subdir>\n";
    print "    (optional) Specify the subdirectory, under \n";
    print "    \$PROJECT_DIR/results, where results file tree starts.\n";
    print "    <results_subdir>  = subdirectory name.\n";
    print "    Default: If forcing_subdir has been specified and \n";
    print "    results_subdir has not, then results_subdir = forcing_subdir\n";
    print "    (i.e. results file tree starts under \n";
    print "    \$PROJECT_DIR/results/\$forcing_subdir).\n";
    print "\n";
    print "  -i <init_file>\n";
    print "    (optional) Specify an initial state file.  This can be simply\n";
    print "    a file name, in which case the file is assumed to be stored \n";
    print "    under \$PROJECT_DIR/state/<state_subdir> (see the -st option)\n";
    print "    or a complete path and file name (the path is needed if you\n";
    print "    want this file to come from a different location than where\n";
    print "    the output state files will be stored). This option only\n";
    print "    works if the tag <INITIAL> is present in the model\'s \n";
    print "    input.template file.\n";
    print "    <init_file>  = Initial state file name.\n";
    print "    Default: model starts from its default initial model state.\n";
    print "\n";
    print "  -st <state_subdir>\n";
    print "    (optional) Specify a subdirectory, under \$PROJECT_DIR/state,\n";
    print "    where the state file tree should start.\n";
    print "    <state_subdir> = name of the subdirectory.\n";
    print "    Default: If results_subdir has been specified and\n";
    print "    state_subdir has not, then state_subdir is set equal to the\n";
    print "    results_subdir (i.e. state file tree starts under \n";
    print "    \$PROJECT_DIR/state/\$results_subdir).\n";
    print "    If neither results_subdir nor state_subdir have been\n";
    print "    specified, but forcing_subdir has been specified, then\n";
    print "    state_subdir = forcing_subdir\n";
    print "\n";
    print "  -uncmp\n";
    print "    (optional) If specified, results files will NOT be compressed\n";
    print "    by gathering; i.e. cells will indexed by row and column,\n";
    print "    allowing space for cells that aren\'t in the land mask (e.g.\n";
    print "    ocean cells or cells outside the catchment).\n";
    print "    Default: cells ARE compressed by gathering, i.e. they will be\n";
    print "    stored in a 1-D array and cells not in the land mask will be\n";
    print "    skipped.\n";
    print "\n";
    print "  -x <varnames>\n";
    print "    (optional) Extract some set of variables from the netcdf-\n";
    print "    format model result files and write them to  vic-style ascii\n";
    print "    files.  These will be stored in the \"/asc\" subdirectory of\n";
    print "    the results directory.\n";
    print "    <varnames> = comma-separated list of variable names to\n";
    print "    extract.\n";
    print "    Default: If -x is NOT specified, the variables listed in the\n";
    print "    model config file will be extracted to ascii. To skip the\n";
    print "    extraction of variables to ascii, specify \"none\" for the\n";
    print "    list of variable names (or remove the list from the model\n";
    print "    config file).\n";
    print "\n";
    print "  -mspc \"<model-specific parameters>\"\n";
    print "    (optional) Any parameters needed specifically for the model\n";
    print "    that you are running. The entire set of parameters should be\n";
    print "    enclosed in double quotes (\").\n";
    print "    Example: for SAC model, need to specify the directory where\n";
    print "    pe files are located, as:\n";
    print "    run_model.pl (blah blah) -mspc \"-pe path_to_pe_files\"\n";
    print "\n";
    print "  -l\n";
    print "    (optional) If specified, input data will be copied to a drive\n";
    print "    that is local to the node that the script is being run on;\n";
    print "    results will be written to this local drive, and then the\n";
    print "    results will be copied to the central drive when the run is\n";
    print "    finished. This reduces network traffic on the cluster and\n";
    print "    speeds up performance dramatically.\n";
    print "\n";
  }
}
