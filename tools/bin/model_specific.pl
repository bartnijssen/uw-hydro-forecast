#-------------------------------------------------------------------------------
# model_specific.pl - subroutines for running specific models in the SIMMA
#                     framework.  Called by run_model.pl.
#                     NOTE: these routines assume that several variables
#                     have been defined globally in the parent script.
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# VIC routines
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# wrap_run_vic - runs the VIC model for the simulation period
#-------------------------------------------------------------------------------
sub wrap_run_vic {

  # Set state file date
  ($state_year,$state_month,$state_day) = ($end_year,$end_month,$end_day);

  # Initial state file
  if (!$init_file) {
    $init_file = "FALSE";
  }

  # Run the model
  &run_vic;

#  # Optional post-processing
#  foreach $cmd (@POSTPROC) {
#    $cmd = $cmd . " >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
#    (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";
#  }

}

#-------------------------------------------------------------------------------
# run_vic - handles actual execution of the VIC model
#-------------------------------------------------------------------------------
sub run_vic {

  # Create controlfile
  @MyParamsInfo = @ParamsInfo;
  foreach (@MyParamsInfo) {
    s/<START_YEAR>/$start_year/g;
    s/<START_MONTH>/$start_month/g;
    s/<START_DAY>/$start_day/g;
    s/<END_YEAR>/$end_year/g;
    s/<END_MONTH>/$end_month/g;
    s/<END_DAY>/$end_day/g;
    s/<PARAMS_DIR>/$ParamsModelDir/g;
    s/<INITIAL>/$init_file/;
    s/<FORCING_DIR>/$ForcingModelDir/g;
    s/<FORC_PREFIX>/$prefix/g;
    s/<FORCE_START_YEAR>/$Forc_Syr/g;
    s/<FORCE_START_MONTH>/$Forc_Smon/g;
    s/<FORCE_START_DAY>/$Forc_Sday/g;
    s/<STATE_DIR>/$state_dir/g;
    s/<STATE_PREFIX>/state/g;
    s/<STATEYEAR>/$state_year/g;
    s/<STATEMONTH>/$state_month/g;
    s/<STATEDAY>/$state_day/g;
    s/<RESULTS_DIR>/$results_dir_asc/g; # Note that VIC writes ascii output
  }
  open (CONTROLFILE, ">$controlfile") or die "$0: ERROR: cannot open current controlfile $controlfile\n";
  foreach (@MyParamsInfo) {
    print CONTROLFILE;
  }
  close(CONTROLFILE);

  # Run the model
#  $cmd = "$MODEL_EXE_DIR/$MODEL_EXE_NAME -g $controlfile 2>&1 >> $LOGFILE";
  $cmd = "$MODEL_EXE_DIR/$MODEL_EXE_NAME -g $controlfile >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
  (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";

#######################################################
#  # Optionally convert ascii results to netcdf
#  if ($NC_OUT) {
#    if ($UNCOMP_OUT) {
#      $comp_str = "";
#    }
#    else {
#      $comp_str = "-c";
#    }
#    foreach $output_prefix (@output_prefixes) {
#      $metadata_template = "$ParamsModelDir/metadata.$output_prefix.template";
#      $metadata = "$current_control_dir/metadata.$output_prefix.txt";
#      if (!open(METADATA_TEMPLATE, "$metadata_template")) {
#        $exit_code = 1;
#        printf STDERR "$0: ERROR: cannot open metadata template $metadata_template\n";
#        return $exit_code;
#      }
#      if (!open(METADATA, ">$metadata")) {
#        $exit_code = 1;
#        printf STDERR "$0: ERROR: cannot open metadata file $metadata\n";
#        return $exit_code;
#      }
#      foreach (<METADATA_TEMPLATE>) {
#        s/<START_DATE>/$current_start_date/;
#        s/<END_DATE>/$current_end_date/;
#        print METADATA;
#      }
#      close(METADATA_TEMPLATE);
#      close(METADATA);
#      $cmd = "$TOOLS_DIR/bin/vic2nc -i $results_dir_asc_daily -p $output_prefix -m $metadata $gridfile_opt -o $results_dir/$output_prefix $comp_str -t m >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
#      print "$cmd\n";
#      if (system($cmd)!=0) {
#        $exit_code = $?;
## vic2nc returns a non-zero exit code for some reason
##      printf STDERR "$0: ERROR: $cmd failed: $exit_code\n";
##      return $exit_code;
#        printf STDERR "$0: WARNING: $cmd exited with error code: $exit_code\n";
#      }
#    }
#  }
#
#  # Copy control files up to main control dir
#  if ($SAVE_YEARLY) {
#    $current_controlfile_mv = $current_controlfile . "." . $current_end_year;
#    $current_controlfile_mv =~ s/\/$current_end_year\//\//;
#    $cmd = "mv $current_controlfile $current_controlfile_mv";
#print "$cmd\n";
#    $status = &shell_cmd($cmd);
#  }
#
#  # Remove intermediate directories
#  @dirlist = ($current_results_dir, $results_dir_asc_daily);
#  if ($current_control_dir != $control_dir) {
#    push @dirlist, $current_control_dir;
#  }
#  for $tmpdir (@dirlist) {
#    $cmd = "rm -rf $tmpdir";
#    system($cmd);
#  }

}


#-------------------------------------------------------------------------------
# Noah routines
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# wrap_run_noah - runs the Noah model for the simulation period
#-------------------------------------------------------------------------------
sub wrap_run_noah {

  # Run the model continuously over the entire simulation period
  &run_noah;

  # Optionally extract selected variables to ascii
  if ($extract_vars && $extract_vars !~ /^none$/i) {
#    $cmd = "$TOOLS_DIR/bin/wrap_nc2vic.pl $results_dir $output_prefixes[0] $extract_vars $results_dir_asc $output_prefixes[0] 2>&1 >> $LOGFILE";
    $cmd = "$TOOLS_DIR/bin/wrap_nc2vic.pl $results_dir $output_prefixes[0] $extract_vars $results_dir_asc $output_prefixes[0] scientific >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
    (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";

#    # Optional post-processing
#    foreach $cmd (@POSTPROC) {
#      $cmd = $cmd . " >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
#      (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";
#    }

    # Multiply moisture fluxes by sec_per_day to get daily total moisture fluxes
    $status = &make_dir("$results_dir_asc.tmp");
    $cmd = "$TOOLS_DIR/bin/wrap_mult.pl $results_dir_asc wb 4 4,5,6 86400 $results_dir_asc.tmp >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
    (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";

    # Clean up temporary directories
    foreach $dir ("$results_dir_asc") {
      $cmd = "rm -rf $dir";
      (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";
    }
    $cmd = "mv $results_dir_asc.tmp $results_dir_asc";
    (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";

  }

}


#-------------------------------------------------------------------------------
# run_noah - handles actual execution of the Noah model
#-------------------------------------------------------------------------------
sub run_noah {

  # Create controlfile
  @MyParamsInfo = @ParamsInfo;
  foreach (@MyParamsInfo) {
    s/<START_YEAR>/$start_year/g;
    s/<START_MONTH>/$start_month/g;
    s/<START_DAY>/$start_day/g;
    s/<END_YEAR>/$end_year/g;
    s/<END_MONTH>/$end_month/g;
    s/<END_DAY>/$end_day/g;
    s/<PARAMS_DIR>/$ParamsModelDir/g;
    s/<INITIAL>/$init_file/;
    s/<FORCING_DIR>/$ForcingModelDir/g;
    s/<FORC_PREFIX>/$prefix/g;
    s/<STATE_DIR>/$state_dir/g;
    s/<STATE_PREFIX>/state/g;
    s/<RESULTS_DIR>/$results_dir/g;
    if ($UNCOMP_OUTPUT) {
      s/^(.*COMP_OUTPUT=).*/$1.FALSE./;
    }
  }
  open (CONTROLFILE, ">$controlfile") or die "$0: ERROR: cannot open current controlfile $controlfile\n";
  foreach (@MyParamsInfo) {
    print CONTROLFILE;
  }
  close(CONTROLFILE);

  # Run the model
#  $cmd = "$MODEL_EXE_DIR/$MODEL_EXE_NAME $controlfile 2>&1 >> $LOGFILE";
  $cmd = "$MODEL_EXE_DIR/$MODEL_EXE_NAME $controlfile >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
  (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";

  # Rename state files to contain date of final simulation day for that month
  $year = $start_year;
  $month = $start_month;
  while ( $year < $end_year || ($year == $end_year && $month <= $end_month) ) {
    $old_state_file_name = sprintf "%s/state.%04d%02d.nc", $StateModelDir, $year, $month;
    if ($year == $end_year && $month == $end_month) {
      $last_day = $end_day;
    }
    else {
      $last_day = $month_days[$month-1];
      if ($year % 4 == 0 && $month == 2) {
        $last_day++;
      }
    }
    $new_state_file_name = sprintf "%s/state.%04d%02d%02d.nc", $StateModelDir, $year, $month, $last_day;
    if (-e $old_state_file_name) {
      $cmd = "mv $old_state_file_name $new_state_file_name";
      (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";
    }
    $month++;
    if ($month > 12) {
      $month = 1;
      $year++;
    }
  }

}


#-------------------------------------------------------------------------------
# SAC routines
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# wrap_run_sac - runs the SAC model for the simulation period
#-------------------------------------------------------------------------------
sub wrap_run_sac {

  # Default parameter values
  # default pe dir will be the noah results directory for the same simulation period, etc.
  $pe_dir = $results_dir;
  # HACK - use noah_2.8 instead of noah
  # $pe_dir =~ s/sac/noah/g;
  $pe_dir =~ s/sac/noah_2.8/g;
  $get_pe_dir = 0;
  $pe_prefix = "pe";

  # Handle model-specific arguments
  foreach $arg (split /\s+/, $_[0]) {

    if ($arg eq "-pe") {
      $get_pe_dir = 1;
    }
    elsif ($get_pe_dir) {
      $pe_dir = $arg;
      $get_pe_dir = 0;
    }

  }

  # Run the model continuously over the entire simulation period
  &run_sac;

  # Optionally extract selected variables to ascii
  if ($extract_vars && $extract_vars !~ /^none$/i) {
#    $cmd = "$TOOLS_DIR/bin/wrap_nc2vic.pl $results_dir $output_prefixes[0] $extract_vars $results_dir_asc $output_prefixes[0]";
    $cmd = "$TOOLS_DIR/bin/wrap_nc2vic.pl $results_dir $output_prefixes[0] $extract_vars $results_dir_asc $output_prefixes[0] scientific >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
    (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";

#    # Optional post-processing
#    foreach $cmd (@POSTPROC) {
#      $cmd = $cmd . " >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
#      (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";
#    }

    # Multiply moisture fluxes by sec_per_day to get daily total moisture fluxes
    $status = &make_dir("$results_dir_asc.tmp");
    $cmd = "$TOOLS_DIR/bin/wrap_mult.pl $results_dir_asc wb 4 4,5,6 86400 $results_dir_asc.tmp >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
    (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";

    # Clean up temporary directories
    foreach $dir ("$results_dir_asc") {
      $cmd = "rm -rf $dir";
      (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";
    }
    $cmd = "mv $results_dir_asc.tmp $results_dir_asc";
    (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";

  }

}

#-------------------------------------------------------------------------------
# run_sac - handles actual execution of the SAC model
#-------------------------------------------------------------------------------
sub run_sac {

  # Create controlfile
  @MyParamsInfo = @ParamsInfo;
  foreach (@MyParamsInfo) {
    s/<START_YEAR>/$start_year/g;
    s/<START_MONTH>/$start_month/g;
    s/<START_DAY>/$start_day/g;
    s/<END_YEAR>/$end_year/g;
    s/<END_MONTH>/$end_month/g;
    s/<END_DAY>/$end_day/g;
    s/<PARAMS_DIR>/$ParamsModelDir/g;
    s/<INITIAL>/$init_file/;
    s/<FORCING_DIR>/$ForcingModelDir/g;
    s/<FORC_PREFIX>/$prefix/g;
    s/<STATE_DIR>/$state_dir/g;
    s/<STATE_PREFIX>/state/g;
    s/<RESULTS_DIR>/$results_dir/g;
    s/<PE_DIR>/$pe_dir/g;
    s/<PE_PREFIX>/$pe_prefix/g;
    if ($UNCOMP_OUTPUT) {
      s/^(.*COMP_OUTPUT=).*/$1.FALSE./;
    }
  }
  open (CONTROLFILE, ">$controlfile") or die "$0: ERROR: cannot open current controlfile $controlfile\n";
  foreach (@MyParamsInfo) {
    print CONTROLFILE;
  }
  close(CONTROLFILE);

  # Run the model
#  $cmd = "$MODEL_EXE_DIR/$MODEL_EXE_NAME $controlfile 2>&1 >> $LOGFILE";
  $cmd = "$MODEL_EXE_DIR/$MODEL_EXE_NAME $controlfile >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
  (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";

  # Rename state files to contain date of final simulation day for that month
  $year = $start_year;
  $month = $start_month;
  $day = $start_day;
  while ( $year < $end_year || ($year == $end_year && $month <= $end_month) ) {
    $old_state_file_name = sprintf "%s/state.%04d%02d.nc", $StateModelDir, $year, $month;
    if ($year == $end_year && $month == $end_month) {
      $last_day = $end_day;
    }
    else {
      $last_day = $month_days[$month-1];
      if ($year % 4 == 0 && $month == 2) {
        $last_day++;
      }
    }
    $new_state_file_name = sprintf "%s/state.%04d%02d%02d.nc", $StateModelDir, $year, $month, $last_day;
    if (-e $old_state_file_name) {
      $cmd = "mv $old_state_file_name $new_state_file_name";
      (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";
    }
    $month++;
    if ($month > 12) {
      $month = 1;
      $year++;
    }
  }

}


#-------------------------------------------------------------------------------
# CLM routines
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# wrap_run_clm - runs the CLM model for the simulation period
#-------------------------------------------------------------------------------
sub wrap_run_clm {

  # Run the model continuously over the entire simulation period
  &run_clm;

  # Optionally extract selected variables to ascii
  if ($extract_vars && $extract_vars !~ /^none$/i) {
#    $cmd = "$TOOLS_DIR/bin/wrap_nc2vic.pl $results_dir $output_prefixes[0] $extract_vars $results_dir_asc $output_prefixes[0]";
    $cmd = "$TOOLS_DIR/bin/wrap_nc2vic.pl $results_dir $output_prefixes[0] $extract_vars $results_dir_asc $output_prefixes[0] scientific >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
    (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";

    # Optional post-processing
#    foreach $cmd (@POSTPROC) {
#      $cmd = $cmd . " >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
#      (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";
#    }

    # Multiply moisture fluxes by sec_per_day to get daily total moisture fluxes
    $status = &make_dir("$results_dir_asc.tmp");
    $cmd = "$TOOLS_DIR/bin/wrap_mult.pl $results_dir_asc wb 4 4,5,6,7,8 86400 $results_dir_asc.tmp >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
    (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";

    # Add liquid and frozen soil moisture fields together
    $status = &make_dir("$results_dir_asc.tmp2");
    $cmd = "$TOOLS_DIR/bin/wrap_add_fields.pl $results_dir_asc.tmp wb 4 $results_dir_asc.tmp2 4:5:6,10:20,11:21,12:22,13:23,14:24,15:25,16:26,17:27,18:28,19:29 >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
    (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";

    # Insert dummy records where leap days were omitted
    $status = &make_dir("$results_dir_asc.tmp3");
    $cmd = "$TOOLS_DIR/bin/wrap_insert_leap_day.pl $results_dir_asc.tmp2 wb $results_dir_asc.tmp3 $start_date $end_date >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
    (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";

    # Clean up temporary directories
    foreach $dir ("$results_dir_asc","$results_dir_asc.tmp","$results_dir_asc.tmp2") {
      $cmd = "rm -rf $dir";
      (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";
    }
    $cmd = "mv $results_dir_asc.tmp3 $results_dir_asc";
    (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";

    if ($PROJECT eq "mexico") {
      $cmd = "cp $results_dir_asc/wb_22.7500_-109.7500 $results_dir_asc/wb_22.7500_-110.2500";
      $cmd = $cmd . " >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
      (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";
    }

  }

}

#-------------------------------------------------------------------------------
# run_clm - handles actual execution of the CLM model
#-------------------------------------------------------------------------------
sub run_clm {

  # CLM-specific parameters
  ($clm_end_year,$clm_end_month,$clm_end_day) = Add_Delta_Days($end_year,$end_month,$end_day,1);
  $clm_end_month = sprintf "%02d", $clm_end_month;
  $clm_end_day = sprintf "%02d", $clm_end_day;

  # Create controlfile
  @MyParamsInfo = @ParamsInfo;
  foreach (@MyParamsInfo) {
    s/<PROJECT>/$PROJECT/g;
    s/<FORCING_DIR>/$ForcingModelDir/g;
    s/<FORC_PREFIX>/$prefix/g;
    s/<PARAMS_DIR>/$ParamsModelDir/g;
    s/<STATE_DIR>/$state_dir/g;
    s/<RESULTS_DIR>/$results_dir/g;
    s/<START_YEAR>/$start_year/g;
    s/<START_MONTH>/$start_month/g;
    s/<START_DAY>/$start_day/g;
    s/<END_YEAR>/$clm_end_year/g;
    s/<END_MONTH>/$clm_end_month/g;
    s/<END_DAY>/$clm_end_day/g;
    s/<INITIAL>/$init_file/g;
  }
  open (CONTROLFILE, ">$controlfile") or die "$0: ERROR: cannot open current controlfile $controlfile\n";
  foreach (@MyParamsInfo) {
    print CONTROLFILE;
  }
  close(CONTROLFILE);

  # Run the model
  $cmd = "cp $controlfile $MODEL_EXE_DIR/lnd.stdin";
  (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";
####  $cmd = "/bin/sh; $MODEL_EXE_DIR/$MODEL_EXE_NAME < $controlfile 2>&1 >> $LOGFILE; exit";
###  $cmd = "cd $MODEL_EXE_DIR; $MODEL_EXE_NAME >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp; cd -";
#  $cmd = "$MODEL_EXE_DIR/$MODEL_EXE_NAME < $controlfile >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
  $cmd = "cd $MODEL_EXE_DIR; ./$MODEL_EXE_NAME >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp; cd -";
#  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";

  # Insert origin time into the output files
  # This assumes that CLM writes all output variables to one file
  opendir(INDIR,"$results_dir") or die "$0: ERROR: cannot open $results_dir for reading\n";
  @my_filelist = grep /^$PROJECT.clm2.h0/, readdir(INDIR);
  closedir(INDIR);
  foreach $myfile (@my_filelist) {
    $newfile = $myfile;
    $newfile =~ s/$PROJECT.clm2.h0/$output_prefixes[0]/;
    $cmd = "mv $results_dir/$myfile $results_dir/$newfile";
#    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";
    $cmd = "/usr/local/bin/ncatted -O -a time_origin,global,c,c,\"$start_year-$start_month-$start_day 00:00:00\" $results_dir/$newfile >& $LOGFILE.tmp; cat $LOGFILE.tmp >> $LOGFILE; rm $LOGFILE.tmp";
#    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";
  }

  # Rename state file to contain date of final simulation day
  $old_state_file_name = sprintf "%s/%s.clm2.r.%04d-%02d-%02d-00000.nc", $StateModelDir, $PROJECT, $clm_end_year, $clm_end_month, $clm_end_day;
  $new_state_file_name = sprintf "%s/state.%04d%02d%02d.nc", $StateModelDir, $end_year, $end_month, $end_day;
  $cmd = "mv $old_state_file_name $new_state_file_name";
  (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";

}


#-------------------------------------------------------------------------------
# This line is necessary for the contents of this file to be included in other
# perl programs via a "require" statement
#-------------------------------------------------------------------------------
1;
