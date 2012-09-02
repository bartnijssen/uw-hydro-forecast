#!/usr/bin/perl

# cmd-line arguments
# set to "null" if directory doesn't exist; values for this variable will be set to $nodata
$evap_dir = shift;
$runoff_dir = shift;
$baseflow_dir = shift;
$rtot_dir = shift;
$soilmoist_dir = shift;
$swe_dir = shift;
$stot_dir = shift;
$nodata = shift;
$out_dir = shift;

@dirlist = ($evap_dir, $runoff_dir, $baseflow_dir, $rtot_dir, $soilmoist_dir, $swe_dir, $stot_dir);

# Get list of grid cells from first extant directory
foreach $dir (@dirlist) {
  if ($dir !~ /^null$/i) {
    opendir (DIR, $dir) or die "$0: ERROR: cannot open directory $dir for reading\n";
    @filelist = grep !/^\./, readdir(DIR);
    closedir(DIR);
    last;
  }
}

# Loop over output files; each output file is a pasting together of the columns of the input files
foreach $file (@filelist) {
  $new_file = $file;
  if ($new_file =~ /^(.+)_[\d-\.]+_[\d-\.]+$/) {
    $new_file =~ s/$1/pctl/;
  }
  open (OUTFILE, ">$out_dir/$new_file") or die "$0: ERROR: cannot open output file $out_dir/$new_file for writing\n";
  close(OUTFILE);
}
