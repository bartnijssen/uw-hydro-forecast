#!/usr/bin/perl
# SGE directives
#$ -cwd
#$ -j y
#$ -S /usr/bin/perl

use Date::Calc qw(Days_in_Month Delta_Days Add_Delta_Days);

# Get command-line arguments
$PROJECT = shift;
$FORC_UPD_DATE_FILE = shift;
$CURRSPIN_DATE_FILE = shift;
$CURRSPIN_START_DATE_FILE = shift;
$CURRSPIN_FORC_DIR = shift;

# Constants
$ROOT_DIR = "/raid8/forecast/sw_monitor";
$TOOLS_DIR = "$ROOT_DIR/tools";

# Read dates in date files
open (FORC_UPD_DATE_FILE, $FORC_UPD_DATE_FILE) or die "$0: ERROR: cannot open file $FORC_UPD_DATE_FILE\n";
foreach (<FORC_UPD_DATE_FILE>) {
  if (/^(\d+)\s+(\d+)\s+(\d+)\s+/) {
    ($forc_upd_end_year,$forc_upd_end_mon,$forc_upd_end_mday) = ($1,$2,$3);
  }
}
close(FORC_UPD_DATE_FILE);
open (CURRSPIN_DATE_FILE, $CURRSPIN_DATE_FILE) or die "$0: ERROR: cannot open file $CURRSPIN_DATE_FILE\n";
foreach (<CURRSPIN_DATE_FILE>) {
  if (/^(\d+)\s+(\d+)\s+(\d+)\s+/) {
    ($currspin_end_year,$currspin_end_mon,$currspin_end_mday) = ($1,$2,$3);
  }
}
close(CURRSPIN_DATE_FILE);
open (CURRSPIN_START_DATE_FILE, $CURRSPIN_START_DATE_FILE) or die "$0: ERROR: cannot open file $CURRSPIN_START_DATE_FILE\n";
foreach (<CURRSPIN_START_DATE_FILE>) {
  if (/^(\d+)\s+(\d+)\s+(\d+)\s+/) {
    ($currspin_start_year,$currspin_start_mon,$currspin_start_mday) = ($1,$2,$3);
  }
}
close(CURRSPIN_START_DATE_FILE);

# Build date strings
$FORC_START_DATE = sprintf "%04d-%02d-%02d", $currspin_start_year,$currspin_start_mon,$currspin_start_mday;
$FORC_UPD_END_DATE = sprintf "%04d-%02d-%02d", $forc_upd_end_year,$forc_upd_end_mon,$forc_upd_end_mday;

# Update the current spinup forcings
$cmd = "$TOOLS_DIR/grds_2_tser.US.pl $forc_upd_end_year $forc_upd_end_mon $forc_upd_end_mday $currspin_end_year $currspin_end_mon $currspin_end_mday $CURRSPIN_FORC_DIR/";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
$cmd = "cp $FORC_UPD_DATE_FILE $CURRSPIN_DATE_FILE";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

# Disaggregate the forcings
$cmd = "$TOOLS_DIR/wrap_vicDisagg.pl -p $PROJECT -f curr_spinup -pf data -s $FORC_START_DATE -e $FORC_UPD_END_DATE";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

# Convert forcings to netcdf
$cmd = "$TOOLS_DIR/wrap_vic2nc.pl -p $PROJECT -f curr_spinup -pf full_data -s $FORC_START_DATE -e $FORC_UPD_END_DATE";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

# Copy date file to signal the completion of forcings update
$cmd = "cp $FORC_UPD_DATE_FILE $CURRSPIN_FORC_DIR/../nc/";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
