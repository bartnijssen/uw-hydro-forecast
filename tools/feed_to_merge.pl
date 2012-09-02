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
$modellist = shift; # comma-separated list of model names, or "all" to process all models' files
$yr = shift;
$mon = shift;
$day = shift;

#----------------------------------------------------------------------------------------------
# Set up constants
#----------------------------------------------------------------------------------------------

# Read project configuration info
$ConfigProject = "$CONFIG_DIR/config.project.$PROJECT";
$var_info_project_ref = &read_config($ConfigProject);
%var_info_project = %{$var_info_project_ref};

# Save relevant project info in variables
$datenow = sprintf("%04d%02d%02d", $yr, $mon, $day);
$XYZZDir         = $var_info_project{"XYZZ_DIR"} . "/$datenow";
$DepotDir        = $var_info_project{"MERGE_DEPOT_DIR"};

# Parse model list
@models = split /,/, $modellist;
$all=0;
foreach $model (@models) {
  if ($model =~ /^all$/i) {
    $all=1;
  }
}

#----------------------------------------------------------------------------------------------
# END settings
#----------------------------------------------------------------------------------------------

# Check for directories; create if necessary & possible
foreach $dir ($XYZZDir, $DepotDir) {
  if (!-d $dir) {
    die "$0: ERROR: directory $dir not found\n";
  }
}

# Copy contents
if ($all) {
  $cmd = "cp $XYZZDir/* $DepotDir/";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
}
else {
  foreach $model (@models) {
    $cmd = "cp $XYZZDir/*$model* $DepotDir/";
    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
  }

}
# Copy SPI/SRI indxes
$NDXES_DIR	    = $var_info_project{"NDXES_DIR"};
$NDXES_DIR	    = "$NDXES_DIR/xyzz";
##$cmd = "cp $NDXES_DIR/spi_sri.$datenow.xyzz $DepotDir/spi_sri.xyzz";
##print "$cmd\n";
##(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

