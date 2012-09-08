#!/usr/bin/env perl
use warnings;
# AWW-112103

# take a SORTED row of data and find interpolated weibull plotting
# position of an input value in it, assigning fixed value when it is 
# beyond the bounds of the column.  program stops if not all rows have
# have same number of columns as first row.  also find additive & multiplicative
# anomalies wrt mean of distribution.

# usage
# input fmt:  each row of tabular file has
#  <target val> <sorted distribution vals, lowest to highest>
# output fmt: each row has
#  <percentile><additive anom><multiplicative anom>

use lib "/usr/lib/perl5/site_perl/5.6.1";
use Statistics::Lite ("mean");

# read in filenames
if(@ARGV != 2) {
  print @ARGV . " arguments found\n";
  die "Usage: fcst_stats.pl <infile> <outfile>\n";
}

# open files
open(INF, "<$ARGV[0]") or die "Can't open $ARGV[0]: $!\n";
print "reading $ARGV[0] \nwriting $ARGV[1]\n";
open(OUT, ">$ARGV[1]") or die "Can't open $ARGV[1]: $!\n";

$r=0;  # counter
@tmp = ();
while ($line = <INF>) {
  # process first row
  ($targ[$r], @tmp) = split(" ", $line);
  if($r==0) {
    $NDIST = @tmp;  # number in distribution
    $min_p = 1/($NDIST+1)*0.5;  # def. p-val for targ below dist
    $max_p = $NDIST/($NDIST+1) + $min_p;  # ditto for above dist
    print "climatology distribution has $NDIST elements\n";
  } else {
    if($NDIST != @tmp) {
      $ntmp = @tmp;
      $rowtmp = $r+1;
      die "Input file not a regular table:\nRow $rowtmp distribution has $ntmp instead of $NDIST values\n";
    }
  }

  # get stats for current row
  $distmean[$r] = mean @tmp;
  $add_anom[$r] = $targ[$r]-$distmean[$r];

  if($distmean[$r] == 0) {
    $mult_anom[$r] = $weib[$r] = -9999;

  } else {
    # mult anom
    $mult_anom[$r] = ($targ[$r]/$distmean[$r]-1)*100;

    # percentiles
    $i=0;
    while($i < $NDIST) {
      if($tmp[$i]>=$targ[$r] && $i==0) {
        $weib[$r] = $min_p;
        last;
      } elsif ($tmp[$i]<=$targ[$r] && $i==$NDIST-1) {
        $weib[$r] = $max_p;
        last;
      } elsif ($tmp[$i]>=$targ[$r]) {
        # note, i as counter in weib eq. must start at 1 not 0
        # whereas in arrays, starts at 0
        $weib[$r] = ($targ[$r]-$tmp[$i-1]) / ($tmp[$i]-$tmp[$i-1]) *
          (($i+1)/($NDIST+1) - $i/($NDIST+1)) + $i/($NDIST+1);
        last;
      }
    $i++;
    }  # done calc'ing percentiles
  }  # end if non-zero mean case

  $r++;  # increment row

} # done reading data file
close(INF);
print "processed $r rows\n";

# Make sure stats are reasonable
$min_count = 0;
$max_count = 0;
for($row=0;$row<$r;$row++) {
  if ($weib[$row] == $min_p) {
    $min_count++;
  }
  elsif ($weib[$row] == $max_p) {
    $max_count++;
  }
}
if ($min_count + $max_count == $r) {
  die "$0: ERROR: data in file $ARGV[0] consist only of extreme values\n";
}

# Write out stats
for($row=0;$row<$r;$row++) {
  printf OUT "%.2f %.2f %.1f %.1f %.3f\n", 
  $targ[$row], $distmean[$row], $add_anom[$row],$mult_anom[$row],$weib[$row];
}
close(OUT);
