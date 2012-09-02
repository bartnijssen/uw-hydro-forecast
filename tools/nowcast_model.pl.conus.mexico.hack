#!/usr/bin/perl -w
# Wrapper script that makes a nowcast for a given model on a given day.  Does the following:
# 1. runs the model
# 2. converts the output to percentiles of model climatology
# 3. makes plots
#
#----------------------------------------------------------------------------------------------

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

# Date arithmetic
use Date::Calc qw(Days_in_Month Delta_Days Add_Delta_Days);

#----------------------------------------------------------------------------------------------
# Command-line arguments
#----------------------------------------------------------------------------------------------
$PROJECT = shift;
$MODEL = shift;
# These next arguments are optional - can be omitted
$skip_stats = shift; # 1 = exit after running model, skipping stats and plots; 0 (or blank) = do everything - run model, stats, plots, etc.
#$currspin_start_date_override = shift;
$fcast_date_override = shift;

#----------------------------------------------------------------------------------------------
# Set up constants
#----------------------------------------------------------------------------------------------

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

# Save relevant info
$StateNearRTModelDir = $var_info_project{"STATE_MODEL_DIR"};
$StateNearRTModelDir =~ s/<STATE_SUBDIR>/spinup_nearRT/;
$CurrspinStartDateFile = $var_info_project{"FORCING_CURRSPIN_START_DATE_FILE"};
$CurrspinEndDateFile   = $var_info_project{"FORCING_CURRSPIN_END_DATE_FILE"};
$LogDir = $var_info_project{"LOGS_MODEL_DIR"};
$LogDir =~ s/<LOGS_SUBDIR>/curr_spinup/;
$VarList = $var_info_model{"PLOT_VARS"};

$LogFile = "$LogDir/log.nowcast_model.pl.$JOB_ID";

# Check for directories; create if necessary & appropriate
foreach $dir ($LogDir) {
  $status = &make_dir($dir);
}

#----------------------------------------------------------------------------------------------
# Read dates from files
#----------------------------------------------------------------------------------------------

# Assume start date = date of beginning of current spinup forcings
open (FILE, $CurrspinStartDateFile) or die "$0: ERROR: cannot open file $CurrspinStartDateFile\n";
foreach (<FILE>) {
  if (/^(\d+)\s+(\d+)\s+(\d+)\s+/) {
    ($Syr,$Smon,$Sday) = ($1,$2,$3);
  }
}
close(FILE);

# Assume forecast date = date of end of current spinup forcings
open (FILE, $CurrspinEndDateFile) or die "$0: ERROR: cannot open file $CurrspinEndDateFile\n";
foreach (<FILE>) {
  if (/^(\d+)\s+(\d+)\s+(\d+)\s+/) {
    ($Fyr,$Fmon,$Fday) = ($1,$2,$3);
  }
}
close(FILE);

# Optional overriding of dates in files
#if ($currspin_start_date_override) {
#  ($Syr,$Smon,$Sday) = split /-/, $currspin_start_date_override;
#}
if ($fcast_date_override) {
  ($Fyr,$Fmon,$Fday) = split /-/, $fcast_date_override;
}

# Date strings
$start_date = sprintf "%04d-%02d-%02d", $Syr, $Smon, $Sday;
$fcast_date = sprintf "%04d-%02d-%02d", $Fyr, $Fmon, $Fday;

#----------------------------------------------------------------------------------------------
# END settings
#----------------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------
# Run model
#----------------------------------------------------------------------------------------------
# Only run models that can be run (i.e. don't attempt to run multimodel)
if ($var_info_model{"MODEL_SRC_DIR"}) {

  # Build name of last spinup state file
  ($state_year,$state_month,$state_day) = Add_Delta_Days($Syr,$Smon,$Sday,-1);
  $state_str = sprintf "%04d%02d%02d", $state_year, $state_month, $state_day;
  opendir(STATE_DIR, $StateNearRTModelDir) or die "$0: ERROR: cannot open spinup state file directory $StateNearRTModelDir for reading\n";
  @statefilelist = grep /$state_str/, readdir(STATE_DIR);
  closedir(STATE_DIR);
  if (@statefilelist) {
    $init_state_file = $statefilelist[0];
    chomp $init_state_file;
    $init_state_file = "$StateNearRTModelDir/$init_state_file";
  }
  else {
    $init_state_file = "NULL";
  }

  # Run Model
  $cmd = "$TOOLS_DIR/run_model.pl -m $MODEL -p $PROJECT -f curr_spinup -s $start_date -e $fcast_date -i $init_state_file >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
#  `echo $cmd > $LogFile`;
#  if (system($cmd)!=0) {
#    `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
#    die "$0: ERROR: $cmd failed: $?\n";
#  }

  # Optionally exit now
  if ($skip_stats) {
    exit(0);
  }

  # Archive results and post to web site
  $cmd = "$TOOLS_DIR/archive_currspin.pl $MODEL $PROJECT >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
#  `echo $cmd > $LogFile`;
#  if (system($cmd)!=0) {
#    `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
#    die "$0: ERROR: $cmd failed: $?\n";
#  }


}
else {

  # Optionally exit now
  if ($skip_stats) {
    exit(0);
  }

}



#----------------------------------------------------------------------------------------------
# Get stats
#----------------------------------------------------------------------------------------------
# Compute percentiles of model results (but not runoff)
$cmd = "$TOOLS_DIR/get_stats.pl $MODEL $PROJECT $Fyr $Fmon $Fday >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
#`echo $cmd >> $LogFile`;
#if (system($cmd)!=0) {
#  `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
#  die "$0: ERROR: $cmd failed: $?\n";
#}

# Compute percentiles of model runoff - not all models
if (grep /ro/, $VarList) {
  $cmd = "$TOOLS_DIR/calc.cum_ro_qnts.pl $MODEL $PROJECT $Fyr $Fmon $Fday >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
#  `echo $cmd >> $LogFile`;
#  if (system($cmd)!=0) {
#    `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
#    die "$0: ERROR: $cmd failed: $?\n";
#  }
}




#----------------------------------------------------------------------------------------------
# Combine Stats files of CONUS and MEXICO -- Asummes that CONUS run finishes after MEXICO run 
#----------------------------------------------------------------------------------------------
if ($PROJECT eq "conus") {

  $cmd =  "$TOOLS_DIR/merge_spatial_conus_mexico.scr $ROOT_DIR $MODEL $Fyr $Fmon $Fday >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
#  `echo $cmd >> $LogFile`;
#  if (system($cmd)!=0) {
#    `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
#    die "$0: ERROR: $cmd failed: $?\n";
#  }

##### Make plots for CONUS.MEXICO
  $cmd = "$TOOLS_DIR/plot_qnts.pl conus.mexico $MODEL $Fyr $Fmon $Fday >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
#  `echo $cmd >> $LogFile`;
#  if (system($cmd)!=0) {
#    `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
#    die "$0: ERROR: $cmd failed: $?\n";
#  }


  ## Copying conus.mexico plots to depot
  $cmd = "$TOOLS_DIR/copy_figs_depot.pl conus.mexico $MODEL $Fyr $Fmon $Fday >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
#  `echo $cmd >> $LogFile`;
#  if (system($cmd)!=0) {
#    `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
#    die "$0: ERROR: $cmd failed: $?\n";
#  }


  ## Publishing conus.mexico plots
  $cmd = "$TOOLS_DIR/publish_figs.pl conus.mexico";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
#  `echo $cmd >> $LogFile`;
#  if (system($cmd)!=0) {
#    `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
#    die "$0: ERROR: $cmd failed: $?\n";
#  }

}


#----------------------------------------------------------------------------------------------
# Make plots
#----------------------------------------------------------------------------------------------
$cmd = "$TOOLS_DIR/plot_qnts.pl $PROJECT $MODEL $Fyr $Fmon $Fday >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
#`echo $cmd >> $LogFile`;
#if (system($cmd)!=0) {
#  `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
#  die "$0: ERROR: $cmd failed: $?\n";
#}


#----------------------------------------------------------------------------------------------
# Copy plots to "depot"
#----------------------------------------------------------------------------------------------
$cmd = "$TOOLS_DIR/copy_figs_depot.pl $PROJECT $MODEL $Fyr $Fmon $Fday >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
#`echo $cmd >> $LogFile`;
#if (system($cmd)!=0) {
#  `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
#  die "$0: ERROR: $cmd failed: $?\n";
#}

# Clean up tmp files
`rm -f $LogFile.tmp`;

