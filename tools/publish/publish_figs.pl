#!/usr/bin/env perl
# copy_figs.pl: Script to copy model results plots to web site

use warnings;

# 2008-05-22 Generalized for multimodel sw monitor.	TJB
# $Id: $
#-------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------
# Determine tools, root, and config directories - assume this script lives in TOOLS_DIR/
#----------------------------------------------------------------------------------------------
$TOOLS_DIR = "<SYSTEM_INSTALLDIR>/bin";
$CONFIG_DIR = "<SYSTEM_INSTALLDIR>/config";

#----------------------------------------------------------------------------------------------
# Include external modules
#----------------------------------------------------------------------------------------------
# Subroutine for reading config files
require "$TOOLS_DIR/simma_util.pl";

#-------------------------------------------------------------------------------
# Parse the command line
#-------------------------------------------------------------------------------

$PROJECT = shift; # project name, e.g. conus mexico

#----------------------------------------------------------------------------------------------
# Set up constants
#----------------------------------------------------------------------------------------------

# Read project configuration info
$ConfigProject = "$CONFIG_DIR/config.project.$PROJECT";
$var_info_project_ref = &read_config($ConfigProject);
%var_info_project = %{$var_info_project_ref};

# Save relevant project info in variables
$DepotDir        = $var_info_project{"PLOT_DEPOT_DIR"};
$WebPubDir       = $var_info_project{"WEB_PUB_DIR"} . "/$PROJECT";

#----------------------------------------------------------------------------------------------
# END settings
#----------------------------------------------------------------------------------------------

# Check for directories; create if necessary & possible
foreach $dir ($DepotDir, $WebPubDir) {
  if (!-d $dir) {
    die "$0: ERROR: directory $dir not found\n";
  }
}

# Copy plots
$cmd = "cp $DepotDir/* $WebPubDir/";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

