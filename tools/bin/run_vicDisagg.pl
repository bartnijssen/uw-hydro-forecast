#!/usr/bin/env perl
use warnings;
# Script to run vic forcing disaggregation
#
# Author: Ted Bohn
# $Id: $
#-------------------------------------------------------------------------------
use POSIX qw(strftime);

# Command-line arguments
$TOOLS_DIR = shift;
$PARAMS_DIR = shift;
$CONTROL_DIR = shift;
$InDir = shift;
$OutDir = shift;
$start_date = shift;
$end_date = shift;
$forc_start_date = shift;

# Utility subroutines
require "$TOOLS_DIR/simma_util.pl";

# Parse & validate start/end dates
if ($start_date =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/) {
  ($start_year,$start_month,$start_day) = ($1,$2,$3);
}
else {
  die "$0: ERROR: start date must have format YYYY-MM-DD.\n";
}
if ($end_date =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/) {
  ($end_year,$end_month,$end_day) = ($1,$2,$3);
}
else {
  die "$0: ERROR: end date must have format YYYY-MM-DD.\n";
}
if ($forc_start_date =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/) {
  ($forc_start_year,$forc_start_month,$forc_start_day) = ($1,$2,$3);
}
else {
  die "$0: ERROR: forcing start date must have format YYYY-MM-DD.\n";
}

# Model parameters
$PARAMS_TEMPLATE = "$PARAMS_DIR/input.template";
open (PARAMS_TEMPLATE, $PARAMS_TEMPLATE)
  or die "$0: ERROR: cannot open parameter config file $PARAMS_TEMPLATE\n";
@params_template = <PARAMS_TEMPLATE>;
close (PARAMS_TEMPLATE);

# Check for directories; create if necessary
if (!-d $InDir) {
  die "$0: ERROR: forcing directory $InDir not found\n";
}
foreach $dir ($OutDir) {
  $status = &make_dir($dir);
}

# Unique identifier for this job
$JOB_ID = strftime "%y%m%d-%H%M%S", localtime;

#-------------------------------------------------------------------------------
# Model execution
#-------------------------------------------------------------------------------

# Create input file
$status = &make_dir($CONTROL_DIR);
$controlfile = "$CONTROL_DIR/inp.$JOB_ID";
open (CONTROLFILE, ">$controlfile") or die "$0: ERROR: cannot open controlfile $controlfile\n";
foreach (@params_template) {
  s/<STARTYEAR>/$start_year/g;
  s/<STARTMONTH>/$start_month/g;
  s/<STARTDAY>/$start_day/g;
  s/<STARTHOUR>/0/g;
  s/<ENDYEAR>/$end_year/g;
  s/<ENDMONTH>/$end_month/g;
  s/<ENDDAY>/$end_day/g;
  s/<FORCING_DIR>/$InDir/g;
  s/<FORCE_START_YEAR>/$forc_start_year/g;
  s/<FORCE_START_MONTH>/$forc_start_month/g;
  s/<FORCE_START_DAY>/$forc_start_day/g;
  s/<PARAMS_DIR>/$PARAMS_DIR/g;
  s/<RESULTS_DIR>/$OutDir/g;
  print CONTROLFILE $_;
}
close(CONTROLFILE);

# Run the model
$cmd = "$TOOLS_DIR/vicDisagg -g $controlfile";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";
