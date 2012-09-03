#!/usr/bin/perl

# This script converts monthly timeseries data to percentiles with respect to
# monthly distributions.

$datafile = shift; # ascii timeseries (YYYY MM data1 data2 data3...)
$collist = shift; # comma-separated list of data columns to add together
$dstrfilelist = shift; # comma-separated list of monthly distribution files

@cols = split /,/, $collist;
@dstr_files = split /,/, $dstrfilelist;
if (@dstr_files != 12) {
  die "$0: ERROR: there must be 12 monthly distribution files\n";
}

# Read input data file
open(DATA, $datafile) or die "$0: ERROR: cannot open $datafile for reading\n";
foreach (<DATA>) {
  chomp;
  @fields = split /\s+/;
  push @year, $fields[0];
  push @month, $fields[1];
  $tmpdata = 0;
  foreach $col (@cols) {
    $tmpdata += $fields[$col];
  }
  push @data, $tmpdata;
}
close(DATA);
$nRecs = @data;

# Read distribution files
for ($mon=0; $mon<12; $mon++) {
  open(DIST, $dstr_files[$mon]) or die "$0: ERROR: cannot open $dstr_files[$mon] for reading\n";
  foreach (<DIST>) {
    chomp;
    push @{$dist[$mon]}, $_;
  }
  close(DIST);
  $nDist = @{$dist[$mon]};
}

# Convert data values to percentiles of the distribution
for ($i=0; $i<$nRecs; $i++) {
  $found = 0;
  DIST_LOOP: for ($j=0; $j<$nDist; $j++) {
    if ($data[$i] <= $dist[$month[$i]-1][$j]) {
      $found = 1;
      if ($j == 0) {
        $data[$i] = 0;
      }
      else {
        $data[$i] = ( $j-1 + ($data[$i] - $dist[$month[$i]-1][$j-1])/($dist[$month[$i]-1][$j] - $dist[$month[$i]-1][$j-1]) ) / $nDist;
      }
      last DIST_LOOP;
    }
  }
  if (!$found) {
    $data[$i] = 1;
  }

  printf "%04d %02d %.4f\n", $year[$i], $month[$i], $data[$i];

}
