#!/usr/bin/perl 
# A. Wood August 2007
# run a set of ESP forecasts, given existing state files & forcings, etc.
# this version:  for SW Monitor, on sere, in aww dirs

# date settings from arguments
$CYR = $ARGV[0];  # current (initial) day
$CMO = $ARGV[1]; 
$CDY = $ARGV[2];
$FSYR = $ARGV[3]; # climatology boundaries
$FEYR = $ARGV[4];
$my_model = $ARGV[5];
$PROJECT = $ARGV[6];

#print "$CYR $CMO $CDY $FSYR $FEYR $my_model $PROJECT\n";
# clear out working directories, make necessary ones
$TOOLS_DIR = "/raid8/forecast/sw_monitor/tools";
#$STORDIR = "$OUTDIR/summary/$CYR$CMO$CDY";
$datestr = sprintf("%04d%02d%02d",$CYR,$CMO,$CDY);
$STORDIR = "/raid8/forecast/sw_monitor/data/$PROJECT/results/esp/$my_model/esp/SAVED/$datestr";
`mkdir $STORDIR`;
#`mkdir $STORDIR`;

# only run if state file is copied...

$METYR = "$FSYR";

while ($METYR <= $FEYR) # forecast year loop

{   $ENDYR = $METYR +1; #### for 1 year simulation
    $FORC_START_DATE = sprintf "%04d-%02d-%02d", $METYR,$CMO,$CDY;
    $FORC_UPD_END_DATE = sprintf "%04d-%02d-%02d", $ENDYR,$CMO,$CDY;
    $datestr = sprintf("%04d%02d%02d",$CYR,$CMO,$CDY);
    $init_state_file = "state_" . "$datestr";  #### Will have to change this for other models

print "Running ensembles intialized on $FORC_START_DATE\n ";

#print "$TOOLS_DIR/esp_scripts/run_model_esp.pl -m $my_model -p $PROJECT -f retro -pf data -r esp -s $FORC_START_DATE -e $FORC_UPD_END_DATE -st spinup.1915.10 -i $init_state_file\n";

$cmd = "$TOOLS_DIR/esp_scripts/run_model_esp.pl -m $my_model -p $PROJECT -f retro -pf data -r esp -s $FORC_START_DATE -e $FORC_UPD_END_DATE -st retro.2005 -i $init_state_file";

print "$cmd\n";

#(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

$OUTDIR = "/raid8/forecast/sw_monitor/data/$PROJECT/results/esp/$my_model/esp";

`mkdir flux`;
` cp -r /raid8/forecast/sw_monitor/data/$PROJECT/results/esp/$my_model/esp/asc flux/ `;


print "\nStoring the output\n";

#`cd $OUTDIR`; ### CD into the flux dir
#compress the outputs
`tar -czf $STORDIR/fluxes.$METYR.tar.gz flux/ `;
#`cd -`; ### out of the flux dir
`rm -rf ./flux`;

$METYR = $METYR+1;
}
