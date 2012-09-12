#!/usr/bin/env perl
# Wrapper script for complete multi-model nowcast
#----------------------------------------------------------------------------------------------

use warnings;

#----------------------------------------------------------------------------------------------
# Determine tools and config directories
#----------------------------------------------------------------------------------------------
$TOOLS_DIR = "<SYSTEM_INSTALLDIR>/bin";
$CONFIG_DIR = "<SYSTEM_INSTALLDIR>/config";

#----------------------------------------------------------------------------------------------
# Include external modules
#----------------------------------------------------------------------------------------------
# Subroutine for reading config files
require "$TOOLS_DIR/simma_util.pl";

# Date computation
use Date::Calc qw(Days_in_Month Delta_Days Add_Delta_Days);

# Access to environment variables
use Env;

# Filename parsing
use File::Basename;

fileparse($0, ".pl");
($scriptname, $path, $suffix) = fileparse($0, ".pl");

#----------------------------------------------------------------------------------------------
# Command-line arguments
#----------------------------------------------------------------------------------------------
$PROJECT = shift;
# This next argument is optional
$stage = shift;

#----------------------------------------------------------------------------------------------
# Set up constants
#----------------------------------------------------------------------------------------------

# Unique identifier for this job
$JOB_ID = `date +%y%m%d-%H%M%S`;
if ($JOB_ID =~ /(\S+)/) {
  $JOB_ID = $1;
}

# !!!!!!!!!!!!!!!!! GET THIS FROM CONFIG FILE !!!!!!!!!!!!!!!!!!
# Set up netcdf access
$ENV{INC_NETCDF} = "<SYSTEM_NETCDF_INC>";
$ENV{LIB_NETCDF} = "<SYSTEM_NETCDF_LIB>";

# Configuration files
$ConfigProject = "$CONFIG_DIR/config.project.$PROJECT";

# Project configuration info
$var_info_project_ref = &read_config($ConfigProject);
%var_info_project = %{$var_info_project_ref};
$ModelList    = $var_info_project{"MODEL_LIST"};
@models = split /,/, $ModelList;
$EmailList    = $var_info_project{"EMAIL_LIST"};
@emails = split /,/, $EmailList;
$LogDir = $var_info_project{"LOGS_CURRSPIN_DIR"} . "/". $scriptname;

$LogFile = "$LogDir/log.$scriptname$suffix.$JOB_ID";

# Check for directories; create if necessary & appropriate
foreach $dir ($LogDir) {
  $status = &make_dir($dir);
}

# Stage can be defined in the config file. Precedence is:command-line, config file. 
# It is 1 if it is not specified in either of those locations
if (not defined $stage) {
  if (exists($var_info_project{"NOWCAST_STAGE"}) and 
      defined($var_info_project{"NOWCAST_STAGE"}) and 
      $var_info_project{"NOWCAST_STAGE"}) {
	$stage = $var_info_project{"NOWCAST_STAGE"};
  } else {
	$stage = 1;
  }
}

#----------------------------------------------------------------------------------------------
# END settings
#----------------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------
# Update ascii forcings
#--------------------------------------------------------------------------------
if ($stage == 1) {

  $cmd = "$TOOLS_DIR/update_forcings_asc.pl $PROJECT >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
  #`echo $cmd > $LogFile`;
  #if (system($cmd)!=0) {
  #  `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
  #  die "$0: ERROR: $cmd failed: $?\n";
  #}
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
  
  $stage++;
  
}

#--------------------------------------------------------------------------------
# Run nowcast for models that use vic-style ascii forcings
#--------------------------------------------------------------------------------
if ($stage == 2) {
  
  foreach $model (@models) {
    # Read model configuration info
    $ConfigModel = "$CONFIG_DIR/config.model.$model";
    $var_info_model_ref = &read_config($ConfigModel);
    %var_info_model = %{$var_info_model_ref};
    $ModelType = $var_info_model{"MODEL_TYPE"};
    $ForcingType = $var_info_model{"FORCING_TYPE"};
    if ($ModelType eq "real" && $ForcingType ne "nc") {
      $cmd = "$TOOLS_DIR/nowcast_model.pl $PROJECT $model >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
      #    `echo $cmd >> $LogFile`;
      #    if (system($cmd)!=0) {
      #      `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
      #      die "$0: ERROR: $cmd failed: $?\n";
      #    }
      print "$cmd\n";
      (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
    }
  }
  
  $stage++;
  
}

#--------------------------------------------------------------------------------
# Generate netcdf forcings
#--------------------------------------------------------------------------------
if ($stage == 3) {
  
  # Check whether netcdf forcings are needed
  $need_netcdf = 0;
  foreach $model (@models) {
    # Read model configuration info
    $ConfigModel = "$CONFIG_DIR/config.model.$model";
    $var_info_model_ref = &read_config($ConfigModel);
    %var_info_model = %{$var_info_model_ref};
    $ForcingType = $var_info_model{"FORCING_TYPE"};
    if ($ForcingType eq "nc") {
      $need_netcdf = 1;
    }
  }
  
  # Generate the netcdf forcings
  if ($need_netcdf) {
    $cmd = "$TOOLS_DIR/update_forcings_nc.pl $PROJECT >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
    #  `echo $cmd >> $LogFile`;
    #  if (system($cmd)!=0) {
    #    `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
    #    die "$0: ERROR: $cmd failed: $?\n";
    #  }
    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
  }
  
  $stage++;
  
}

#--------------------------------------------------------------------------------
# Run nowcast for models that use netcdf forcings
#--------------------------------------------------------------------------------
if ($stage == 4) {

  foreach $model (@models) {
    # Read model configuration info
    $ConfigModel = "$CONFIG_DIR/config.model.$model";
    $var_info_model_ref = &read_config($ConfigModel);
    %var_info_model = %{$var_info_model_ref};
    $ModelType = $var_info_model{"MODEL_TYPE"};
    $ForcingType = $var_info_model{"FORCING_TYPE"};
    if ($ModelType eq "real" && $ForcingType eq "nc") {
      $cmd = "$TOOLS_DIR/nowcast_model.pl $PROJECT $model >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
      #    `echo $cmd >> $LogFile`;
      #    if (system($cmd)!=0) {
      #      `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
      #      die "$0: ERROR: $cmd failed: $?\n";
      #    }
      print "$cmd\n";
      (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
    }
  }
  
  $stage++;
  
}


#--------------------------------------------------------------------------------
# Run nowcast for multi-model ensemble
#--------------------------------------------------------------------------------
if ($stage == 5) {
  
  foreach $model (@models) {
    # Read model configuration info
    $ConfigModel = "$CONFIG_DIR/config.model.$model";
    $var_info_model_ref = &read_config($ConfigModel);
    %var_info_model = %{$var_info_model_ref};
    $ModelType = $var_info_model{"MODEL_TYPE"};
    if ($ModelType eq "ensemble") {
      $cmd = "$TOOLS_DIR/nowcast_model.pl $PROJECT $model >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
      #    `echo $cmd >> $LogFile`;
      #    if (system($cmd)!=0) {
      #      `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
      #      die "$0: ERROR: $cmd failed: $?\n";
      #    }
      print "$cmd\n";
      (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
    }
  }

  $stage++;

}


#--------------------------------------------------------------------------------
# Publish plots to web site
#--------------------------------------------------------------------------------
if ($stage == 6) {

  $cmd = "$TOOLS_DIR/publish_figs.pl $PROJECT";
  #`echo $cmd >> $LogFile`;
  #if (system($cmd)!=0) {
  #  `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
  #  die "$0: ERROR: $cmd failed: $?\n";
  #}
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

  $stage++;

}


#--------------------------------------------------------------------------------
# Announce completion of nowcast
#--------------------------------------------------------------------------------
### This part is not active because emails are sent out through the qsub
$subject = "\"[USWIDE] Nowcast $PROJECT complete\"";
$addresses = join " ", @emails;
$cmd = "echo OK | /bin/mail $addresses -s $subject";
#`echo $cmd >> $LogFile`;
#if (system($cmd)!=0) {
#  `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
#  die "$0: ERROR: $cmd failed: $?\n";
#}
####print "$cmd\n";
###(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";


# Clean up tmp files
`rm -f $LogFile.tmp`;
