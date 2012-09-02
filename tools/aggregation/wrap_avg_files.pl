#!/usr/bin/perl

# Command-line arguments
$soilfile = shift; # VIC soil param file at old (fine) resolution
$indir = shift;
$prefix = shift;
$min_lat = shift;
$max_lat = shift;
$min_lon = shift;
$max_lon = shift;
$new_res = shift;
$ndateflds = shift;
$precision = shift;
$outdir = shift;

# Make list of lat/lons
#opendir(INDIR,$indir) or die "$0: ERROR: cannot open directory $indir for reading\n";
#@filelist = grep /$prefix/, readdir(INDIR);
#closedir(INDIR);
#$latlonfile = "./latlonlist.txt";
#open (LATLON, ">$latlonfile") or die "$0: ERROR: cannot open $latlonfile for writing\n";
#foreach $file (sort(@filelist)) {
#  if ($file =~ /^($prefix)_([^_]+)_([^_]+)$/) {
#    ($lat,$lon) = ($2,$3);
#    print LATLON "$lat $lon\n";
#  }
#}
#close(LATLON);
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
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

# Read lat/lon mapping file and assemble lists of all old grid cell centers that map to new grid cells
# lat/lon mapping file has format new_lat new_lon : old_lat old_lon
open (NEWLATLON, "$newlatlonfile") or die "$0: ERROR: cannot open $newlatlonfile for reading\n";
$new_idx = -1;  # index of the new cells
foreach (<NEWLATLON>) {
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
close(NEWLATLON);
$ncells = $new_idx+1;

# Loop over mapping to average the files
for ($k=0; $k<$ncells; $k++) {
  $newfile = $outdir . "/" . $prefix . "_" . $newlats[$k] . "_" . $newlons[$k];
  @oldfiles = ();
  for ($i=0; $i<$count[$k]; $i++) {
    $oldfile = $indir . "/" . $prefix . "_" . $oldlats[$k][$i] . "_" . $oldlons[$k][$i];
    push @oldfiles, $oldfile;
  }
  $oldfilestr = join ",", @oldfiles;
  $cmd = "avg_files.pl $oldfilestr $ndateflds $precision > $newfile";
  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
}
