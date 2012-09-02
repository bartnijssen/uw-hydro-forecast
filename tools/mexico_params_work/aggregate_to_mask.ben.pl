#!/usr/bin/perl

## Read in arc info data from a specified resolution (assume global data set
## starting from NW corner, lat lon.  Map these values to the
## desired resolution of the mask file

$maskfile = shift;
$datafile = shift;
$data_res = shift;
$outfile = shift;
$line_count = 0;
$n_cols = 0;
$nrows = 0;
$xllcorner = 0;
$yllcorner = 0;
$mask_row = 0;
$mask_lat = 0;
$mask_lon = 0;
$no_data = -99;

open(OUTFILE,">$outfile");

## Open mask file, read in the geometry to make horizontal passes through it


open(MASK,$maskfile);
foreach $line1 (<MASK>) {
  chomp $line1;
  $line1 =~ s/^\s+//;
  @column1 = split /\s+/, $line1;
  $line_count++;
  if ($line_count == 1) {
    $ncols = $column1[1];
    printf OUTFILE "NCOLS           $ncols \n";
  }
  elsif ($line_count == 2) {
    $nrows = $column1[1];
    printf OUTFILE "NROWS           $nrows \n";
  }
  elsif ($line_count == 3) {
    $xllcorner = $column1[1];
    printf OUTFILE "XLLCORNER       $xllcorner \n";
  }
  elsif ($line_count == 4) {
    $yllcorner = $column1[1];
    printf OUTFILE "YLLCORNER       $yllcorner \n";
  }
  elsif ($line_count == 5) {
    $mask_res = $column1[1];
    printf OUTFILE "cellsize        $mask_res \n";
  }
  elsif ($line_count == 6) {
    $mask_no_data = $column1[1];
    printf OUTFILE "NODATA          $no_data \n";
  }
  else {
    $mask_row = $line_count - 6;
    for ($i = 0; $i <= $#column1; $i++) {
      $mask_lat = $yllcorner + ($nrows - $mask_row)*$mask_res + $mask_res/2;
      $mask_lon = $xllcorner + $i*$mask_res + $mask_res/2;
      if ($column1[$i] == 1) {
#	print "$mask_lat $mask_lon \n";
	open(DATA,$datafile);
	$cells_contained = 0;
	$acc_value = 0;
	$data_row = 0;
	foreach $line2 (<DATA>) {
	  chomp $line2;
	  $line2 =~ s/^\s+//;
	  @column2 = split /\s+/, $line2;
	  $data_lat = 90 - ($data_res/2) - ($data_row*$data_res);
	  for ($j = 0; $j <= $#column2; $j++) {
	    $data_lon = -180 + ($data_res/2) + ($j*$data_res);
	    if (($data_lat <= ($mask_lat + ($mask_res/2)))&&($data_lat > ($mask_lat - ($mask_res/2)))&&($data_lon <= ($mask_lon + ($mask_res/2)))&&($data_lon > ($mask_lon - ($mask_res/2)))){
	      if ($column2[$j] != -99) {
		$cells_contained++;
		$acc_value += $column2[$j];
		print "-> $data_lat $data_lon $cells_contained $acc_value \n";
	      }
	    }
	  }
	  $data_row++;
	}
	close(DATA);
	if ($cells_contained == 0) {
	  print "No contained cells $mask_lat $mask_lon \n";
	  printf OUTFILE "%.2f ", $no_data;
	}
	else{
	  printf OUTFILE "%.2f ", ($acc_value/$cells_contained);
	  printf STDOUT "%.2f ", ($acc_value/$cells_contained);
        }
      }
      else {
	printf OUTFILE "%.2f ", $no_data;
	printf STDOUT "%.2f ", $no_data;	
      }
    }
    printf OUTFILE "\n";
    printf STDOUT "\n";
  }
}
close(MASK);
close(OUTFILE);
