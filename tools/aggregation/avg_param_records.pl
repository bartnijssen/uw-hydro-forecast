#!/usr/bin/perl

# Command-line arguments
$infile = shift; # parameter file whose records will be aggregated
$cell_map = shift; # mapping between new (coarse resolution) cells and old (fine resolution) cells (output from cell_map_upscale.pl)

# Read cell mapping file and assemble lists of all old grid cell centers that map to new grid cells
# cell mapping file has format new_lat new_lon : old_lat old_lon
open (CELL_MAP, "$cell_map") or die "$0: ERROR: cannot open $cell_map for reading\n";
$new_idx = -1;  # index of the new cells
foreach (<CELL_MAP>) {
  chomp;
  @fields = split /\s+/;
  ($newlat,$newlon) = @fields[0..1];
  if ($new_idx == -1 || $newlat != $savelat || $newlon != $savelon) {
    $new_idx++;
    $newlats[$new_idx] = $newlat;
    $newlons[$new_idx] = $newlon;
  }
  push @{$oldlats[$new_idx]}, $fields[3]; # Add this old lat to the list of oldlats for this new cell
  push @{$oldlons[$new_idx]}, $fields[4]; # Add this old lon to the list of oldlons for this new cell
  $count[$new_idx]++;
  $savelat = $newlat;
  $savelon = $newlon;
}
close(CELL_MAP);
$ncells = $new_idx+1;

# Average the records
for ($k=0; $k<$ncells; $k++) {
  $this_count = 0;
  @avg_vals = ();
  # Loop over input param file to find the records to average
  open (INFILE, $infile) or die "$0: ERROR: cannot open input file $infile\n";
  foreach (<INFILE>) {
    chomp;
    @fields = split;
    ($lat,$lon) = @fields[2..3];
    for ($j=0; $j<$count[$k]; $j++) {
      if ($oldlats[$k][$j] == $lat && $oldlons[$k][$j] == $lon) {
        for ($i=4; $i<@fields; $i++) {
	  $avg_vals[$i-4] += $fields[$i];
	}
        $this_count++;
      }
    }
  }
  close (INFILE);
  if ($this_count > 0) {
    for ($i=4; $i<@fields; $i++) {
      $avg_vals[$i-4] /= $this_count;
    }
    printf "1 %d %.4f %.4f", $k, $newlats[$k], $newlons[$k];
    for ($i=4; $i<@fields; $i++) {
      printf " %f", $avg_vals[$i-4];
    }
    print "\n";
  }

}
