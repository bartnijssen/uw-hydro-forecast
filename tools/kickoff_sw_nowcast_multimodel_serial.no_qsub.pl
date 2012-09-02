#!/usr/bin/perl
use Date::Calc qw(Days_in_Month Delta_Days Add_Delta_Days);

# Access to environment variables
use Env;

# Set up netcdf access
$ENV{INC_NETCDF} = "/usr/local/i386/include";
$ENV{LIB_NETCDF} = "/usr/local/i386/lib";


# Get command-line arguments
$PROJECT = shift;
$MODEL_LIST = shift; # comma-separated list of model names
                     # noah and sac are typically treated as one combined model, "noah_sac"

$PROJECT_UC = $PROJECT;
$PROJECT_UC =~ tr/a-z/A-Z/;

# Constants
$ROOT_DIR = "/raid8/forecast/sw_monitor";
$TOOLS_DIR = "$ROOT_DIR/tools";

# Derived constants
$CURRSPIN_FORC_DIR = "$ROOT_DIR/data/$PROJECT/forcing/curr_spinup";
$FORC_UPD_DIR = "$ROOT_DIR/data/$PROJECT/forcing/spinup/dly_append";
$CURRSPIN_START_DATE_FILE = "$CURRSPIN_FORC_DIR/FORC.START_DATE";
$CURRSPIN_DATE_FILE = "$CURRSPIN_FORC_DIR/FORC.END_DATE";
$FORC_UPD_DATE_FILE = "$FORC_UPD_DIR/FORC.END_DATE";
$SPINUP_STATE_DIR = "$ROOT_DIR/data/$PROJECT/state/spinup_nearRT";
$XYZZ_DIR = "$ROOT_DIR/data/$PROJECT/spatial/xyzz.all";
$RESULTS_DATE_FILE = "$XYZZ_DIR/RESULTS.END_DATE";

# Initialize the date information
($curr_sec,$curr_min,$curr_hour,$curr_mday,$curr_mon,$curr_year,$wday,$yday,$isdst) = localtime(time);
$curr_mon++;
$curr_year += 1900;
($exit_year,$exit_mon,$exit_mday) = Add_Delta_Days($curr_year,$curr_mon,$curr_mday,1);
$days_till_exit = 1;

# Read dates in date files
open (CURRSPIN_DATE_FILE, $CURRSPIN_DATE_FILE) or die "$0: ERROR: cannot open file $CURRSPIN_DATE_FILE\n";
foreach (<CURRSPIN_DATE_FILE>) {
  if (/^(\d+)\s+(\d+)\s+(\d+)\s+/) {
    ($currspin_end_year,$currspin_end_mon,$currspin_end_mday) = ($1,$2,$3);
  }
}
close(CURRSPIN_DATE_FILE);
open (FORC_UPD_DATE_FILE, $FORC_UPD_DATE_FILE) or die "$0: ERROR: cannot open file $FORC_UPD_DATE_FILE\n";
foreach (<FORC_UPD_DATE_FILE>) {
  if (/^(\d+)\s+(\d+)\s+(\d+)\s+/) {
    ($forc_upd_end_year,$forc_upd_end_mon,$forc_upd_end_mday) = ($1,$2,$3);
  }
}
close(FORC_UPD_DATE_FILE);

# Compare forcing end dates
$currspin_forc_upd_diff = Delta_Days($forc_upd_end_year,$forc_upd_end_mon,$forc_upd_end_mday,$currspin_end_year,$currspin_end_mon,$currspin_end_mday);
if ($currspin_forc_upd_diff > 0) {
  die "$0: ERROR: current spinup forcings are newer than update forcings\n";
}

# Preliminary loop: periodically check the date files to see if forcings have been updated
while ($currspin_forc_upd_diff == 0 && $days_till_exit > 0) {

  # Wait a while before checking again
  print "Updated forcings not received; sleeping...\n";
  sleep 300;

  # Check for the arrival of a new forcing update
  open (FORC_UPD_DATE_FILE, $FORC_UPD_DATE_FILE) or die "$0: ERROR: cannot open file $FORC_UPD_DATE_FILE\n";
  foreach (<FORC_UPD_DATE_FILE>) {
    if (/^(\d+)\s+(\d+)\s+(\d+)\s+/) {
      ($forc_upd_end_year,$forc_upd_end_mon,$forc_upd_end_mday) = ($1,$2,$3);
    }
  }
  $currspin_forc_upd_diff = Delta_Days($forc_upd_end_year,$forc_upd_end_mon,$forc_upd_end_mday,$currspin_end_year,$currspin_end_mon,$currspin_end_mday);
  if ($currspin_forc_upd_diff > 0) {
    die "$0: ERROR: current spinup forcings are newer than update forcings\n";
  }

  # Check current time again
  ($curr_sec,$curr_min,$curr_hour,$curr_mday,$curr_mon,$curr_year,$wday,$yday,$isdst) = localtime(time);
  $curr_mon++;
  $curr_year += 1900;
  $days_till_exit = Delta_Days($curr_year,$curr_mon,$curr_mday,$exit_year,$exit_mon,$exit_mday);

}

# Exit at end of current calendar day
if ($days_till_exit == 0) {
  print "$0: End of current calendar day; exiting.\n";
  exit;
}

#-----------------------------
# Do the update
#-----------------------------

# Run the forcing update and the model runs in serial
$cmd = "$TOOLS_DIR/wrap_nowcast_serial.no_qsub.pl $PROJECT $FORC_UPD_DATE_FILE $CURRSPIN_DATE_FILE $CURRSPIN_START_DATE_FILE $CURRSPIN_FORC_DIR/asc_vicinp $RESULTS_DATE_FILE $SPINUP_STATE_DIR $MODEL_LIST";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

