#!/usr/bin/perl

# This script computes the average of results (expressed as quantiles of climatology)
# from different models for all points in space.

# Get command-line arguments
$PROJECT = shift;
$MODEL_LIST = shift;
$DATESTR = shift;

# Constants
$ROOT_DIR = "/raid8/forecast/sw_monitor";
@month_days = (31,28,31,30,31,30,31,31,30,31,30,31);

# Derived global variables
$PROJECT_UC = $PROJECT;
$PROJECT =~ tr/A-Z/a-z/;
$PROJECT_UC =~ tr/a-z/A-Z/;
@models = split /,/, $MODEL_LIST;
$nmodels = @models;
$DATA_DIR = "$ROOT_DIR/data/$PROJECT/spatial/xyzz.all/$DATESTR";
$DIST_DIR = "$ROOT_DIR/data/$PROJECT/results/retro/multimodel/monthly/asc_distrib";
if ($DATESTR =~ /^\d\d\d\d(\d\d)(\d\d)$/) {
  ($monthstr,$daystr) = ($1,$2);
  $fmonth = $monthstr * 1;
  $fday = $daystr * 1;
}
else {
  die "$0: ERROR: cannot parse month from the date string $DATESTR\n";
}

# Set of variables to process
#@varnames = ("sm","swe","stot");
@varnames = ("sm");

# Determine weights for interpolating monthly distributions
$midx = $fmonth-1;  # index of month in @month_days
if ($fday <= 15) {
  $midx1 = $midx-1;
  if ($midx1 < 0) {
    $midx1 = 11;
  }
  $midx2 = $midx;
  $w1 = (15-$fday)/$month_days[$midx1];
#    $w2 = $fday/$month_days[$midx1] + ($month_days[$midx2]-15)/$month_days[$midx2];
    $w2 = 1-$w1;
}
else {
  $midx1 = $midx;
  $midx2 = $midx+1;
  if ($midx2 > 11) {
    $midx2 = 0;
  }
#  $w1 = ($month_days[$midx1]-$fday)/$month_days[$midx1] + 15/$month_days[$midx2];
  $w2 = ($fday-15)/$month_days[$midx1];
  $w1 = 1-$w2;
}

foreach $varname (@varnames) {

  # Average the model percentiles for current day
  ($mmavg_ref,$lat_ref,$lon_ref) = &avg_model_pctls($varname);
  @mmavg = @{$mmavg_ref};
  @lat = @{$lat_ref};
  @lon = @{$lon_ref};
  $NCELLS = @mmavg;

  # Convert multi-model average into percentile vs the historical distribution of multimodel averages
  $mmavg_ref = &normalize_v_historic($varname, $mmavg_ref, $lat_ref, $lon_ref, $midx1, $midx2);
  @mmavg = @{$mmavg_ref};

  # Write the data
  $outfile = "$DATA_DIR/$varname.$PROJECT_UC.multimodel.f-c_mean.a-m_anom.qnt.xyzz";
  open (OUTFILE, ">$outfile") or die "$0: ERROR: cannot open file $outfile for writing\n";
  for ($i=0; $i<$NCELLS; $i++) {
    print OUTFILE "$lon[$i] $lat[$i] -9999 -9999 -9999 -9999 $mmavg[$i]\n";
  }
  close(OUTFILE);

}


sub avg_model_pctls {

  my $varname = shift;
  my $model;
  my $datafile;
  my @lat;
  my @lon;
  my $cell;
  my @fields;
  my @mmavg;

  # For each model, open its xyzz.all file for the current forecast
  # and add to running total of data
  @lat = ();
  @lon = ();
  @mmavg = ();
  foreach $model (@models) {
    $datafile = "$DATA_DIR/$varname.$PROJECT_UC.$model.f-c_mean.a-m_anom.qnt.xyzz";
    open (DATAFILE, $datafile) or die "$0: ERROR: cannot open file $datafile for reading\n";
    $cell = 0;
    foreach (<DATAFILE>) {
      chomp;
      @fields = split /\s+/;
      ($lon[$cell],$lat[$cell]) = @fields[0..1];
      $mmavg[$cell] += $fields[6];
      $cell++;
    }
    close(DATAFILE);
  }

  # Finish averaging the data
  foreach (@mmavg) {
    $_ /= $nmodels;
    $_ = sprintf "%.3f", $_;
  }

  return (\@mmavg,\@lat,\@lon);

}


sub normalize_v_historic {

  my $varname = shift;
  my $mmavg_ref = shift;
  my $lat_ref = shift;
  my $lon_ref = shift;
  my $midx1 = shift;
  my $midx2 = shift;

  my $monthstr1, $monthstr2;
  my $i, $j;
  my $distfile;
  my @mmavg = @{$mmavg_ref};
  my @dist1, @dist2, @dist;
  my $nDist;
  my $found;

  # We will approximate the distribution of 30-day average soil moistures
  # centered on the current day by taking a weighted average of the
  # monthly distributions for the two months that fall within the 30-day
  # window centered on the current day.

  # Read the distributions for month ahead and month behind
  $monthstr1 = sprintf "%02d", $midx1+1;
  $monthstr2 = sprintf "%02d", $midx2+1;
  for ($i=0; $i<$NCELLS; $i++) {
    $distfile = $DIST_DIR . "/mon" . $monthstr1 . "/" . $varname . "dstr_" . $lat[$i] . "_" . $lon[$i];
    open (DISTFILE, $distfile) or die "$0: ERROR: cannot open $distfile for reading\n";
    @dist1 = (<DISTFILE>);
    close(DISTFILE);
    $distfile = $DIST_DIR . "/mon" . $monthstr2 . "/" . $varname . "dstr_" . $lat[$i] . "_" . $lon[$i];
    open (DISTFILE, $distfile) or die "$0: ERROR: cannot open $distfile for reading\n";
    @dist2 = (<DISTFILE>);
    close(DISTFILE);
    $nDist = @dist1;
    # Form weighted average of the two distributions
    for ($j=0; $j<$nDist; $j++) {
      $dist[$j] = $w1*$dist1[$j] + $w2*$dist2[$j];
    }
    # Express multi-model average as percentile of the new distribution
    $found = 0;
    DIST_LOOP: for ($j=0; $j<$nDist; $j++) {
      if ($mmavg[$i] <= $dist[$j]) {
        $found = 1;
        if ($j == 0) {
          $mmavg[$i] = 0;
        }
        else {
          $mmavg[$i] = ( $j-1 + ($mmavg[$i] - $dist[$j-1])/($dist[$j] - $dist[$j-1]) ) / $nDist;
        }
        last DIST_LOOP;
      }
    }
    if (!$found) {
      $mmavg[$i] = 1;
    }
    $mmavg[$i] = sprintf "%.3f", $mmavg[$i];
  }

  return \@mmavg;

}


