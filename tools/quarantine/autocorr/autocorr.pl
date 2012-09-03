#!/usr/bin/perl

# This script finds the autocorrelation of a time series, taken from a specified column of an ascii file.

# Command-line arguments
$file = shift;   # File name
$col = shift;    # Column to analyze (indexing starts at 0)
$maxlag = shift; # Maximum lag to analyze

# Read file
@data = ();
open(FILE, $file) or die "$0: ERROR: cannot open $file for reading\n";
foreach (<FILE>) {
  @fields = split /\s+/;
  push @data, $fields[$col];
}
close(FILE);

$nRecs = @data;

# Compute autocorrelation at lags
for ($lag=0; $lag<=$maxlag; $lag++) {
  # Means
  $mean1 = 0;
  $mean2 = 0;
  for ($i=0; $i<$nRecs-$lag; $i++) {
    $mean1 += $data[$i];
    $mean2 += $data[$i+$lag];
  }
  $mean1 /= $nRecs-$lag;
  $mean2 /= $nRecs-$lag;
  # Anomalies
  for ($i=0; $i<$nRecs-$lag; $i++) {
    $anom1[$i] = $data[$i]-$mean1;
    $anom2[$i] = $data[$i+$lag]-$mean2;
  }
  # Multiplicative terms
  $covar = 0;
  $var1 = 0;
  $var2 = 0;
  for ($i=0; $i<$nRecs-$lag; $i++) {
    $covar += $anom1[$i]*$anom2[$i];
    $var1 += $anom1[$i]*$anom1[$i];
    $var2 += $anom2[$i]*$anom2[$i];
  }
  $autocorr = $covar/sqrt($var1*$var2);
  printf "%.4f\n", $autocorr;
}

