#!/usr/bin/perl

# This script averages the contents of the given files.  The files must all have the
# same format and the same number of lines.

# Authors: Ben Livneh (blivneh@hydro.washington.edu) and Ted Bohn (tbohn@hydro.washington.edu)
# Date: 2008-04-03

# Usage: avg_files.pl file1,file2,...,fileN ndateflds precision
# where
#   file1,file2,...,fileN = comma-separated list of filenames (including path)
#   ndateflds             = number of fields in each file containing date information
#                           (e.g. for "YYYY MM DD data1 data2 data3 ...", ndateflds = 3)
#   precision             = number of decimal places of precision for floating point data;
#                           this is for output formatting only.

# Command-line arguments
$filelist = shift;
$ndateflds = shift;
$precision = shift;

# Parse the file list
@filenames = split /,/, $filelist;
$numfiles = @filenames;

# Loop over all files
$count = 0;
foreach $file (@filenames) {

  # Read current file
  $rec = 0;
  open (FILE, $file) or die "$0: ERROR: cannot open $file for reading\n";
  foreach (<FILE>) {

    chomp;
    @fields = split /\s+/;

    # Keep running total of each data field across all files
    if ($count == 0) {
      push @{$data[$rec]}, @fields;
    }
    else {
      for($i=0; $i<@fields; $i++) {
        $data[$rec][$i] += $fields[$i];
      }
    }

    # Divide by number of files
    if ($count == $numfiles-1) {
      for($i=0; $i<@fields; $i++) {
        $data[$rec][$i] /= $numfiles;
      }
    }

    $rec++;

  }

  close(FILE);

  $count++;

}
$nrecs = $rec;

# Print averaged data
$fmtstr = "%." . $precision . "f";
for ($rec=0; $rec<$nrecs; $rec++) {
  if ($ndateflds > 0) {
    printf "%d", $data[$rec][0];
    for ($i=1; $i<$ndateflds; $i++) {
      printf " %d", $data[$rec][$i];
    }
    for ($i=$ndateflds; $i<@fields; $i++) {
      printf " $fmtstr", $data[$rec][$i];
    }
  }
  else {
    printf "$fmtstr", $data[$rec][0];
    for ($i=1; $i<@fields; $i++) {
      printf " $fmtstr", $data[$rec][$i];
    }
  }
  print "\n";
}
