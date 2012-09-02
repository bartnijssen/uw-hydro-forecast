#!/usr/bin/perl -w
# A. Wood
# transforming gridded MONTHLY amounts to gridded daily amounts
# - proceed one month at a time, since data inputs are very large
# need to rescale each months values (per grid cell) to equal mon amt
# better way may be to invoke the thiessen polygons
#   (but the problem with that how to handle missing dly vals)

#   for PRECIP only

# inputs:  monthly amount grid for spinup data (rows=cells, cols=months)
#            note, this is transposed relative to the input qnt grid
#          daily amount grid (rows=months, cols=cells)
# output:  rescaled dly amount grid
# AWW-100803
# AWW-103103:  modified to run in loop for all basins
# AWW-1104:  modified to run using flexible periods rather than months
#            and to run off ARGS only

#use Date::Calc qw(Days_in_Month Delta_Days);
use lib "/raid8/forecast/proj/ncast/src/lib";
use UWTime;
use Date::Manip;

# ------------- ARGUMENTS ----------------
$Fperamt  = shift;
$Fdlyamt  = shift;
$Syr = shift;
$Smon = shift;
$Fyr = shift;
$Fmon = shift;
$Fday = shift;
$Frescale = shift;

# ===== open, read in obs quantiles ================
open(INF, "<$Fperamt") or die "$0: ERROR: Cannot open $Fperamt: $!\n";
$c=0;
while (<INF>) {
  @tmp = split;
  for($per=0;$per<@tmp;$per++) {
    $peramt[$c][$per] = $tmp[$per];
  }
  $c++;
}
close(INF);
$cells = $c;

print "### Log for $0\n";
print "Start is $Syr $Smon\n";
print "Forc is $Fyr $Fmon $Fday\n";
print "Number of periods is $per\n";


# calculate number of days in each period
if($per==1) {
  # calc percentiles for just one period
  print "Calcing per for 1 period\n";
  @daycnt = ( Delta_Days($Syr, $Smon, 1, $Fyr, $Fmon, $Fday)+1 );
} else {
  if($per==2) {
  print "Calcing per for 2 periods\n";
  $S1 = $Syr . $Smon . "01";
  $S2 = DateCalc( $S1, "+1 months", 0 );
  print "Period 2 starts at $S2\n";

  ( $S2yr, $S2mon, $S2day ) = unpack "a4a2a2", $S2;
  # calc percentiles for 2 periods; first is one month long
  @daycnt = ( Delta_Days($Syr, $Smon, 1, $Syr, $Smon, Days_In_Month($Syr,$Smon))+1 ,
              Delta_Days($S2yr, $S2mon, $S2day, $Fyr, $Fmon, $Fday)+1 );
  } else {
    print "Quitting. Per is not 1 or 2\n";
    die "$0: ERROR: $0 program being used incorrectly.  found other than 1 or 2 periods worth of data in input files\n";
  }
}

#TEST
#@daycnt = qw(31 55);
print "Daycnt @daycnt\n";
#exit(0);
#TEST

# ===== monthly loop to read and write daily values, one period at a time ================
open(INF, "<$Fdlyamt") or die "$0: ERROR: Cannot open $Fdlyamt: $!\n";
open(OUT, ">$Frescale") or die "$0: ERROR: Cannot open $Frescale: $!\n";

for($per=0;$per<@daycnt;$per++) {

  print " Writing output for period $per...\n";
  # get one period worth of data
  @dly = @pertot = ();
#          print "PERTOT-c is $pertot[0]\n";
  for($d=0; $d<$daycnt[$per]; $d++) {
  print "reading period $per, day $d\n";
    $line = <INF>;  # read one line
    @tmp = split(" ",$line);
    for($c=0;$c<$cells;$c++) {
      $dly[$d][$c] = $tmp[$c];
#      if ( (defined($tmp[$c])) && (defined($pertot[$c]) ) ){

#      if ( defined($tmp[$c]) ){
        $pertot[$c] += $tmp[$c];  # for rescaling
#      } else {
        #print "INPUT LINE $line\n";
        if ( defined($tmp[$c])) {
          #print "TMP-c is $tmp[$c] \n";
        } else {
          print "TMP-c is undefined for cell $c \n";
        }

#        if ( defined($pertot[$c])) {
#          print "PERTOT-c is $pertot[$c]\n";
#        } else {
#          print "IN HERE PERTOT-c is undefined for cell $c\n";
#        }

#        print "Quitting because undef at day $d cell $c\n";
#        die "Quitting because undef value at day $d cell $c \n";
#      }
    }
  }

  # rescale, write out daily values
  for($d=0;$d<$daycnt[$per];$d++) {
    #print "writing period $per, day $d\n";
    for($c=0;$c<$cells;$c++) {
      if($pertot[$c]>0) {
        printf OUT "%.3f ", $dly[$d][$c]/$pertot[$c]*$peramt[$c][$per];
      } elsif($pertot[$c]==0) {
        printf OUT "%.1f ", 0.0;
      } else {  # negative pcp
        print "negative monthly total for cell $c, per $per\n";
        die "$0: ERROR: negative monthly total for cell $c, per $per\n";
      }
    }
    printf OUT "\n";
  }

} #end of period loop

print " --- $0 finished \n";

close(INF);
close(OUT);

print "--- $0 finished \n";


