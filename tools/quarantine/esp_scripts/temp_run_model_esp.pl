#!/usr/bin/perl
# SGE directives
#$ -cwd
#$ -j y
#$ -S /usr/bin/perl
#
# run_model.pl: Script to run a model within SIMMA framework
#
# usage: see usage() function below
#
# Author: Ted Bohn
# $Id: $
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Preliminary Stuff
#-------------------------------------------------------------------------------

# This allows us to use sophisticated command-line argument parsing
use Getopt::Long;

# Date arithmetic
use Date::Calc qw(Days_in_Month Delta_Days Add_Delta_Days);

# Access to environment variables
use Env;

# Set up netcdf access
$ENV{INC_NETCDF} = "/usr/local/i386/include";
$ENV{LIB_NETCDF} = "/usr/local/i386/lib";

# Root Directory - Edit this to reflect location of your SIMMA installation
$ROOT_DIR = "/raid8/forecast/sw_monitor";

# Utility subroutines
require "$ROOT_DIR/tools/simma_util.pl";

# Model-specific subroutines
require "$ROOT_DIR/tools/model_specific.pl";

# Constants
@month_days = (31,28,31,30,31,30,31,31,30,31,30,31);
@output_prefixes = ("wb","eb","sur","sub","eva","csp");

# Unique identifier for this job
$JOB_ID = `date +%y%m%d-%H%M%S`;
if ($JOB_ID =~ /(\S+)/) {
  $JOB_ID = $1;
}

# Default values
$forcing_subdir = "";
$results_subdir = "";
$state_subdir = "";
$SAVE_YEARLY = 0;
$UNCOMP_OUTPUT = 0;
$forcing_str = "";
$init_file = "";
$extract_vars = "";
$local_storage = 0;


#-------------------------------------------------------------------------------
# Parse the command line
#-------------------------------------------------------------------------------

# Hash used in GetOptions function
# format: option => \$variable_to_set
%options_hash = (
  h   => \$help,
  m   => \$MODEL_NAME,
  p   => \$project,
  f   => \$forcing_subdir,
  pf  => \$prefix,
  s   => \$start_date,
  e   => \$end_date,
  r   => \$results_subdir,
  i   => \$init_file,
  st  => \$state_subdir,
  uncmp => \$UNCOMP_OUTPUT,
  l   => \$local_storage,
  x   => \$extract_vars,
  mspc => \$model_specific,
);

# This parses the command-line arguments and sets values for the variables in %option_hash
$status = &GetOptions(\%options_hash,"h","m=s","p=s","f=s","pf=s","s=s","e=s","r=s","i=s","st=s","uncmp","l","x=s","mspc=s");

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
if (!$project) {
  print STDERR "$0: ERROR: no project specified\n";
  usage("short");
  exit(-1);
}
if (!$prefix) {
  print STDERR "$0: ERROR: no prefix specified\n";
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
  ($start_year,$start_month,$start_day) = ($1,$2,$3);
}
else {
  print STDERR "$0: ERROR: start date must have format YYYY-MM-DD.\n";
  usage("full");
  exit(-1);
}
if ($end_date =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/) {
  ($end_year,$end_month,$end_day) = ($1,$2,$3);
}
else {
  print STDERR "$0: ERROR: end date must have format YYYY-MM-DD.\n";
  usage("full");
  exit(-1);
}
if ($start_year > $end_year) {
  print STDERR "$0: ERROR: start_date is later than end_date: start_year > end_year.\n";
  usage("short");
  exit(-1);
}
elsif ($start_year == $end_year) {
  if ($start_month > $end_month) {
    print STDERR "$0: ERROR: start_date is later than end_date: start_year == end_year and start_month > end_month.\n";
    usage("short");
    exit(-1);
  }
  elsif ($start_month == $end_month) {
    if ($start_day > $end_day) {
      print STDERR "$0: ERROR: start_date is later than end_date: start_year == end_year, start_month == end_month, and start_day > end_day.\n";
      usage("short");
      exit(-1);
    }
  }
}

# Yearly state saving NO SAVING OF STATE FILES FOR ESP RUNS
# **************************************
if ($state_date =~ /^(\d\d)-(\d\d)$/) {
  ($state_year,$state_month,$state_day) = (9999,$1,$2);
  $SAVE_YEARLY = 1;
}
elsif ($state_date) {
  print STDERR "$0: ERROR: state date must have format MM-DD.\n";
  usage("full");
  exit(-1);
}
else {
  ($state_year,$state_month,$state_day) = ($end_year,$end_month,$end_day);
}

## ***************************************
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
# Get configuration information
#-------------------------------------------------------------------------------

$TOOLS_DIR = "$ROOT_DIR/tools";
$CONFIG_DIR = "$ROOT_DIR/config";
$CONFIG_MODEL = "$CONFIG_DIR/config.model.$MODEL_NAME";
$CONFIG_PROJECT = "$CONFIG_DIR/config.project.$project";

# Model configuration info
@POSTPROC = ();
open (CONFIG_MODEL, $CONFIG_MODEL) or die "$0: ERROR: cannot open model config file $CONFIG_MODEL\n";
CONFIG_MODEL_LOOP: foreach (<CONFIG_MODEL>) {
  chomp;
  if (/^#/) {
    next CONFIG_MODEL_LOOP;
  }
  @fields = split /\s+/;
  if ($fields[0] =~ /^MODEL_SRC_DIR$/) {
    $MODEL_SRC_DIR = $fields[1];
  }
  elsif ($fields[0] =~ /^MODEL_EXE_DIR$/) {
    $MODEL_EXE_DIR = $fields[1];
  }
  elsif ($fields[0] =~ /^MODEL_EXE_NAME$/) {
    $MODEL_EXE_NAME = $fields[1];
  }
  elsif ($fields[0] =~ /^MODEL_VER$/) {
    $MODEL_VER = $fields[1];
  }
  elsif ($fields[0] =~ /^EXTRACT_VARS$/ && !$extract_vars) {
    $extract_vars = $fields[1];
  }
  elsif ($fields[0] =~ /^POSTPROC$/) {
    shift @fields;
    $line = join " ", @fields;
    push @POSTPROC, $line;
  }
}
close (CONFIG_MODEL);

# Project configuration info
open (CONFIG_PROJECT, $CONFIG_PROJECT) or die "$0: ERROR: cannot open project config file $CONFIG_PROJECT\n";
CONFIG_PROJECT_LOOP: foreach (<CONFIG_PROJECT>) {
  chomp;
  if (/^#/) {
    next CONFIG_PROJECT_LOOP;
  }
  @fields = split /\s+/;
  if ($fields[0] =~ /^PROJECT_DIR$/) {
    $PROJECT_DIR = $fields[1];
  }
  elsif ($fields[0] =~ /^LOCAL_PROJECT_DIR$/) {
    $LOCAL_PROJECT_DIR = $fields[1];
  }
  elsif ($fields[0] =~ /^EQUAL_AREA$/) {
    $EQUAL_AREA = $fields[1];
  }
  elsif ($fields[0] =~ /^RESOLUTION$/) {
    $RESOLUTION = $fields[1];
  }
}
close (CONFIG_PROJECT);


#---------------------------------------------------
# HACK!
if ($local_storage) {
$uname = `uname -a`;
if ($uname =~ /compute-(...)/) {
  $nodename = $1;
}
if (!$nodename) {
  die "$0: ERROR: node name not found\n";
}

# Determine local dir
if ($nodename =~ /c-(0|1|2|3|4)/) {
  $local_root = "/state/partition2";
}
else {
  $local_root = "/state/partition1";
}

$LOCAL_PROJECT_DIR =~ s/\/raid/$local_root/;
}
#---------------------------------------------------


# Model parameters
$PARAMS_DIR = "$PROJECT_DIR/params/$MODEL_NAME";
$PARAMS_TEMPLATE = "$PARAMS_DIR/input.template";
open (PARAMS_TEMPLATE, $PARAMS_TEMPLATE) or die "$0: ERROR: cannot open parameter config file $PARAMS_TEMPLATE\n";
@params_template = <PARAMS_TEMPLATE>;
close (PARAMS_TEMPLATE);

# Forcing configuration info
$FORCING_TREE_DIR = "$PROJECT_DIR/forcing/$forcing_subdir";
$FORCING_DIR = "$FORCING_TREE_DIR/nc";

# Output configuration info
$RESULTS_DIR = "$PROJECT_DIR/results/$results_subdir/$MODEL_NAME/esp/nc";
$RESULTS_DIR_ASC = "$PROJECT_DIR/results/$results_subdir/$MODEL_NAME/temp/asc";
$LOGS_DIR = "$PROJECT_DIR/logs/$results_subdir/$MODEL_NAME";
$CONTROL_DIR = "$PROJECT_DIR/control/$results_subdir/$MODEL_NAME";
$STATE_DIR = "$PROJECT_DIR/state/$state_subdir/$MODEL_NAME";
$results_dir = $RESULTS_DIR;
$results_dir_asc = $RESULTS_DIR_ASC;
$logs_dir = $LOGS_DIR;
$control_dir = $CONTROL_DIR;
$state_dir = $STATE_DIR;

# Check for directories; create if necessary
if (!-d $FORCING_TREE_DIR) {
  die "$0: ERROR: forcing directory $FORCING_TREE_DIR not found\n";
}
foreach $dir ($RESULTS_DIR, $RESULTS_DIR_ASC, $LOGS_DIR, $CONTROL_DIR, $STATE_DIR) {
  $status = &make_dir($dir);
}

# Use local directories if specified
if ($local_storage) {
  $LOCAL_RESULTS_DIR = "$LOCAL_PROJECT_DIR/results/$results_subdir/$MODEL_NAME/daily/nc";
  $LOCAL_RESULTS_DIR_ASC = "$LOCAL_PROJECT_DIR/results/$results_subdir/$MODEL_NAME/daily/asc";
  $LOCAL_LOGS_DIR = "$LOCAL_PROJECT_DIR/results/$results_subdir/$MODEL_NAME/logs";
  $LOCAL_CONTROL_DIR = "$LOCAL_PROJECT_DIR/results/$results_subdir/$MODEL_NAME/control";
  $LOCAL_STATE_DIR = "$LOCAL_PROJECT_DIR/state/$state_subdir/$MODEL_NAME";
  $results_dir = $LOCAL_RESULTS_DIR;
  $results_dir_asc = $LOCAL_RESULTS_DIR_ASC;
  $logs_dir = $LOCAL_LOGS_DIR;
  $control_dir = $LOCAL_CONTROL_DIR;
  $state_dir = $LOCAL_STATE_DIR;
  # Clean out the directories if they exist
  foreach $dir ($LOCAL_RESULTS_DIR, $LOCAL_RESULTS_DIR_ASC, $LOCAL_LOGS_DIR, $LOCAL_CONTROL_DIR, $LOCAL_STATE_DIR) {
    if (-e $dir) {
      $cmd = "rm -rf $dir";
      (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
    }
  }
  # Create the directories
  foreach $dir ($LOCAL_RESULTS_DIR, $LOCAL_RESULTS_DIR_ASC, $LOCAL_LOGS_DIR, $LOCAL_CONTROL_DIR, $LOCAL_STATE_DIR) {
    $status = &make_dir($dir);
  }
}

# Override initial state file if specified on command line
if ($init_file) {
  if (!-e $init_file) {
    if (-e "$STATE_DIR/$init_file") {
      $init_file = "$STATE_DIR/$init_file";
    }
    else {
      die "$0: ERROR: init file $init_file not found\n";
    }
  }
}

$LOGFILE = "$logs_dir/log.$JOB_ID";
$controlfile = "$control_dir/inp.$JOB_ID";


#-------------------------------------------------------------------------------
# Model execution
#-------------------------------------------------------------------------------
$model_specific =~ s/"//g;
$func_name = "wrap_run_" . $MODEL_NAME;
if ($MODEL_NAME eq "noah_2.8") {
  $func_name = "wrap_run_noah";
}
&{$func_name}($model_specific);


#-------------------------------------------------------------------------------
# Copy results from local directories to absolute directories, if specified
#-------------------------------------------------------------------------------
if ($local_storage) {
  $cmd = "gzip $LOCAL_LOGS_DIR/*";
  (($status = &shell_cmd($cmd,$LOGFILE)) == 0) or die "$0: ERROR: $cmd failed: $status\n";
  foreach $prefix (@output_prefixes) {
    $cmd = "cp --no-dereference --preserve=link $LOCAL_RESULTS_DIR/$prefix* $RESULTS_DIR/";
    (($status = &shell_cmd($cmd,$LOGFILE)) == 0) or die "$0: ERROR: $cmd failed: $status\n";
  }
  $cmd = "cp -r $LOCAL_RESULTS_DIR_ASC $RESULTS_DIR_ASC/../";
  (($status = &shell_cmd($cmd,$LOGFILE)) == 0) or die "$0: ERROR: $cmd failed: $status\n";
  $cmd = "cp --no-dereference --preserve=link $LOCAL_STATE_DIR/* $STATE_DIR/";
  (($status = &shell_cmd($cmd,$LOGFILE)) == 0) or die "$0: ERROR: $cmd failed: $status\n";
#  $cmd = "cp --no-dereference --preserve=link $LOCAL_CONTROL_DIR/* $CONTROL_DIR/";
#  (($status = &shell_cmd($cmd,$LOGFILE)) == 0) or die "$0: ERROR: $cmd failed: $status\n";
  $cmd = "cp --no-dereference --preserve=link $LOCAL_LOGS_DIR/* $LOGS_DIR/";
  (($status = &shell_cmd($cmd,$LOGFILE)) == 0) or die "$0: ERROR: $cmd failed: $status\n";
  $cmd = "rm -rf $LOCAL_RESULTS_DIR $LOCAL_RESULTS_DIR_ASC $LOCAL_STATE_DIR $LOCAL_CONTROL_DIR $LOCAL_LOGS_DIR";
  (($status = &shell_cmd($cmd)) == 0) or die "$0: ERROR: $cmd failed: $status\n";
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
  print "  $0 [-h] -m <model> -p <project> [-f <forcing_subdir>] -pf <prefix> -s <start_date> -e <end_date> [-r <results_subdir>] [-i <init_file>] [-st <state_subdir>] [-uncmp] [-x <varnames>] [ -mspc <model-specific parameters> ] [-l]\n";
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
    print "these files will identify which variables they contain, as\n";
    print "follows:\n";
    print "  eb  = energy balance terms\n";
    print "  wb  = water balance terms\n";
    print "  sur = surface state terms\n";
    print "  sub = subsurface state terms\n";
    print "  eva = detailed evaporation-related terms\n";
    print "  csp = detailed cold-season-process terms\n";
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
    print "    <project>  = Name of project or basin to simulate.  This script will look for project-specific\n";
    print "                 parameters, including \$PROJECT_DIR, in the file \$ROOT_DIR/config/config.<project>.\n";
    print "\n";
    print "  -f <forcing_subdir>\n";
    print "    <forcing_subdir>  = (optional) subdirectory, under \$PROJECT_DIR/forcing, where forcing file tree starts.\n";
    print "                     Default: forcing file tree is directly under \$PROJECT_DIR/forcing.\n";
    print "\n";
    print "  -pf <prefix>\n";
    print "    <prefix>  = Prefix of forcing files.  Script will only consider forcing files with\n";
    print "                filenames beginning with <prefix>.\n";
    print "\n";
    print "  -s <start_date>\n";
    print "    <start_date>  = Start date of the simulation.  Format: YYYY-MM-DD.\n";
    print "\n";
    print "  -e <end_date>\n";
    print "    <end_date>  = End date of the simulation.  Format: YYYY-MM-DD.\n";
    print "\n";
    print "  -r <results_subdir>\n";
    print "    (optional) Specify the subdirectory, under \$PROJECT_DIR/results, where results file tree starts.\n";
    print "    <results_subdir>  = subdirectory name.\n";
    print "    Default: If forcing_subdir has been specified and results_subdir has not, then\n";
    print "    results_subdir = forcing_subdir (i.e. results file tree starts under \$PROJECT_DIR/results/\$forcing_subdir).\n";
    print "\n";
    print "  -i <init_file>\n";
    print "    (optional) Specify an initial state file.  This can be simply a file name, in which case the file\n";
    print "    is assumed to be stored under \$PROJECT_DIR/state/<state_subdir> (see the -st option),\n";
    print "    or a complete path and file name (the path is needed if you want this file to come from\n";
    print "    a different location than where the output state files will be stored).\n";
    print "    This option only works if the tag <INITIAL> is present in the model\'s input.template file.\n";
    print "    <init_file>  = Initial state file name.\n";
    print "    Default: model starts from its default initial model state.\n";
    print "\n";
    print "  -st <state_subdir>\n";
    print "    (optional) Specify a subdirectory, under \$PROJECT_DIR/state, where the state file tree should start.\n";
    print "    <state_subdir> = name of the subdirectory.\n";
    print "    Default: If results_subdir has been specified and state_subdir has not, then state_subdir is set equal to\n";
    print "    the results_subdir (i.e. state file tree starts under \$PROJECT_DIR/state/\$results_subdir).\n";
    print "    If neither results_subdir nor state_subdir have been specified, but forcing_subdir\n";
    print "    has been specified, then state_subdir = forcing_subdir\n";
    print "\n";
    print "  -uncmp\n";
    print "    (optional) If specified, results files will NOT be compressed by gathering; i.e. cells will\n";
    print "    indexed by row and column, allowing space for cells that aren\'t in the land mask (e.g.\n";
    print "    ocean cells or cells outside the catchment).\n";
    print "    Default: cells ARE compressed by gathering, i.e. they will be stored in a 1-D array and cells\n";
    print "    not in the land mask will be skipped.\n";
    print "\n";
    print "  -x <varnames>\n";
    print "    (optional) Extract some set of variables from the netcdf-format model result files and write\n";
    print "    them to  vic-style ascii files.  These will be stored in the \"/asc\" subdirectory of the results\n";
    print "    directory.\n";
    print "    <varnames>  = comma-separated list of variable names to extract.\n";
    print "    Default: If -x is NOT specified, or if the <varnames> list is blank, no variables will be extracted to ascii.\n";
    print "\n";
    print "  -mspc \"<model-specific parameters>\"\n";
    print "    (optional) Any parameters needed specifically for the model that you are running.\n";
    print "    The entire set of parameters should be enclosed in double quotes (\").\n";
    print "    Example: for SAC model, need to specify the directory where pe files are located, as:\n";
    print "      run_model.pl (blah blah) -mspc \"-pe path_to_pe_files\"\n";
    print "\n";
    print "  -l\n";
    print "    (optional) If specified, input data will be copied to a drive that is local to the node\n";
    print "    that the script is being run on; results will be written to this local drive, and then\n";
    print "    the results will be copied to the central drive when the run is finished.  This reduces\n";
    print "    network traffic on the cluster and speeds up performance dramatically.\n";
    print "\n";
  }

}
