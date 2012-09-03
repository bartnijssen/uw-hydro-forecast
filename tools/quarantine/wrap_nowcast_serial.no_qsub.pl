#!/usr/bin/perl
# SGE directives
#$ -cwd
#$ -j y
#$ -S /usr/bin/perl

use Date::Calc qw(Days_in_Month Delta_Days Add_Delta_Days);

# Access to environment variables
use Env;

# Set up netcdf access
$ENV{INC_NETCDF} = "/usr/local/i386/include";
$ENV{LIB_NETCDF} = "/usr/local/i386/lib";


# Get command-line arguments
$PROJECT = shift;
$FORC_UPD_DATE_FILE = shift;
$CURRSPIN_DATE_FILE = shift;
$CURRSPIN_START_DATE_FILE = shift;
$CURRSPIN_FORC_DIR = shift;
$RESULTS_DATE_FILE = shift;
$SPINUP_STATE_DIR = shift;
$MODEL_LIST = shift;
@MODELS = split /,/, $MODEL_LIST;

# Constants
$ROOT_DIR = "/raid8/forecast/sw_monitor";
$TOOLS_DIR = "$ROOT_DIR/tools";
$CONFIG_DIR = "$ROOT_DIR/config";
$CONFIG_FILE = "$CONFIG_DIR/config.project.$PROJECT";

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

# Read climatology start/end years from config file
open (CONFIG_FILE, $CONFIG_FILE) or die "$0: ERROR: cannot open file $CONFIG_FILE\n";
foreach (<CONFIG_FILE>) {
  if (/^CLIM_START_YR\s+(\d+)/) {
    $CLIM_START_YR = $1;
  }
  if (/^CLIM_END_YR\s+(\d+)/) {
    $CLIM_END_YR = $1;
  }
}
close(CONFIG_FILE);

# Build date strings
$FORC_START_DATE = sprintf "%04d-%02d-%02d", $currspin_start_year,$currspin_start_mon,$currspin_start_mday;
$FORC_UPD_END_DATE = sprintf "%04d-%02d-%02d", $forc_upd_end_year,$forc_upd_end_mon,$forc_upd_end_mday;

# Run the update script
$cmd = "$TOOLS_DIR/update_forcings.pl $PROJECT $FORC_UPD_DATE_FILE $CURRSPIN_DATE_FILE $CURRSPIN_START_DATE_FILE $CURRSPIN_FORC_DIR";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

# Create preliminary results date file
$datestr = sprintf "%04d%02d%02d", $forc_upd_end_year, $forc_upd_end_mon, $forc_upd_end_mday;
open (RESULTS_DATE_FILE, ">$RESULTS_DATE_FILE.tmp") or die "$0: ERROR: cannot open results date file $RESULTS_DATE_FILE.tmp for writing\n";
print RESULTS_DATE_FILE "$forc_upd_end_year $forc_upd_end_mon $forc_upd_end_mday  # Nowcast Date\n";

# Run the models and get their statistics
foreach $model (@MODELS) {
  if ($model eq "noah_sac") {
    &process_model("noah");
    &process_model("sac");
  }
  else {
    &process_model($model);
  }
}

# Make multimodel average
$MODEL_LIST =~ s/noah_sac/noah,sac/;
$datestr = sprintf "%04d%02d%02d", $forc_upd_end_year,$forc_upd_end_mon,$forc_upd_end_mday;
$cmd = "$TOOLS_DIR/mk_multmod_avg.pl $PROJECT $MODEL_LIST $datestr";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
print RESULTS_DATE_FILE "multimodel complete\n";

# Make plots
@MODELS = split /,/, $MODEL_LIST;
push @MODELS, "multimodel";
foreach $model (@MODELS) {
  $cmd = "$TOOLS_DIR/plot_qnts.pl.old $PROJECT $model $forc_upd_end_year $forc_upd_end_mon $forc_upd_end_mday $CLIM_START_YR $CLIM_END_YR";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
}

# One final write to the  results date file to signify that the runs are complete
print RESULTS_DATE_FILE "# THIS IS A GENERATED FILE; DO NOT EDIT DATE ABOVE\n";
close(RESULTS_DATE_FILE);
$cmd = "mv $RESULTS_DATE_FILE.tmp $RESULTS_DATE_FILE";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";


sub process_model {

  my $my_model = shift @_;

#  # Special pre-processing
#  $extract = "-x Qs,Qsb,SWE,SoilMoist";
#  if ($my_model eq "clm") {
#    # Different variables to extract
#    $extract = "-x QOVER,QDRAI,H2OSNO,SOILLIQ,SOILICE";
#    # Clean out asc directory
#    if (-e "$ROOT_DIR/data/$PROJECT/results/curr_spinup/clm/daily/asc") {
#      $cmd = "rm -rf $ROOT_DIR/data/$PROJECT/results/curr_spinup/clm/daily/asc";
#      print "$cmd\n";
#      (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";
#    }
#  }
#  if ($my_model eq "vic") {
#    # Output already in ascii format
#    $extract = "";
#  }

  # Get name of last spinup state file
  @statefilelist = `ls $SPINUP_STATE_DIR/$my_model`;
  if ($my_model eq "clm") {
    @sortlist = grep /^$PROJECT.clm2.r.+nc$/, sort(@statefilelist);
  }
  else {
    @sortlist = sort @statefilelist;
  }
  $init_state_file = pop @sortlist;
  chomp $init_state_file;

  # Run model
#  $cmd = "$TOOLS_DIR/run_model.pl.old -m $my_model -p $PROJECT -f curr_spinup -pf full_data -s $FORC_START_DATE -e $FORC_UPD_END_DATE -i $SPINUP_STATE_DIR/$my_model/$init_state_file $extract -l";
#  $cmd = "$TOOLS_DIR/run_model.pl.old -m $my_model -p $PROJECT -f curr_spinup -pf full_data -s $FORC_START_DATE -e $FORC_UPD_END_DATE -i $SPINUP_STATE_DIR/$my_model/$init_state_file $extract";
  $cmd = "$TOOLS_DIR/run_model.pl.old -m $my_model -p $PROJECT -f curr_spinup -pf full_data -s $FORC_START_DATE -e $FORC_UPD_END_DATE -i $SPINUP_STATE_DIR/$my_model/$init_state_file";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

  # Special post-processing
  if ($my_model eq "clm") {
#    # Add liquid and frozen soil moisture
#    $cmd = "$TOOLS_DIR/add_liq_ice.pl $ROOT_DIR/data/$PROJECT/results/curr_spinup/clm/daily/asc wb 7 17";
#    print "$cmd\n";
#    (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";
    # Convert longitudes
    $cmd = "$TOOLS_DIR/clm_fix_lon.pl $ROOT_DIR/data/$PROJECT/results/curr_spinup/clm/daily/asc wb";
    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR in $cmd: $?\n";
  }

  # Convert soil moistures to percentiles of historical distribution
  $cmd = "$TOOLS_DIR/get_stats.pl.old $my_model $PROJECT $forc_upd_end_year $forc_upd_end_mon $forc_upd_end_mday $CLIM_START_YR $CLIM_END_YR";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

  # Cumulative runoff
  if ($my_model =~ /vic/i) {
    $cmd = "$TOOLS_DIR/calc.cum_ro_qnts.pl.old $my_model $PROJECT $forc_upd_end_year $forc_upd_end_mon $forc_upd_end_mday $CLIM_START_YR $CLIM_END_YR";
    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
  }

  # Record completion of this model's processing
  print RESULTS_DATE_FILE "$my_model complete\n";

}
