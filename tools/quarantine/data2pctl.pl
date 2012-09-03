#!/usr/bin/perl

$datafile = shift;
$ndateflds = shift; # Number of date fields on each line; these will be printed in the output file
                    # Specify 0 to have no date information in the output file
$collist = shift; # comma-separated list of data columns to add together
$dstrfile = shift;

@cols = split /,/, $collist;

# Read input data file
open(DATA, $datafile) or die "$0: ERROR: cannot open $datafile for reading\n";
foreach (<DATA>) {
  chomp;
  @fields = split /\s+/;
  $tmpdata = 0;
  if ($ndateflds) {
    $datestr = join " ", @fields[0..$ndateflds-1];
  }
  foreach $col (@cols) {
    $tmpdata += $fields[$col];
  }
  push @data, $tmpdata;
  push @date, $datestr;
}
close(DATA);
$nRecs = @data;

# Read distribution file
open(DIST, $dstrfile) or die "$0: ERROR: cannot open $dstrfile for reading\n";
foreach (<DIST>) {
  chomp;
  push @dist;
}
close(DIST);
$nDist = @dist;

# Convert data values to percentiles of the distribution
for ($i=0; $i<$nRecs; $i++) {
  $found = 0;
  for ($j=0; $j<$nDist; $j++) {
    if ($data[$i] <= $dist[$j]) {
      $found = 1;
      if ($j == 0) {
        $data[$i] = 0;
      }
      else {
        $data[$i] = ( $j-1 + ($data[$i] - $dist[$j-1])/($dist[$j] - $dist[$j-1]) ) / $nDist;
      }
    }
  }
  if (!$found) {
    $data[$i] = 1;
  }

  if ($ndateflds) {
    printf "%s %.4f\n", $date[$i], $data[$i];
  }
  else {
    printf "%.4f\n", $data[$i];
  }

}
