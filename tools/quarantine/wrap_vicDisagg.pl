#!/usr/bin/perl
# SGE directives
#$ -cwd
#$ -j y
#$ -S /usr/bin/perl
#
# wrap_vicDisagg.pl: Script to run vic forcing disaggregation within SIMMA framework
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

# Root Directory - Edit this to reflect location of your SIMMA installation
$ROOT_DIR = "/raid8/forecast/sw_monitor";

# Utility subroutines
require "$ROOT_DIR/tools/simma_util.pl";

# Unique identifier for this job
$JOB_ID = `date +%y%m%d-%H%M%S`;
if ($JOB_ID =~ /(\S+)/) {
  $JOB_ID = $1;
}

# Default values
$forcing_subdir = "";
$MODEL_NAME = "vicDisagg";
$MODEL_EXE_NAME = "vicDisagg";
$local_storage = 0;


#-------------------------------------------------------------------------------
# Parse the command line
#-------------------------------------------------------------------------------

# Hash used in GetOptions function
# format: option => \$variable_to_set
%options_hash = (
  h   => \$help,
  p   => \$project,
  f   => \$forcing_subdir,
  pf  => \$prefix,
  s   => \$start_date,
  e   => \$end_date,
  l   => \$local_storage,
);

# This parses the command-line arguments and sets values for the variables in %option_hash
$status = &GetOptions(\%options_hash,"h","p=s","f=s","pf=s","s=s","e=s","l");

#-------------------------------------------------------------------------------
# Validate the command-line arguments
#-------------------------------------------------------------------------------

# Help option
if ($help) {
  usage("full");
  exit(0);
}

# Validate required arguments
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

#-------------------------------------------------------------------------------
# Get configuration information
#-------------------------------------------------------------------------------

$TOOLS_DIR = "$ROOT_DIR/tools";
$CONFIG_DIR = "$ROOT_DIR/config";
$CONFIG_PROJECT = "$CONFIG_DIR/config.project.$project";
$MODEL_EXE_DIR = $TOOLS_DIR;

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
$FORCING_DIR = "$PROJECT_DIR/forcing/$forcing_subdir/asc_vicinp";
$FORCING_METADATA = "$FORCING_DIR/metadata.txt";
open (FORCING_METADATA, $FORCING_METADATA) or die "$0: ERROR: cannot open forcing metadata file $FORCING_METADATA\n";
@forcing_metadata = <FORCING_METADATA>;
close (FORCING_METADATA);

# Output configuration info
$RESULTS_DIR = "$PROJECT_DIR/forcing/$forcing_subdir/asc_disagg";
$results_dir = $RESULTS_DIR;

# Check for directories; create if necessary
if (!-d $FORCING_DIR) {
  die "$0: ERROR: forcing directory $FORCING_DIR not found\n";
}
foreach $dir ($RESULTS_DIR) {
  $status = &make_dir($dir);
}

# Use local directories if specified
if ($local_storage) {
  $LOCAL_RESULTS_DIR = "$LOCAL_PROJECT_DIR/results/$forcing_subdir/asc_disagg";
  $results_dir = $LOCAL_RESULTS_DIR;
  foreach $dir ($LOCAL_RESULTS_DIR) {
    $status = &make_dir($dir);
  }
}

# Log files
$LOGS_DIR = "$PROJECT_DIR/logs/$forcing_subdir/$MODEL_NAME";
$status = &make_dir($LOGS_DIR);
$LOGFILE = "$LOGS_DIR/log.wrap_vicDisagg.pl.$JOB_ID";


#-------------------------------------------------------------------------------
# Model execution
#-------------------------------------------------------------------------------

# Create input file
$CONTROL_DIR = "$PROJECT_DIR/control/$forcing_subdir/$MODEL_NAME";
$status = &make_dir($CONTROL_DIR);
$controlfile = "$CONTROL_DIR/inp.$JOB_ID";
@new_forcing_metadata = ();
foreach (@forcing_metadata) {
  s/<FORCING_DIR>/$FORCING_DIR/g;
  s/<FORCE_START_YEAR>/$start_year/g;
  s/<FORCE_START_MONTH>/$start_month/g;
  s/<FORCE_START_DAY>/$start_day/g;
  push @new_forcing_metadata, $_;
}
open (CONTROLFILE, ">$controlfile") or die "$0: ERROR: cannot open controlfile $controlfile\n";
foreach (@params_template) {
  if (/<FORCING_METADATA>/) {
    print CONTROLFILE @new_forcing_metadata;
  }
  else {
    s/<STARTYEAR>/$start_year/g;
    s/<STARTMONTH>/$start_month/g;
    s/<STARTDAY>/$start_day/g;
    s/<STARTHOUR>/0/g;
    s/<ENDYEAR>/$end_year/g;
    s/<ENDMONTH>/$end_month/g;
    s/<ENDDAY>/$end_day/g;
    s/<PARAMS_DIR>/$PARAMS_DIR/g;
    s/<RESULTS_DIR>/$results_dir/g;
    print CONTROLFILE $_;
  }
}
close(CONTROLFILE);

# Run the model
$cmd = "$MODEL_EXE_DIR/$MODEL_EXE_NAME -g $controlfile >& $LOGFILE";
(system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";


#-------------------------------------------------------------------------------
# Copy results from local directories to absolute directories, if specified
#-------------------------------------------------------------------------------
if ($local_storage) {
  $cmd = "cp $LOCAL_RESULTS_DIR/* $RESULTS_DIR/";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
  $cmd = "rm -rf $LOCAL_RESULTS_DIR";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
}

exit(0);

#-------------------------------------------------------------------------------
# Usage
#-------------------------------------------------------------------------------

sub usage() {

  print "\n";
  print "$0: Script to run vic forcing disaggregation within the SIMMA framework\n";
  print "\n";
  print "usage:\n";
  print "  $0 [-h] -p <project> [-f <forcing_subdir>] -pf <prefix> -s <start_date> -e <end_date> [-l]\n";
  print "\n";
  if ($_[0] eq "full") {
    print "Given vic-style ascii forcings, runs vicDisagg (vic compiled with\n";
    print "OUTPUT_FORCE set to TRUE) over the specified simulation period\n";
    print "and produces disaggregated forcing files.\n";
    print "\n";
    print "Arguments:\n";
    print "\n";
    print "  -h\n";
    print "    prints this usage message\n";
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
    print "  -l\n";
    print "    (optional) If specified, input data will be copied to a drive that is local to the node\n";
    print "    that the script is being run on; results will be written to this local drive, and then\n";
    print "    the results will be copied to the central drive when the run is finished.  This reduces\n";
    print "    network traffic on the cluster and speeds up performance dramatically.\n";
    print "\n";
  }

}
