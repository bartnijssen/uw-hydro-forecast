#!/usr/bin/perl

## CREAT MASK FILE FROM VIC SOIL FILE
## INPUTS ARE VIC SOIL FILE, RESOLUTION OF SOIL FILE, AND OUTPUT FILE NAME
## AUTHOR: B.LIVNEH

$vic_soil = shift;
$res = shift;
$outfile = shift;
$no_data = 0;
$data = 1;

## Compute min and max, lat and lon from VIC soil file, then make horizontal
## passes from NW to SE and create a mask
$min_lat = 90;
$max_lat = -90;
$min_lon = 180;
$max_lon = -180;
$n_cols = 0;
$nrows = 0;
$cell_found = 0;

open(SOIL0, $vic_soil);

foreach $line0 (<SOIL0>) {
  chomp $line0;
  $line0 =~ s/^\s+//;
  @column0 = split /\s+/, $line0;
  if ($column0[2] < $min_lat) {
    $min_lat = $column0[2];
  }
  if ($column0[2] > $max_lat) {
    $max_lat = $column0[2];
  }
  if ($column0[3] < $min_lon) {
    $min_lon = $column0[3];
  }
  if ($column0[3] > $max_lon) {
    $max_lon = $column0[3];
  }
}

close(SOIL);

printf STDOUT "%.4f %.4f %.4f %.4f \n", $min_lat, $max_lat, $min_lon, $max_lon;

$ncols = ($max_lon - $min_lon)/$res;
$nrows = ($max_lat - $min_lat)/$res;

open(OUTFILE, ">$outfile");
printf OUTFILE "NCOLS           $ncols \n";
printf OUTFILE "NROWS           $nrows \n";
printf OUTFILE "XLLCORNER       $min_lon \n";
printf OUTFILE "YLLCORNER       $min_lat \n";
printf OUTFILE "cellsize        $res \n";
printf OUTFILE "NODATA_value    $no_data \n";

$lat = 0;
$lon = 0;


for ($i = 0; $i <= $nrows; $i++) {
  for ($j = 0; $j <= $ncols; $j++) {
    $lat = $max_lat - $i*$res;
    $lon = $min_lon + $j*$res;
    print "$lat $lon \n";
    $cell_found = 0;
    open(SOIL, $vic_soil);
    foreach $line (<SOIL>) {
      chomp $line;
      $line =~ s/^\s+//;
      @column = split /\s+/, $line;
      if (($column[2] == $lat)&&($column[3] == $lon)) {
	printf OUTFILE "%d ", $data;
	$cell_found = 1;
      }
    }
    close(SOIL);
    if ($cell_found == 0) {
      printf OUTFILE "%d ", $no_data;
    }
    if ($j == $ncols) {
      printf OUTFILE "\n";
    }
  }
} 
