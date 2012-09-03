#!/usr/bin/perl

# This script maps grid centers from a higher resolution (smaller cell size) to a lower resolution (larger cell size).

# Usage: cell_map_upscale.pl latlon_list min_lat max_lat min_lon max_lon new_res

# NOTE: this script does NOT work if your domain contains a discontinuity in lat/lon
# e.g. if you are numbering longitudes from 0 E to 360 E, and 0 E falls inside your domain;
#      or if you are numbering longs from -179 E to 180 E, and your domain straddles 180E/-179E

# Author: Ben Livneh (blivneh@hydro.washington.edu) and Ted Bohn (tbohn@hydro.washington.edu)
# Date: 2008-04-03

# Command-line arguments
$latlon_list = shift;  # Ascii file listing old (higher-resolution) grid cell centers in format LAT LON
$min_lat = shift;      # Southern boundary of new (lower-resolution) grid
$max_lat = shift;      # Northern boundary of new (lower-resolution) grid
$min_lon = shift;      # Western boundary of new (lower-resolution) grid
$max_lon = shift;      # Eastern boundary of new (lower-resolution) grid
$new_res = shift;      # Resolution of new grid (degrees)

# Compute nrows, ncols
$nrows = ($max_lat-$min_lat)/$new_res;
$ncols = ($max_lon-$min_lon)/$new_res;

# Read list of old grid centers
open (FILE, $latlon_list) or die "$0: ERROR: cannot open $latlon_list for reading\n";
foreach (<FILE>) {
  chomp;
  ($lat,$lon) = split /\s+/;
  push @old_lats, $lat;
  push @old_lons, $lon;
}

# Map old grid centers to new grid centers
for ($row = 0; $row < $nrows; $row++) {
  for ($col = 0; $col < $ncols; $col++) {
    $new_min_lat = $min_lat + $row*$new_res;
    $new_min_lon = $min_lon + $col*$new_res;
    $new_center_lat = $new_min_lat + 0.5*$new_res;
    $new_center_lon = $new_min_lon + 0.5*$new_res;
    for ($k=0; $k<@old_lats; $k++) {
      if ($old_lats[$k] > $new_min_lat && $old_lats[$k] <= $new_min_lat+$new_res
          && $old_lons[$k] > $new_min_lon && $old_lons[$k] <= $new_min_lon+$new_res) {
        printf "%.4f %.4f : %.4f %.4f\n", $new_center_lat, $new_center_lon, $old_lats[$k], $old_lons[$k];
      }
    }
  }
}
close(FILE);
