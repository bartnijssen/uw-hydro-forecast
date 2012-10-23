#-------------------------------------------------------------------------------
# Rout_specific.pl - subroutines for running the routing model in the SIMMA
#                     framework.  Called by run_rout.pl.
#                     NOTE: these routines assume that several variables
#                     have been defined globally in the parent script.
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# Rout routines
#-------------------------------------------------------------------------------
use Log::Log4perl qw(:easy);

#-------------------------------------------------------------------------------
# wrap_run_vic - runs the VIC model for the simulation period
#-------------------------------------------------------------------------------
sub wrap_run_rout {

  # Run the routing model
  &run_rout;
}

#-------------------------------------------------------------------------------
# run_rout - Runs routing model
#-------------------------------------------------------------------------------
sub run_rout {

  # Create controlfile
  @MyParamsInfo = @ParamsInfo;
  foreach (@MyParamsInfo) {
    s/<PARAMS_ROUT_DIR>/$ParamsModelDir/g;
    s/<SPINUP_DIR>/$SpinupModelAscDir/g;
    s/<SPINUP_START_YEAR>/$Spinup_Syr/g;
    s/<SPINUP_START_MON>/$Spinup_Smon/g;
    s/<SPINUP_START_DAY>/$Spinup_Sday/g;
    s/<SPINUP_END_YEAR>/$Spinup_Eyr/g;
    s/<SPINUP_END_MON>/$Spinup_Emon/g;
    s/<SPINUP_END_DAY>/$Spinup_Eday/g;
    s/<FLUX_OUTPUT>/$results_dir_asc/g;
    s/<FLUX_START_YEAR>/$start_year/g;
    s/<FLUX_START_MON>/$start_month/g;
    s/<FLUX_START_DAY>/$start_day/g;
    s/<FLUX_END_YEAR>/$end_year/g;
    s/<FLUX_END_MON>/$end_month/g;
    s/<FLUX_END_DAY>/$end_day/g;
    s/<ROUT_OUTPUT>/$Routdir/g;
    s/<ROUT_START_YEAR>/$start_year/g;
    s/<ROUT_START_MON>/$start_month/g;
    s/<ROUT_START_DAY>/$start_day/g;
    s/<ROUT_END_YEAR>/$end_year/g;
    s/<ROUT_END_MON>/$end_month/g;
    s/<ROUT_END_DAY>/$end_day/g;
  }
  open(CONTROLFILE, ">$controlfile") or
    LOGDIE("Cannot open current controlfile $controlfile");
  DEBUG("OPENING current controlfile $controlfile");
  foreach (@MyParamsInfo) {
    print "$_\n";
    print CONTROLFILE;
  }
  close(CONTROLFILE);

  # Run the model
  $cmd = "$ROUTE_EXE_DIR/$ROUTE_EXE_NAME $controlfile >& $LOGFILE";
  DEBUG($cmd);
  (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
}  ### Sub_rout

#-------------------------------------------------------------------------------
# This line is necessary for the contents of this file to be included in other
# perl programs via a "require" statement
#-------------------------------------------------------------------------------
1;
