#!/usr/bin/perl -w
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

#----------------------------------------------------------------------------------------------
# Determine tools, root, and config directories - assume this script lives in ROOT_DIR/tools/
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
# Include external modules
#----------------------------------------------------------------------------------------------
# Subroutine for reading config files
require "$TOOLS_DIR/simma_util.pl";

#----------------------------------------------------------------------------------------------
# Command-line arguments
#----------------------------------------------------------------------------------------------
$PROJECT = shift;
$MODEL = shift;

if ($MODEL ne "vic") {
  exit(0);
}

#----------------------------------------------------------------------------------------------
# Set up constants
#----------------------------------------------------------------------------------------------

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

# Substitute user-specified information into project and model variables
$var_info_project{"RESULTS_MODEL_ASC_DIR"} =~ s/<RESULTS_SUBDIR>/$var_info_project{"CURR_SUBDIR"}/g;

# Save relevant project info in variables
$ResultsModelAscDir = $var_info_project{"RESULTS_MODEL_ASC_DIR"};
# The final processed model results will be stored in the ascii dir
$ResultsModelFinalDir = $ResultsModelAscDir;
$DepotDir        = $var_info_project{"PLOT_DEPOT_DIR"};

# Check for directories; create if necessary & possible
foreach $dir ($ResultsModelFinalDir, $DepotDir) {
  if (!-d $dir) {
    die "$0: ERROR: directory $dir not found\n";
  }
}
foreach $dir ($DepotDir) {
  $status = &make_dir($dir);
}

$Archive = "curr_spinup.$PROJECT.$MODEL.tgz";

#----------------------------------------------------------------------------------------------
# END settings
#----------------------------------------------------------------------------------------------

# Archive results
if (-e "$ResultsModelFinalDir/../$Archive") {
  $cmd = "rm -f $ResultsModelFinalDir/../$Archive";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
}
$cmd = "cd $ResultsModelFinalDir/..; tar -cvzf $Archive asc; cd -";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

# Copy to depot
$cmd = "cp $ResultsModelFinalDir/../$Archive $DepotDir/";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
