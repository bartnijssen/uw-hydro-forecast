#!/usr/bin/perl -w
# AWW-12-29-02
# calculate anomalies from values given precalculated means
# inputs:  .fmt file with values in same column order as
#        .info/.xyz type file with desired averages to remove
# outputs: .fmt file with anomalies

# AWW-103103:  using percentile method for precip - anomaly for temps only
#              expanding to use for 5 basins
# AWW-052604:  changed station list to remove a station
# AWW-1104:  updated to just deal with one basin, and run automatically

# command-line arguments
$tx_fmt = shift;
$tn_fmt = shift;
$avgs = shift;
$Void = shift;
$tx_anom = shift;
$tn_anom = shift;

print "========";
print "INSIDE $0\n";
print "AVGS file is $avgs\n";
print "Void is $Void\n";

open(TXFMT, "<$tx_fmt") or die "$0: ERROR: Cannot open $tx_fmt: $!\n";
open(TNFMT, "<$tn_fmt") or die "$0: ERROR: Cannot open $tn_fmt: $!\n";
open(AVGS, "<$avgs") or die "$0: ERROR: Cannot open $avgs: $!\n";
open(TXANOM, ">$tx_anom") or die "$0: ERROR: Cannot open $tx_anom: $!\n";
open(TNANOM, ">$tn_anom") or die "$0: ERROR: Cannot open $tn_anom: $!\n";

# read in data
print "reading value .fmt files\n";
$c=0;

while (<TXFMT>) {
  @tmp = split;
  for($s=0;$s<@tmp;$s++) {
    $tx[$c][$s] = $tmp[$s];
  }

  $line= <TNFMT>;
  @tmp = split(" ",$line);
  for($s=0;$s<@tmp;$s++) {
    $tn[$c][$s] = $tmp[$s];
  }
  $c++;
}
close(TXFMT);
close(TNFMT);
$recs=$c;

# read averages ---------------------------------------
$s=0;
while (<AVGS>) {
  ($name[$s],$junk,$txavg[$s],$tnavg[$s]) = split;
  $s++;
}
close(AVGS);
$junk = 0;  # just to avoid the warning message, while keeping -w

# write out anomaly .fmt files, handling voids
print "writing anomaly files\n";
for($c=0;$c<$recs;$c++) {
  for($s=0;$s<@name;$s++) {
    if($tx[$c][$s] != $Void && $tn[$c][$s] != $Void && $txavg[$s] != $Void && $tnavg[$s] != $Void ) {
      printf TXANOM "%.3f ",$tx[$c][$s]-$txavg[$s];
      printf TNANOM "%.3f ",$tn[$c][$s]-$tnavg[$s];

      if($tx[$c][$s]-$txavg[$s]<-100 || $tn[$c][$s]-$tnavg[$s]<-100){
        $TXA = $tx[$c][$s]- $txavg[$s];
        $TNA = $tn[$c][$s]- $tnavg[$s];
	print "Achtung! Vals are $TXA $TNA for station $name[$s] - changing to void\n";
        print "  RAW TX is $tx[$c][$s] and TN is $tn[$c][$s]\n";
        print "  AVG TX is $txavg[$s] and TN is $tnavg[$s]\n";
        printf TXANOM "%.1f ",$Void;
        printf TNANOM "%.1f ",$Void;
      }
    } else {
      printf TXANOM "%.1f ",$Void;
      printf TNANOM "%.1f ",$Void;
    }
  }
  printf TXANOM "\n";
  printf TNANOM "\n";
}

close(TXANOM);
close(TNANOM);
