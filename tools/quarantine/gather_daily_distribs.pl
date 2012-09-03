#!/usr/bin/perl -w

# This script assumes daily data

# Command-line arguments
$filelist = shift;
$model = shift;
$ResultsDir = shift;
#$prefix = shift;
$col_list = shift; # comma-separated list of fields; these will be summed
##########$thresh = shift; # threshold value for inclusion in distribution
##########$nodata = shift; # value to represent missing or invalid data (typically set to -99)
$DistribDir = shift;
$prefix_out = shift;

@cols = split /,/, $col_list;

#$days_in_non_leap_year = 365;

# Get list of files to process
open(FLIST, $filelist) or die "$0: ERROR: cannot open $filelist for reading\n";
foreach (<FLIST>) {
  chomp;
  if ($model !~ /vic/i) {
    s/fluxes/wb/g;
  }
  push @flist, $_;
}
close(FLIST);
#opendir (RESULTS, "$ResultsDir") or die "$0: ERROR: cannot open $ResultsDir for reading\n";
#@flist = grep /^$prefix/, readdir(RESULTS);
#closedir(RESULTS);

# Loop over files in filelist
$first_cell = 1;
foreach $file (@flist) {
#print "$file\n";

  # Read results file
  open (FILE, "$ResultsDir/$file") or die "$0: ERROR: cannot open $ResultsDir/$file for reading\n";
  @data = ();
  $day_of_year = 1; # Assume file starts at the beginning of a year
  $nYears = 0;
  FILE_LOOP: foreach (<FILE>) {

    chomp;
    @fields = split /\s+/;
    ($year,$month,$day) = @fields[0..2];

    # Skip Feb 29 of leap years; otherwise store data
    if ($year % 4 == 0 && $month*1 == 2 && $day*1 == 29) {
      next FILE_LOOP;
    }
    else {
      $data[$day_of_year-1][$nYears] = 0;
      foreach $col (@cols) {
        $data[$day_of_year-1][$nYears] += $fields[$col];
      }
#      if ($data[$day_of_year-1][$nYears] < $thresh) {
#        $data[$day_of_year-1][$nYears] = $nodata;
#      }
    }

    # Increment day of year
    $day_of_year++;
    if ($day_of_year > 365) {
      $day_of_year -= 365;
      $nYears++;
    }

  }
  close(FILE);

  # Write distribution to files corresponding to day of year
  for ($i=0; $i<365; $i++) {
    $filename = sprintf "%s.%03d.txt", $prefix_out, $i+1;
    if ($first_cell) {
      open(OUTF, ">$DistribDir/$filename") or die "$0: ERROR: cannot open $DistribDir/$filename for writing\n";
    }
    else {
      open(OUTF, ">>$DistribDir/$filename") or die "$0: ERROR: cannot open $DistribDir/$filename for appending\n";
    }
    printf OUTF "%.4f", $data[$i][0];
    for ($j=1; $j<$nYears; $j++) {
      printf OUTF " %.4f", $data[$i][$j];
    }
    printf OUTF "\n";
    close(OUTF);
  }
  $first_cell = 0;

}
