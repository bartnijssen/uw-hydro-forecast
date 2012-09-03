#!/usr/bin/perl -w

# This script assumes daily data

# Command-line arguments
$ResultsDir = shift;
$prefix = shift;
$col_list = shift; # comma-separated list of fields; these will be summed
$thresh = shift; # threshold value for inclusion in distribution
$nodata = shift; # value to represent missing or invalid data (typically set to -99)
$width = shift;  # window width (in days); should be an odd number
$PctlDir = shift;
$prefix_out = shift;

@cols = split /,/, $col_list;

$days_in_non_leap_year = 365;

# Loop over files in ResultsDir
opendir (RESULTS, "$ResultsDir") or die "$0: ERROR: cannot open $ResultsDir for reading\n";
@filelist = grep /^$prefix/, readdir(RESULTS);
closedir(RESULTS);
$f = 0;
foreach $file (@filelist) {
print "$file\n";

  # Read results file
  open (FILE, "$ResultsDir/$file") or die "$0: ERROR: cannot open $ResultsDir/$file for reading\n";
  @data = ();
  @year = ();
  @month = ();
  @day = ();
  $i = 0;
  foreach (<FILE>) {
    chomp;
    @fields = split /\s+/;
    ($year[$i],$month[$i],$day[$i]) = @fields[0..2];
    $data[$i] = 0;
    foreach $col (@cols) {
      $data[$i] += $fields[$col];
    }
    if ($data[$i] < $thresh) {
      $data[$i] = $nodata;
    }
#print "$i $year[$i] $month[$i] $day[$i] $data[$i]\n";
    $i++;
  }
  close(FILE);
  $nRecs = $i;

  # Open output file
  $outfile = $file;
  $outfile =~ s/^$prefix/$prefix_out/;
  open (OUTF, ">$PctlDir/$outfile") or die "$0: ERROR: cannot open $PctlDir/$outfile for writing\n";

  # Compute number of years contained in time series
  $nYears = int ($nRecs / 365.25);

  # For all 365 days, construct sorted distribution of data values occurring within the window centered on that day
  @distrib = ();
  @distrib_sorted = ();
  for ($j=0; $j<365; $j++) {

    # Figure out which days of the year are in the window
    @days_to_get = ();
    for ($i=-int($width/2); $i<int($width/2)+1; $i++) {
      $day = $j+$i;
      if ($day < 0) {
        $day += 365;
      }
      elsif ($day >= 365) {
        $day -= 365;
      }
      push @days_to_get, $day; 
    }

    # Grab the days in the window from each year (adjusting for leap years)
#$i = 0;
    $count = 0;
    for ($y=$year[0]; $y<$year[0]+$nYears; $y++) {
      if ($y % 4 == 0) {
        $leap = 1;
      }
      else {
        $leap = 0;
      }
      foreach $day (@days_to_get) {
	$day_adj = $day;
        if ($leap && $day >= 60) {
	  $day_adj--;
	}
        push @{$distrib[$j]}, $data[$count+$day_adj];
#printf "%d %d %d %d %f %f\n", $i, $day_adj, $count, $count+$day_adj, $data[$count+$day_adj], $distrib[$j][$i];
#$i++;
      }
      $days_in_year = 365;
      if ($leap) {
        $days_in_year++;
      }
      $count += $days_in_year;
    }

    # Sort the distribution
#print "@{$distrib[$j]}\n";
#exit;
    @{$distrib_sorted[$j]} = sort numer @{$distrib[$j]};
#print "@{$distrib_sorted[$j]}\n";
#exit;
    @tmp = ();
    foreach $val (@{$distrib_sorted[$j]}) {
      if ($val != $nodata) {
        push @tmp, $val;
      }
    }
    @{$distrib_sorted[$j]} = @tmp;
    $nDist[$j] = @{$distrib_sorted[$j]};
  }

  # For each day in the time series, compute its percentile with respect to the sorted distribution & write to output file
  $count = 0;
  for ($i=0; $i<$nRecs; $i++) {

    # Compute day of year
    $day_of_year = $i-$count;
    if ($year[$i] % 4 == 0) {
      $leap = 1;
    }
    else {
      $leap = 0;
    }
    if ($leap && $day_of_year >= 59) {
      $day_of_year--;
    }

    $days_in_year = $days_in_non_leap_year;
    if ($leap) {
      $days_in_year++;
    }

    # Compare this day's data value with the distribution
    $min_p = 0.5*1/($nDist[$day_of_year]+1);
    $max_p = $min_p + $nDist[$day_of_year]/($nDist[$day_of_year]+1);
    COMPUTE_LOOP: for ($y=0; $y<$nDist[$day_of_year]; $y++) {
#print "i $i year $year[$i] count $count leap $leap day $day_of_year dist_idx $y days_in_year $days_in_year distrib $distrib_sorted[$day_of_year][$y] $data[$i]\n";
      if ($data[$i] < $thresh) {
        $pctl = $nodata;
      }
      elsif ($y == 0 && $data[$i] <= $distrib_sorted[$day_of_year][$y]) {
        $pctl = $min_p;
#print "i $i year $year[$i] day $day_of_year dist_idx $y days_in_year $days_in_year data $data[$i] pctl $pctl (low)\n";
	last COMPUTE_LOOP;
      }
      elsif ($y == $nDist[$day_of_year]-1 && $data[$i] >= $distrib_sorted[$day_of_year][$y]) {
        $pctl = $max_p;
#print "i $i year $year[$i] day $day_of_year dist_idx $y days_in_year $days_in_year data $data[$i] pctl $pctl (high)\n";
	last COMPUTE_LOOP;
      }
      elsif ($data[$i] <= $distrib_sorted[$day_of_year][$y]) {
        $pctl = ($data[$i]-$distrib_sorted[$day_of_year][$y-1])/($distrib_sorted[$day_of_year][$y]-$distrib_sorted[$day_of_year][$y-1]) / ($nDist[$day_of_year]+1) + $y / ($nDist[$day_of_year]+1);
#print "i $i year $year[$i] day $day_of_year dist_idx $y days_in_year $days_in_year data $data[$i] pctl $pctl\n";
	last COMPUTE_LOOP;
      }
    }

    # Write to output file
    printf OUTF "%04d %02d %02d %.4f\n", $year[$i], $month[$i], $day[$i], $pctl;

    # Increment base day count
    if ($day_of_year == $days_in_non_leap_year-1) {
      $count += $days_in_year;
    }
  }

  # Close the output file
  close(OUTF);
  $f++;
#  if ($f == 100) {
#    exit;
#  }

}

sub numer { $a <=> $b; }
