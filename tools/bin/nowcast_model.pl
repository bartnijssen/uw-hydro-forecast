#!/usr/bin/env perl
use warnings;
# Wrapper script that makes a nowcast for a given model on a given day.  Does the following:
# 1. runs the model
# 2. converts the output to percentiles of model climatology
# 3. makes plots
#
#----------------------------------------------------------------------------------------------

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

# Date arithmetic
use Date::Calc qw(Days_in_Month Delta_Days Add_Delta_Days);

# Filename parsing
use File::Basename;

($scriptname, $path, $suffix) = fileparse($0, ".pl");

#----------------------------------------------------------------------------------------------
# Command-line arguments
#----------------------------------------------------------------------------------------------
$PROJECT = shift;
$MODEL = shift;
# These next arguments are optional - can be omitted
$StepList = shift; # Either a comma-separated list of steps in the process to execute, or "all" to indicate all steps
$currspin_start_date_override = shift;
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
$ProjectType = $var_info_project{"PROJECT_TYPE"};
if ($ProjectType =~ /merge/i) {
  $SubProjectList = $var_info_project{"PROJECT_MERGE_LIST"};
  @SubProjects = split /,/, $SubProjectList;
}
$StateNearRTModelDir = $var_info_project{"STATE_MODEL_DIR"};
$StateNearRTModelDir =~ s/<STATE_SUBDIR>/spinup_nearRT/;
$CurrspinStartDateFile = $var_info_project{"FORCING_CURRSPIN_START_DATE_FILE"};
$CurrspinEndDateFile   = $var_info_project{"FORCING_CURRSPIN_END_DATE_FILE"};
$LogDir = $var_info_project{"LOGS_MODEL_DIR"};
$LogDir =~ s/<LOGS_SUBDIR>/curr_spinup/;
$VarList = $var_info_model{"PLOT_VARS"};

$LogFile = "$LogDir/log.$scriptname$suffix.$JOB_ID";

# Get info for each subproject in the list
for ($proj_idx=0; $proj_idx<@SubProjects; $proj_idx++) {

  # Read subproject config file
  $ConfigProject = "$CONFIG_DIR/config.project.$SubProjects[$proj_idx]";
  $var_info_project_ref = &read_config($ConfigProject);
  %var_info_project = %{$var_info_project_ref};

  # Substitute model-specific information into project variables
  foreach $key_proj (keys(%var_info_project)) {
    foreach $key_model (keys(%var_info_model)) {
      $var_info_project{$key_proj} =~ s/<$key_model>/$var_info_model{$key_model}/g;
    }
  }

  # Save relevant info
  $CurrspinEndDateFileSub[$proj_idx]   = $var_info_project{"FORCING_CURRSPIN_END_DATE_FILE"};

}

# Check for directories; create if necessary & appropriate
foreach $dir ($LogDir) {
  $status = &make_dir($dir);
}

# Parse the step list
if (!$StepList) {
  $StepList = "all";
}
@steps = split /,/, $StepList;
$do_model = 0;
$do_archive = 0;
$do_stats = 0;
$do_plots = 0;
$do_depot = 0;
foreach $step (@steps) {
  if ($step eq "all" || $step eq "model") {
    $do_model = 1;
  }
  if ($step eq "all" || $step eq "archive") {
    $do_archive = 1;
  }
  if ($step eq "all" || $step eq "stats") {
    $do_stats = 1;
  }
  if ($step eq "all" || $step eq "plots") {
    $do_plots = 1;
  }
  if ($step eq "all" || $step eq "depot") {
    $do_depot = 1;
  }
}
if ($ProjectType =~ /merge/i) {
  $do_model = $do_archive = 0;
}
else
{$do_depot = $do_plots = 0;
}


#----------------------------------------------------------------------------------------------
# Read dates from files
#----------------------------------------------------------------------------------------------

if ($ProjectType !~ /merge/i) {

  # Assume start date = date of beginning of current spinup forcings
  open (FILE, $CurrspinStartDateFile) or die "$0: ERROR: cannot open file $CurrspinStartDateFile\n";
  foreach (<FILE>) {
    if (/^(\d+)\s+(\d+)\s+(\d+)\s+/) {
      ($Syr,$Smon,$Sday) = ($1,$2,$3);
    }
  }
  close(FILE);

  # Assume nowcast date = date of end of current spinup forcings
  open (FILE, $CurrspinEndDateFile) or die "$0: ERROR: cannot open file $CurrspinEndDateFile\n";
  foreach (<FILE>) {
    if (/^(\d+)\s+(\d+)\s+(\d+)\s+/) {
      ($Fyr,$Fmon,$Fday) = ($1,$2,$3);
    }
  }
  close(FILE);

}
else {

  # Nowcast date is the date of the most recent nowcast among all the sub-projects
  $first = 1;
  for ($proj_idx=0; $proj_idx<@SubProjects; $proj_idx++) {
    open (FILE, $CurrspinEndDateFileSub[$proj_idx]) or die "$0: ERROR: cannot open file $CurrspinEndDateFileSub[$proj_idx]\n";
    foreach (<FILE>) {
      if (/^(\d+)\s+(\d+)\s+(\d+)\s+/) {
        ($Fyr,$Fmon,$Fday) = ($1,$2,$3);
      }
    }
    close(FILE);
    if ($first) {
      $datenow = sprintf "%04d%02d%02d", $Fyr, $Fmon, $Fday;
      $first = 0;
    }
    else {
      $datetmp = sprintf "%04d%02d%02d", $Fyr, $Fmon, $Fday;
      if ($datetmp > $datenow) {
        $datenow = $datetmp;
      }
    }
  }
  if ($datenow =~ /(\d\d\d\d)(\d\d)(\d\d)/) {
    ($Fyr,$Fmon,$Fday) = ($1,$2,$3);
  }

}

# Optional overriding of dates in files
if ($currspin_start_date_override) {
  ($Syr,$Smon,$Sday) = split /-/, $currspin_start_date_override;
}
if ($fcast_date_override) {
  ($Fyr,$Fmon,$Fday) = split /-/, $fcast_date_override;
}

# Date strings
$start_date = sprintf "%04d-%02d-%02d", $Syr, $Smon, $Sday;
$fcast_date = sprintf "%04d-%02d-%02d", $Fyr, $Fmon, $Fday;

#$start_date = sprintf "%04d-%d-%d", $Syr, $Smon, $Sday;
#$fcast_date = sprintf "%04d-%d-%d", $Fyr, $Fmon, $Fday;

#----------------------------------------------------------------------------------------------
# END settings
#----------------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------
# Run model
#----------------------------------------------------------------------------------------------

# Only run real models (i.e. don't attempt to run multimodel)
if ($var_info_model{"MODEL_TYPE"} eq "real") {

  if ($do_model) {

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
#    $cmd = "$TOOLS_DIR/run_model.pl -m $MODEL -p $PROJECT -f curr_spinup -s $start_date -e $fcast_date -i $init_state_file >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
#    print "$cmd\n";
#    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
#    `echo $cmd > $LogFile`;
#    if (system($cmd)!=0) {
#      `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
#      die "$0: ERROR: $cmd failed: $?\n";
#    }
    $cmd = "$TOOLS_DIR/run_model.pl -m $MODEL -p $PROJECT -f curr_spinup -s $start_date -e $fcast_date -i $init_state_file >& $LogFile.tmp";
    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
    $cmd = "cat $LogFile.tmp >> $LogFile";
    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
    $cmd = "rm -f $LogFile.tmp";
    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

  }

  if ($do_archive) {

    # Archive results and post to web site
#    $cmd = "$TOOLS_DIR/archive_currspin.pl $MODEL $PROJECT >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
#    print "$cmd\n";
#    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
#    `echo $cmd > $LogFile`;
#    if (system($cmd)!=0) {
#      `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
#      die "$0: ERROR: $cmd failed: $?\n";
#    }
    $cmd = "$TOOLS_DIR/archive_currspin.pl $PROJECT $MODEL >& $LogFile.tmp";
    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
    $cmd = "cat $LogFile.tmp >> $LogFile";
    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
    $cmd = "rm -f $LogFile.tmp";
    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

  }


}



#----------------------------------------------------------------------------------------------
# Get stats
#----------------------------------------------------------------------------------------------
if ($do_stats) {

  if ($ProjectType =~ /merge/i) {

    # Stats for this project will consist of merged stats files from other "sub-projects".
#    $cmd =  "$TOOLS_DIR/merge_project_stats.pl $PROJECT $MODEL $Fyr $Fmon $Fday >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
#    print "$cmd\n";
#    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
#    `echo $cmd >> $LogFile`;
#    if (system($cmd)!=0) {
#      `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
#      die "$0: ERROR: $cmd failed: $?\n";
#    }
    $cmd =  "$TOOLS_DIR/merge_project_stats.pl $PROJECT $MODEL $Fyr $Fmon $Fday >& $LogFile.tmp";
    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
    $cmd = "cat $LogFile.tmp >> $LogFile";
    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
    $cmd = "rm -f $LogFile.tmp";
    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

  }
  else {

    # Compute percentiles of model results (but not runoff)
#    $cmd = "$TOOLS_DIR/get_stats.pl.bak $MODEL $PROJECT $Fyr $Fmon $Fday >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
#    print "$cmd\n";
#    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
#    `echo $cmd >> $LogFile`;
#    if (system($cmd)!=0) {
#      `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
#      die "$0: ERROR: $cmd failed: $?\n";
#    }
    $cmd = "$TOOLS_DIR/get_stats.pl.bak $MODEL $PROJECT $Fyr $Fmon $Fday >& $LogFile.tmp";
    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
    $cmd = "cat $LogFile.tmp >> $LogFile";
    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
    $cmd = "rm -f $LogFile.tmp";
    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

    # Compute percentiles of model runoff - not all models
    if (grep /ro/, $VarList) {
#      $cmd = "$TOOLS_DIR/calc.cum_ro_qnts.pl $MODEL $PROJECT $Fyr $Fmon $Fday >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
#      print "$cmd\n";
#      (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
#      `echo $cmd >> $LogFile`;
#      if (system($cmd)!=0) {
#        `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
#        die "$0: ERROR: $cmd failed: $?\n";
#      }
      $cmd = "$TOOLS_DIR/calc.cum_ro_qnts.pl $MODEL $PROJECT $Fyr $Fmon $Fday >& $LogFile.tmp";
      print "$cmd\n";
      (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
      $cmd = "cat $LogFile.tmp >> $LogFile";
      print "$cmd\n";
      (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
      $cmd = "rm -f $LogFile.tmp";
      print "$cmd\n";
      (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
    }

  }

}


#----------------------------------------------------------------------------------------------
# Make plots
#----------------------------------------------------------------------------------------------
if ($do_plots) {

#  $cmd = "$TOOLS_DIR/publish/plot_qnts.pl $PROJECT $MODEL $Fyr $Fmon $Fday >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
#  print "$cmd\n";
#  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
#  `echo $cmd >> $LogFile`;
#  if (system($cmd)!=0) {
#    `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
#    die "$0: ERROR: $cmd failed: $?\n";
#  }
  $cmd = "$TOOLS_DIR/plot_qnts.pl $PROJECT $MODEL $Fyr $Fmon $Fday >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
  $cmd = "cat $LogFile.tmp >> $LogFile";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
  $cmd = "rm -f $LogFile.tmp";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

}



#----------------------------------------------------------------------------------------------
# Copy plots to "depot"
#----------------------------------------------------------------------------------------------
if ($do_depot) {

#  $cmd = "$TOOLS_DIR/publish/copy_figs_depot.pl $PROJECT $MODEL $Fyr $Fmon $Fday >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
#  print "$cmd\n";
#  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
#  `echo $cmd >> $LogFile`;
#  if (system($cmd)!=0) {
#    `echo $0: ERROR: $cmd failed: $? >> $LogFile`;
#    die "$0: ERROR: $cmd failed: $?\n";
#  }
  $cmd = "$TOOLS_DIR/copy_figs_depot.pl $PROJECT $MODEL $Fyr $Fmon $Fday >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
  $cmd = "cat $LogFile.tmp >> $LogFile";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
  $cmd = "rm -f $LogFile.tmp";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

}

# Clean up tmp files
`rm -f $LogFile.tmp`;

