#!/usr/bin/perl

# Command-line arguments
$soilfile = shift; # VIC soil param file at old (fine) resolution
$infile = shift; # parameter file whose records will be aggregated
$min_lat = shift;
$max_lat = shift;
$min_lon = shift;
$max_lon = shift;
$new_res = shift;
$outfile = shift; # output (aggregated) parameter file

# Make list of lat/lons
open(SOIL, $soilfile) or die "$0: ERROR: cannot open soil file $soilfile for reading\n";
$latlonfile = "./latlonlist.txt";
open (LATLON, ">$latlonfile") or die "$0: ERROR: cannot open $latlonfile for writing\n";
foreach (<SOIL>) {
  @fields = split /\s+/;
  ($lat,$lon) = @fields[2..3];
  print LATLON "$lat $lon\n";
}
close(LATLON);
close(SOIL);

# Feed lat/lon list to cell_map_upscale.pl to get mapping
$newlatlonfile = "./latlonlist.new.txt";
$cmd = "cell_map_upscale.pl $latlonfile $min_lat $max_lat $min_lon $max_lon $new_res > $newlatlonfile";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

# Feed mapping file and parameter file to the averaging script
$cmd = "avg_param_records.pl $infile $newlatlonfile > $outfile";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

