#!/bin/bash 
# program to extract monthly averages from the daily flux file output
# timeseries version, now finds nrecs automatically
# AWW-2003
## Shrad -2011 Reformatted it
## Shrad-2011 This script process ESP flux output for each ensemble separately
## hence the script is called after VIC run of each ensemble.
## BN changed to bash because it would not work on PNNL machine

MINPARAMS=6

if [ $# -lt "$MINPARAMS" ] 
then
    echo "USAGE: $0 METYR BASIN BINDIR ARCHDIR RESULTS_DIR FLIST"
    exit 1
fi

### Ensemble year
METYR="$1" 
## Name of the Basin
BASIN="$2"
## Directory where post processing scripts are
BINDIR="$3"
## Directory where data after post porcessing will be stored
ARCHDIR="$4"
## Directory where ESP daily flux output is
RESULTS_DIR="$5" 
### The directory where monthly ESP flux output will be stored
MONDIR="$6" 
### List of flux files
FLIST="$7" 

mkdir -p $MONDIR

echo "Working VIC-output directory is $RESULTS_DIR"
# find NRECS 
F=`head -1 $FLIST`
NRECS=`wc $RESULTS_DIR/$F | awk '{print $1}' `
echo "averaging flux files"
while read line 
do
    echo "Averaging file $line"
    $BINDIR/xtr_mon_ts $RESULTS_DIR/$line $MONDIR/$line 1 12 $NRECS
done < "$FLIST"

echo "Extracting daily/monthly summary for basin $BASIN"
TMPDIR="$ARCHDIR/xtr_vars.$METYR" ### The Temp directory also has the the ensemble years
mkdir -p $TMPDIR
SPATIAL_DIR="$ARCHDIR/spatial"
mkdir -p $SPATIAL_DIR
  
$BINDIR/xtr.spatial_data.sh $BASIN $TMPDIR $FLIST $RESULTS_DIR $MONDIR 
# Archive the output of xtr.spatial_data.scr
cp $TMPDIR/$BASIN.dy1_swe $SPATIAL_DIR/$BASIN.dy1_swe.$METYR
cp $TMPDIR/$BASIN.all_monvars $SPATIAL_DIR/$BASIN.all_monvars.$METYR
#### Removing TMPDIR 
rm -rf $TMPDIR
echo "Done with $0"
