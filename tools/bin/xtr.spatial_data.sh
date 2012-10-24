#!/bin/bash
# A. Wood
# script extract variables from the flux files & mon_flux files:
#
#      SWE, 1st day of month, from forecasts
#      All mon. avgs. vars
#
# daily flux output files NOW looks like this:
#   year mon day pcp  evap  ro    bf   tavg   moist1  moist2  moist3  swe 
#   1979  1   1  0.0  0.0  0.00  2.05  -4.1    24.4    108.1   190.1  40.0 
#
# METEOR VERSION
#
### Shrad-2011 Reformatted it
# ----------------------------------------------
# 1. go through the daily summary flux files, extract SWE, unsorted,
#    for each 1st of month in forecast period
# 2. also, from the monthly summary flux files, extract components, unsorted,
#    for months current + 12 forecast months

MINPARAMS=5

if [ $# -lt "$MINPARAMS" ] 
then
    echo "USAGE: $0 BASIN TMPDIR FLIST RESULTS_DIR MON_DIR"
    exit 1
fi

## Basin name
BAS="$1" 
## Temp directory inside ESP Store dir
TMPDIR="$2" 
## List of flux file names
FLIST="$3" 

### Results directory where daily flux output of the given ensemble are stored 
RESULTS_DIR="$4"
### Directory where monthly flux output are---- aggregated by the script before this one.
MON_DIR="$5" 

#### Shrad -- Remove old files.
if [ -e $TMPDIR/$BAS.dy1_swe ] 
then
    \rm $TMPDIR/$BAS.dy1_swe 
fi
if [ -e $TMPDIR/$BAS.all_monvars ] 
then
    \rm $TMPDIR/$BAS.all_monvars
fi

h=1
while read line
do
    FDLY=$RESULTS_DIR/"$line"
    FMON=$MON_DIR/"$line"
    awk '{if($3==1)printf("%.1f ",$12)}END{printf("\n")}' $FDLY >> $TMPDIR/$BAS.dy1_swe
  # all fcst vars (print only months where sm3 > 0 (shows valid avg. mon)
    awk '{ \
          for (s=0; s<12; s++) { \
              f=s*9+2; \
              if ($(f+7)+$(f+6)+$(f+5)>0) \
                  printf("%.1f %.1f %.1f %.1f %.1f   ", \
                         $f, $(f+4), $(f+2)+$(f+3), $(f+5)+$(f+6)+$(f+7), $(f+8)) \
          } \
         } \
         END {printf("\n")}' $FMON >> $TMPDIR/$BAS.all_monvars
    let h=h+1
done < "$FLIST"
echo "Done with $0"
