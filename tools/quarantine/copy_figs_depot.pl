#!/usr/bin/perl -w
# copy_figs.pl: Script to copy model results plots to web site

# 2008-05-22 Generalized for multimodel sw monitor.	TJB
# $Id: $
#-------------------------------------------------------------------------------

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
# Include external modules
#----------------------------------------------------------------------------------------------
# Subroutine for reading config files
require "$TOOLS_DIR/simma_util.pl";

#-------------------------------------------------------------------------------
# Parse the command line
#-------------------------------------------------------------------------------

$PROJECT = shift; # project name, e.g. conus mexico
$MODEL = shift; # model name, e.g. vic noah sac clm multimodel all
$yr = shift;
$mon = shift;
$day = shift;

#----------------------------------------------------------------------------------------------
# Set up constants
#----------------------------------------------------------------------------------------------

# Derived variables
$MODEL_UC = $MODEL;
$MODEL_UC =~ tr/a-z/A-Z/;
$PROJECT_UC = $PROJECT;
$PROJECT =~ tr/A-Z/a-z/;
$PROJECT_UC =~ tr/a-z/A-Z/;
$datenow = sprintf("%04d%02d%02d", $yr, $mon, $day);

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

# Save relevant project info in variables
$XYZZDir         = $var_info_project{"XYZZ_DIR"} . "/$datenow";
$PlotDir         = $var_info_project{"PLOT_DIR"} . "/$datenow";
$DepotDir        = $var_info_project{"PLOT_DEPOT_DIR"};

#----------------------------------------------------------------------------------------------
# END settings
#----------------------------------------------------------------------------------------------

# Check for directories; create if necessary & possible
foreach $dir ($XYZZDir, $PlotDir, $DepotDir) {
  if (!-d $dir) {
    die "$0: ERROR: directory $dir not found\n";
  }
}
foreach $dir ($DepotDir) {
  $status = &make_dir($dir);
}

# Copy stats
if ($MODEL eq "all") {
  $cmd = "cp $XYZZDir/* $DepotDir/";
}
else {
  $cmd = "cp $XYZZDir/*$MODEL* $DepotDir/";
}
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

# Copy plots
if ($MODEL eq "all") {
  $cmd = "cp $PlotDir/* $DepotDir/";
}
else {
  $cmd = "cp $PlotDir/*$MODEL* $DepotDir/";
}
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

