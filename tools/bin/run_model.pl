#!<SYSTEM_PERL_EXE> -w

=pod

=head1 NAME

run_model.pl

=head1 SYNOPSIS

run_model.pl
 [options] -m <model> -p <project> -s <start_date> -e <end_date>

 Options:
    --help|h|?                  brief help message
    --man|info                  full documentation
    -uncmp                      do not compress output
    -f <forcing_subdir>         forcing subdirectory
    -r <results_subdir>         results subdirectory
    -i <init_file>              state file for startup
    -st <state_subdir>          state subdirectory
    -x <varnames>               extract variables from netcdf
    -mspc <model-specific parameters>
                                model-specific parameters
    -t <model template>         input template        

 Required
    -m <model>                  model
    -p <project>                project
    -s <start_date>             simulation start (YYYY-MM-DD)
    -e <end_date>               simulation end (YYYY-MM-DD)

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

-r <results_subdir>

   (optional) Specify the subdirectory, under $PROJECT_DIR/results, where
   results file tree starts.  <results_subdir> = subdirectory name.  Default: If
   forcing_subdir has been specified and results_subdir has not, then
   results_subdir = forcing_subdir (i.e. results file tree starts under
   $PROJECT_DIR/results/\$forcing_subdir).

-i <init_file>

   (optional) Specify an initial state file.  This can be simply a file name, in
   which case the file is assumed to be stored under
   $PROJECT_DIR/state/<state_subdir> (see the -st option) or a complete path
   and file name (the path is needed if you want this file to come from a
   different location than where the output state files will be stored). This
   option only works if the tag <INITIAL> is present in the model\'s
   input.template file.  <init_file> = Initial state file name.  Default: model
   starts from its default initial model state.

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

-t <input template>

   (optional) Possible override for the input template that is used for the
   model simulation. This file must be stored in PARAMS_MODEL_DIR, but will be
   read instaed of the default input.template

=cut

#-------------------------------------------------------------------------------
no warnings qw(once);  # don't like this, but there are global
                       # variables used by model_specific.pl
use lib qw(<SYSTEM_INSTALLDIR>/lib <SYSTEM_PERL_LIBS>);
use Log::Log4perl qw(:easy);
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
use Date::Calc qw(Days_in_Month Delta_Days Add_Delta_Days);

# Access to environment variables
use Env;
use POSIX qw(strftime);

# Model-specific subroutines
require "$TOOLS_DIR/model_specific.pl";

#-------------------------------------------------------------------------------
# Parse the command line
#-------------------------------------------------------------------------------
Log::Log4perl->init('<SYSTEM_LOG_CONFIG>');

# Default values
$forcing_subdir = "";
$results_subdir = "";
$state_subdir   = "";
$UNCOMP_OUTPUT  = 0;
$init_file      = "";
$extract_vars   = "";

# Hash used in GetOptions function
# format: option => \$variable_to_set
my $result = GetOptions(
                        "help|h|?" => \$help,
                        "man|info" => \$man,
                        "m=s"      => \$MODEL_NAME,
                        "p=s"      => \$PROJECT,
                        "f=s"      => \$forcing_subdir,
                        "s=s"      => \$start_date,
                        "e=s"      => \$end_date,
                        "r=s"      => \$results_subdir,
                        "i=s"      => \$init_file,
                        "st=s"     => \$state_subdir,
                        "uncmp"    => \$UNCOMP_OUTPUT,
                        "x=s"      => \$extract_vars,
                        "mspc=s"   => \$model_specific,
                        "t=s"      => \$input_template
                       );

#-------------------------------------------------------------------------------
# Validate the command-line arguments
#-------------------------------------------------------------------------------
pod2usage(-verbose => 2, -exitstatus => 0) if $man;
pod2usage(-verbose => 2, -exitstatus => 0) if $help;

# Validate required arguments
pod2usage(-verbose => 1, -exitstatus => -1)
  if not defined($MODEL_NAME) or
    not defined($PROJECT)    or
    not defined($start_date) or
    not defined
    ($end_date);

# Parse & validate start/end dates
if ($start_date =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/) {
  ($start_year, $start_month, $start_day) = ($1, $2, $3);
} else {
  LOGWARN("Start date must have format YYYY-MM-DD.");
  pod2usage(-verbose => 1, -exitstatus => -1);
}
if ($end_date =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/) {
  ($end_year, $end_month, $end_day) = ($1, $2, $3);
} else {
  LOGWARN("End date must have format YYYY-MM-DD.");
  pod2usage(-verbose => 1, -exitstatus => -1);
}
if ($start_year > $end_year) {
  LOGWARN("tart_date is later than end_date: " . "start_year > end_year.");
  pod2usage(-verbose => 1, -exitstatus => -1);
} elsif ($start_year == $end_year) {
  if ($start_month > $end_month) {
    LOGWARN("Start_date is later than end_date: " .
            "start_year == end_year and start_month > end_month");
    pod2usage(-verbose => 1, -exitstatus => -1);
  } elsif ($start_month == $end_month) {
    if ($start_day > $end_day) {
      LOGWARN("Start_date is later than end_date: " .
              "start_year == end_year, start_month == end_month " .
              "and start_day > end_day.");
      pod2usage(-verbose => 1, -exitstatus => -1);
    }
  }
}

# Default values of $results_subdir and $state_subdir
if ($forcing_subdir) {
  if (!$results_subdir) {
    $results_subdir = $forcing_subdir;
  }
}
if ($results_subdir) {
  if (!$state_subdir) {
    $state_subdir = $results_subdir;
  }
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
$var_info_project{"RESULTS_MODEL_ASC_DIR"} =~
  s/<RESULTS_SUBDIR>/$results_subdir/g;
$var_info_project{"STATE_MODEL_DIR"}   =~ s/<STATE_SUBDIR>/$state_subdir/g;
$var_info_project{"CONTROL_MODEL_DIR"} =~ s/<CONTROL_SUBDIR>/$state_subdir/g;
$var_info_project{"LOGS_MODEL_DIR"}    =~ s/<LOGS_SUBDIR>/$state_subdir/g;
if ($var_info_model{"POSTPROC"}) {
  $var_info_model{"POSTPROC"} =~ s/<TOOLS_DIR>/$TOOLS_DIR/g;
  $var_info_model{"POSTPROC"} =~ s/<START_DATE>/$start_date/g;
  $var_info_model{"POSTPROC"} =~ s/<END_DATE>/$end_date/g;

  # The final processed model results will be stored in the ascii dir
  $var_info_model{"POSTPROC"} =~
    s/<RESULTS_DIR_FINAL>/$var_info_project{"RESULTS_MODEL_ASC_DIR"}/g;
}

# Save relevant project info in variables
$ParamsModelDir     = $var_info_project{"PARAMS_MODEL_DIR"};
$ForcingModelDir    = $var_info_project{"FORCING_MODEL_DIR"};
$ResultsModelRawDir = $var_info_project{"RESULTS_MODEL_RAW_DIR"};
$ResultsModelAscDir = $var_info_project{"RESULTS_MODEL_ASC_DIR"};
$StateModelDir      = $var_info_project{"STATE_MODEL_DIR"};
$ControlModelDir    = $var_info_project{"CONTROL_MODEL_DIR"};
$LogsModelDir       = $var_info_project{"LOGS_MODEL_DIR"};
$forcing_format     = $var_info_project{"FORCING_FORMAT_DIR"};

# The final processed model results will be stored in the ascii dir
$ResultsModelFinalDir = $ResultsModelAscDir;
$ForcTypeAscVic       = $var_info_project{"FORCING_TYPE_ASC_VIC"};
$ForcTypeNC           = $var_info_project{"FORCING_TYPE_NC"};
$ForcingAscVicPrefix  = $var_info_project{"FORCING_ASC_VIC_PREFIX"};
$ForcingNCPrefix      = $var_info_project{"FORCING_NC_PREFIX"};
if ($forcing_subdir =~ /retro/i) {
  $StartDateFile = $var_info_project{"FORCING_RETRO_START_DATE_FILE"};
} elsif ($forcing_subdir =~ /spinup_nearRT/i) {
  $StartDateFile = $var_info_project{"FORCING_NEAR_RT_START_DATE_FILE"};
} elsif ($forcing_subdir =~ /curr_spinup/i) {
  $StartDateFile = $var_info_project{"FORCING_CURRSPIN_START_DATE_FILE"};
}

# Save relevant model info in variables
$MODEL_EXE_DIR      = $var_info_model{"MODEL_EXE_DIR"};
$MODEL_EXE_NAME     = $var_info_model{"MODEL_EXE_NAME"};
$MODEL_SUBDIR       = $var_info_model{"MODEL_SUBDIR"};
$MODEL_FORCING_TYPE = $var_info_model{"FORCING_TYPE"};
$OUTPUT_PREFIX      = $var_info_model{"OUTPUT_PREFIX"};
@output_prefixes    = split /,/, $OUTPUT_PREFIX;
if (!$extract_vars) {
  $extract_vars = $var_info_model{"EXTRACT_VARS"};
}
if ($var_info_model{"POSTPROC"}) {
  $POSTPROC_STR = $var_info_model{"POSTPROC"};
  @POSTPROC = split /;;/, $POSTPROC_STR;
}
if ($MODEL_FORCING_TYPE eq $ForcTypeAscVic) {
  $prefix = $ForcingAscVicPrefix;
} elsif ($MODEL_FORCING_TYPE eq $ForcTypeNC) {
  $prefix = $ForcingNCPrefix;
}

# Date of beginning of data forcings
open(FILE, $StartDateFile) or
  LOGDIE("Cannot open file $StartDateFile");
foreach (<FILE>) {
  if (/^(\d+)\s+(\d+)\s+(\d+)\s+/) {
    ($Forc_Syr, $Forc_Smon, $Forc_Sday) = ($1, $2, $3);
  }
}
close(FILE);

#---------------------------------------------------
# HACK!
if ("<SYSTEM_LOCAL_STORAGE>" =~ /true/i) {
  $local_root        = "<SYSTEM_LOCAL_ROOT>";
  $PROJECT_DIR       = $var_info_project{"PROJECT_DIR"};
  $LOCAL_PROJECT_DIR = $var_info_project{"LOCAL_PROJECT_DIR"};
  $replace           = "<SYSTEM_ROOT>";
  $LOCAL_PROJECT_DIR =~ s/$replace/$local_root/;
}

#---------------------------------------------------
# Model parameters
if (defined $input_template) {
  $ParamsTemplate = "$ParamsModelDir/$input_template";
} else {
  $ParamsTemplate = "$ParamsModelDir/input.template";
}
open(PARAMS_TEMPLATE, $ParamsTemplate) or
  LOGDIE("Cannot open parameter template file $ParamsTemplate");
@ParamsInfo = <PARAMS_TEMPLATE>;
close(PARAMS_TEMPLATE);

# Check for directories; create if necessary & appropriate
foreach $dir ($ParamsModelDir, $ForcingModelDir) {
  if (!-d $dir) {
    LOGDIE("Directory $dir not found");
  }
}
foreach $dir (
              $ResultsModelRawDir,   $ResultsModelAscDir,
              $ResultsModelFinalDir, $StateModelDir,
              $ControlModelDir,      $LogsModelDir
  ) {
  (&make_dir($dir) == 0) or LOGDIE("Cannot create path $dir: $!");
}

# Output Directories
$results_dir     = $ResultsModelRawDir;
$results_dir_asc = $ResultsModelAscDir;
$state_dir       = $StateModelDir;
$control_dir     = $ControlModelDir;
$logs_dir        = $LogsModelDir;

# Use local directories if specified
if ("<SYSTEM_LOCAL_STORAGE>" =~ /true/i) {
  $LOCAL_RESULTS_DIR = $ResultsModelRawDir;
  $LOCAL_RESULTS_DIR =~ s/$PROJECT_DIR/$LOCAL_PROJECT_DIR/g;
  $LOCAL_RESULTS_DIR_ASC = $ResultsModelAscDir;
  $LOCAL_RESULTS_DIR_ASC =~ s/$PROJECT_DIR/$LOCAL_PROJECT_DIR/g;
  $LOCAL_STATE_DIR = $StateModelDir;
  $LOCAL_STATE_DIR =~ s/$PROJECT_DIR/$LOCAL_PROJECT_DIR/g;
  $LOCAL_CONTROL_DIR = $ControlModelDir;
  $LOCAL_CONTROL_DIR =~ s/$PROJECT_DIR/$LOCAL_PROJECT_DIR/g;
  $LOCAL_LOGS_DIR = $LogsModelDir;
  $LOCAL_LOGS_DIR =~ s/$PROJECT_DIR/$LOCAL_PROJECT_DIR/g;
  $results_dir     = $LOCAL_RESULTS_DIR;
  $results_dir_asc = $LOCAL_RESULTS_DIR_ASC;
  $state_dir       = $LOCAL_STATE_DIR;
  $control_dir     = $LOCAL_CONTROL_DIR;
  $logs_dir        = $LOCAL_LOGS_DIR;

  # Clean out the directories if they exist
  foreach $dir ($state_dir, $control_dir, $logs_dir) {
    if (-e $dir) {
      $cmd = "rm -rf $dir";
      (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
    }
  }
}

# Clean out the directories if they exist
foreach $dir ($results_dir, $results_dir_asc) {
  if (-e $dir) {
    $cmd = "rm -rf $dir";
    (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
  }
}

# Create the directories
foreach $dir ($results_dir, $results_dir_asc, $state_dir, $control_dir,
              $logs_dir) {
  (&make_dir($dir) == 0) or LOGDIE("Cannot create path $dir: $!");
}

# Override initial state file if specified on command line
if ($init_file) {
  if (!-e $init_file) {
    if (-e "$state_dir/$init_file") {
      $init_file = "$state_dir/$init_file";
    } else {
      LOGDIE("Init file $init_file not found");
    }
  }
}
$LOGFILE     = "$logs_dir/log.$MODEL_NAME.$JOB_ID";
$controlfile = "$control_dir/inp.$MODEL_NAME.$JOB_ID";

#-------------------------------------------------------------------------------
# END settings
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# Model execution
#-------------------------------------------------------------------------------
if ($model_specific) {
  $model_specific =~ s/"//g;
}
$func_name = "wrap_run_" . $modelalias;
&{$func_name}($model_specific);

#-------------------------------------------------------------------------------
# Copy results from local directories to absolute directories, if specified
#-------------------------------------------------------------------------------
if ("<SYSTEM_LOCAL_STORAGE>" =~ /true/i) {
  $RESULTS_DIR     = $ResultsModelRawDir;
  $RESULTS_DIR_ASC = $ResultsModelAscDir;
  $STATE_DIR       = $StateModelDir;
  $CONTROL_DIR     = $ControlModelDir;
  $LOGS_DIR        = $LogsModelDir;
  foreach $prefix (@output_prefixes) {
    $cmd =
      "cp --no-dereference --preserve=link $LOCAL_RESULTS_DIR/$prefix* " .
      "$RESULTS_DIR/";
    (($status = &shell_cmd($cmd, $LOGFILE)) == 0) or
      LOGDIE("$cmd failed: $status");
  }
  $cmd = "cp -r $LOCAL_RESULTS_DIR_ASC $RESULTS_DIR_ASC/../";
  (($status = &shell_cmd($cmd, $LOGFILE)) == 0) or
    LOGDIE("$cmd failed: $status");
  $cmd =
    "cp --no-dereference --preserve=link $LOCAL_CONTROL_DIR/* $CONTROL_DIR/";
  (($status = &shell_cmd($cmd, $LOGFILE)) == 0) or
    LOGDIE("$cmd failed: $status");
  $cmd = "cp --no-dereference --preserve=link $LOCAL_STATE_DIR/* $STATE_DIR/";
  (($status = &shell_cmd($cmd, $LOGFILE)) == 0) or
    LOGDIE("$cmd failed: $status");
  $cmd = "cp --no-dereference --preserve=link $LOCAL_LOGS_DIR/* $LOGS_DIR/";
  (($status = &shell_cmd($cmd, $LOGFILE)) == 0) or
    LOGDIE("$cmd failed: $status");
  $cmd =
    "rm -rf $LOCAL_RESULTS_DIR $LOCAL_RESULTS_DIR_ASC $LOCAL_STATE_DIR " .
    "$LOCAL_CONTROL_DIR $LOCAL_LOGS_DIR";
  (($status = &shell_cmd($cmd)) == 0) or
    LOGDIE("$cmd failed: $status");
}
exit(0);
