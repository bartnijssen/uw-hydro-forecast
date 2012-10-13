#!<SYSTEM_PERL_EXE> -w
=pod

=head1 NAME

run_rout_model.pl

=head1 SYNOPSIS

run_rout_model.pl
 [options] -m <model> -p <project> -s <start_date> -e <end_date> -en <year>

 Options:
    --help|h|?                  brief help message
    --man|info                  full documentation
    -uncmp                      do not compress output
    -l                          use local storage in cluster environment
    -f <forcing_subdir>         forcing subdirectory
    -r <results_subdir>         results subdirectory
    -st <state_subdir>          state subdirectory
    -x <varnames>               extract variables from netcdf
    -mspc <model-specific parameters>
                                model-specific parameters

 Required
    -m <model>                  model
    -p <project>                project
    -s <start_date>             simulation start (YYYY-MM-DD)
    -e <end_date>               simulation end (YYYY-MM-DD)
    -en <year>                  year of met forcings used in run
    -i <date of statefile>      date of state file (YYYYMMDD)

=head1 DESCRIPTION

Script to run a model within the forecast system.

Given ALMA-compliant forcings in NetCDF format, runs a model over the specified
simulation period and produces ALMA-compliant output files in NetCDF format.

The forcing files are each assumed to contain 1 month of data.

The files are assumed to have names of the form:
    prefix.YYYYMM.nc
where
    prefix = some alphanumeric string
    YYYY   = 4-digit year
    MM     = 2-digit month

The model output files will each contain 1 month of data aggregated to daily
intervals, and will have names following the same convention as the forcing
files. The prefixes on these files are defined in the model configuration file.

Arguments:

-m <model>

   Name of model to run.

-p <project> 

   Name of project or basin to simulate.  This script will look for
   project-specific parameters, including \$PROJECT_DIR, in the file
   <SYSTEM_INSTALLDIR>/config/config.<project>.

-f <forcing_subdir>

   (optional) subdirectory, under $PROJECT_DIR/forcing, where forcing file tree
   starts. Default: forcing file tree is directly under $PROJECT_DIR/forcing.

-s <start_date>

   Start date of the simulation. Format: YYYY-MM-DD.

-e <end_date>

   End date of the simulation. Format: YYYY-MM-DD.

-en <year>
  
   Year from which the met forcings come that are being used.

-r <results_subdir>

   (optional) Specify the subdirectory, under $PROJECT_DIR/results, where
   results file tree starts.  <results_subdir> = subdirectory name.  Default: If
   forcing_subdir has been specified and results_subdir has not, then
   results_subdir = forcing_subdir (i.e. results file tree starts under
   $PROJECT_DIR/results/\$forcing_subdir).

-i date of state

  Date of forecast initialization date.  Same as the day of state file. It
  should be changed to a day after the state day for the VIC version 4.0.6 and
  after. State date must have format YYYYMMDD.

-st <state_subdir>

   (optional) Specify a subdirectory, under $PROJECT_DIR/state, where the state
   file tree should start.  <state_subdir> = name of the subdirectory.  Default:
   If results_subdir has been specified and state_subdir has not, then
   state_subdir is set equal to the results_subdir (i.e. state file tree starts
   under $PROJECT_DIR/state/\$results_subdir).  If neither results_subdir nor
   state_subdir have been specified, but forcing_subdir has been specified, then
   state_subdir = forcing_subdir

-uncmp

   (optional) If specified, results files will NOT be compressed by gathering;
   i.e. cells will indexed by row and column, allowing space for cells that
   aren\'t in the land mask (e.g.  ocean cells or cells outside the catchment).
   Default: cells ARE compressed by gathering, i.e. they will be stored in a 1-D
   array and cells not in the land mask will be skipped.

-x <varnames>

   (optional) Extract some set of variables from the netcdf- format model result
   files and write them to vic-style ascii files.  These will be stored in the
   \"/asc\" subdirectory of the results directory.  <varnames> = comma-separated
   list of variable names to extract.  Default: If -x is NOT specified, the
   variables listed in the model config file will be extracted to ascii. To skip
   the extraction of variables to ascii, specify \"none\" for the list of
   variable names (or remove the list from the model config file).

-mspc <model-specific parameters>

   (optional) Any parameters needed specifically for the model that you are
   running. The entire set of parameters should be enclosed in double quotes
   (\").  Example: for SAC model, need to specify the directory where pe files
   are located, as: run_model.pl (blah blah) -mspc "-pe path_to_pe_files"

-l 

   (optional) If specified, input data will be copied to a drive that is local
   to the node that the script is being run on; results will be written to this
   local drive, and then the results will be copied to the central drive when
   the run is finished. This reduces network traffic on the cluster and speeds
   up performance dramatically.

-z  

   (optional) ZIP and move results directory into ESP storage directory when
   specified

=cut

#-------------------------------------------------------------------------------
no warnings qw(once);           # don't like this, but there are global
                                # variables used by model_specific.pl
use lib qw(<SYSTEM_INSTALLDIR>/lib <SYSTEM_PERL_LIBS>);
use Getopt::Long;
use Pod::Usage;

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

# This allows us to use sophisticated command-line argument parsing
use Getopt::Long;

# Date arithmetic
use Date::Calc qw(Add_Delta_Days Add_Delta_YM);

# Access to environment variables
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
my $result = GetOptions(
                        "help|h|?"  => \$help,
                        "man|info"  => \$help,
                        "m=s"       => \$MODEL_NAME,
                        "p=s"       => \$PROJECT,
                        "f=s"       => \$forcing_subdir,
                        "s=s"       => \$start_date,
                        "e=s"       => \$end_date,
                        "r=s"       => \$results_subdir,
                        "i=s"       => \$DATE,
                        "en=i"      => \$ENS_YR,
                        "z=i"       => \$esp_storage,
                        "uncmp"     => \$UNCOMP_OUTPUT,
                        "l"         => \$local_storage,
                        "x=s"       => \$extract_vars,
                        "mspc"      => \$model_specific,
                       );

#-------------------------------------------------------------------------------
# Validate the command-line arguments
#-------------------------------------------------------------------------------
pod2usage(-verbose => 2, -exitstatus => 0) if $man;
pod2usage(-verbose => 2, -exitstatus => 0) if $help;

# Validate required arguments
pod2usage(-verbose => 1, -exitstatus => -1) 
  if not defined ($MODEL_NAME) or not defined ($PROJECT) 
  or not defined ($start_date) or not defined($end_date) 
  or not defined($ENS_YR) or not defined($DATE);

# Parse & validate start/end dates
if ($start_date =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/) {
  ($start_year, $start_month, $start_day) = ($1, $2, $3);
} else {
  print STDERR "$0: ERROR: start date must have format YYYY-MM-DD.\n";
  pod2usage(-verbose => 1, -exitstatus => -1);
}
if ($end_date =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/) {
  ($end_year, $end_month, $end_day) = ($1, $2, $3);
} else {
  print STDERR "$0: ERROR: end date must have format YYYY-MM-DD.\n";
  pod2usage(-verbose => 1, -exitstatus => -1);
}
if ($start_year > $end_year) {
  print STDERR "$0: ERROR: start_date is later than end_date: " .
    "start_year > end_year.\n";
  pod2usage(-verbose => 1, -exitstatus => -1);
} elsif ($start_year == $end_year) {
  if ($start_month > $end_month) {
    print STDERR "$0: ERROR: start_date is later than end_date: " .
      "start_year == end_year and start_month > end_month.\n";
    pod2usage(-verbose => 1, -exitstatus => -1);
  } elsif ($start_month == $end_month) {
    if ($start_day > $end_day) {
      print STDERR "$0: ERROR: start_date is later than end_date: " .
        "start_year == end_year, start_month == end_month " .
          "and start_day > end_day.\n";
      pod2usage(-verbose => 1, -exitstatus => -1);
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
  pod2usage(-verbose => 1, -exitstatus => -1);  usage("full");
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
$modelalias         = $var_info_model{MODEL_ALIAS};

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
  "$ESP/$modelalias/$FCST_DATE/dly_flux";  #### ESP FLUXOUTPUT storage directory
$STOR_ROUT_DIR =
  "$ROUT/$modelalias/$FCST_DATE/sflow";    #### ESP Rout storage directory

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
              $ResultsModelFinalDir, $ControlModelDir,      
              $LogsModelDir
  ) {
  (&make_dir($dir) == 0) or die "$0: ERROR: Cannot create path $dir: $!\n";
}

# Output Directories
$results_dir     = $ResultsModelRawDir;
$results_dir_asc = $ResultsModelAscDir;
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
    (&make_dir($dir) == 0) or die "$0: ERROR: Cannot create path $dir: $!\n";
  }
}
$LOGFILE = "$LogsModelDir/log.rout.$PROJECT.$MODEL_NAME.$DATE.$ENS_YR";

###### if ESP_STORAGE = 1
if ($esp_storage) {
  if (!-e $results_dir_asc) {
    $dir = $results_dir_asc;
    (&make_dir($dir) == 0) or die "$0: ERROR: Cannot create path $dir: $!\n";
  }
  $cmd = "tar -xzf $STORDIR/fluxes.$ENS_YR.tar.gz -C $results_dir_asc";
  (($status = &shell_cmd($cmd, $LOGFILE)) == 0) or
    die "$0: ERROR: $cmd failed: $status\n";
  $temp_results_dir = "$results_dir_asc" . '/ESP.' . "$ENS_YR";
  $results_dir_asc  = "$temp_results_dir";
}

####### Running routing model ####################
$func_name = "wrap_run_" . "rout";
&{$func_name}($model_specific);

#-------------------------------------------------------------------------------
# ZIP and move FLuxoutput directory into ESP storage directory when specified if
# $esp_storage = 1
#-------------------------------------------------------------------------------
if (!-e $STORDIR) {
  $dir = $STORDIR;
  (&make_dir($dir) == 0) or die "$0: ERROR: Cannot create path $dir: $!\n";
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
  $dir = $STOR_ROUT_DIR;
  (&make_dir($dir) == 0) or die "$0: ERROR: Cannot create path $dir: $!\n";
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
