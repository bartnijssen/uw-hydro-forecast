#!/usr/bin/perl

# This script converts daily timeseries data to percentiles with respect to
# monthly distributions.

$datafile = shift;# ascii daily timeseries data (YYYY MM DD data1 data2 data3...)
$collist = shift; # comma-separated list of data columns to add together
$dstrfilelist = shift; # comma-separated list of monthly distribution files
$morph = shift;   # 1 = for each day, the reference distribution is an
                  #     interpolation between the monthly distributions
		  #     ahead and behind the current day, assuming the
		  #     distributions are centered on day 15 of each month
		  #     (i.e. "morphing" between the two distributions)
		  # 0 = no morphing; just use distribution corresponding to current month

@cols = split /,/, $collist;
@dstr_files = split /,/, $dstrfilelist;
if (@dstr_files != 12) {
  die "$0: ERROR: there must be 12 monthly distribution files\n";
}

@month_days = (31,28,31,30,31,30,31,31,30,31,30,31);

# Read input data file
open(DATA, $datafile) or die "$0: ERROR: cannot open $datafile for reading\n";
foreach (<DATA>) {
  chomp;
  @fields = split /\s+/;
  push @year, $fields[0];
  push @month, $fields[1];
  push @day, $fields[2];
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
  $midx = $month[$i]-1;

  # Determine which distribution to use
  if ($morph) {
    # Reference distribution is interpolated between month ahead and month behind
    if ($day[$i] <= 15) {
      $midx1 = $midx-1;
      if ($midx1 < 0) {
        $midx1 = 11;
      }
      $midx2 = $midx;
      $w1 = (15-$day[$i])/$month_days[$midx1];
#      $w2 = $day[$i]/$month_days[$midx1] + ($month_days[$midx2]-15)/$month_days[$midx2];
      $w2 = 1-$w1;
    }
    else {
      $midx1 = $midx;
      $midx2 = $midx+1;
      if ($midx2 > 11) {
        $midx2 = 0;
      }
#      $w1 = ($month_days[$midx1]-$day[$i])/$month_days[$midx1] + 15/$month_days[$midx2];
      $w2 = ($day[$i]-15)/$month_days[$midx1];
      $w1 = 1-$w2;
    }
    for ($j=0; $j<$nDist; $j++) {
      $this_dist[$j] = $w1*$dist[$midx1][$j] + $w2*$dist[$midx2][$j];
    }
  }
  else {
    # Reference distribution is that of current month
    @this_dist = @{$dist[$midx]};
  }

  # Find position of data (= percentile) within current distribution
  $found = 0;
  DIST_LOOP: for ($j=0; $j<$nDist; $j++) {
    if ($data[$i] <= $this_dist[$j]) {
      $found = 1;
      if ($j == 0) {
        $data[$i] = 0;
      }
      else {
        $data[$i] = ( $j-1 + ($data[$i] - $this_dist[$j-1])/($this_dist[$j] - $this_dist[$j-1]) ) / $nDist;
      }
      last DIST_LOOP;
    }
  }
  if (!$found) {
    $data[$i] = 1;
  }

  # Write output
  printf "%04d %02d %02d %.4f\n", $year[$i], $month[$i], $day[$i], $data[$i];

}
