#!/usr/bin/perl
#
# interpolate.pl - this script takes an ascii arcinfo-style data file
#                  and fills in any holes (null values) with a bilinear
#                  interpolation of the values in neighboring cells.
#
# usage: interpolate.pl <mask_file> <data_file> <type> <output_file>
#
# where
#   <mask_file>   = name of arcinfo-style ascii mask file for the desired basin
#   <data_file>   = name of arcinfo-style ascii data file for the desired basin
#   <type>        = data type; can be either "int" or "float"
#   <output_file> = name of output file
#
# Author: Ted Bohn, tbohn@hydro.washington.edu, 2005-Aug-29
#
# Modified: to allow for a single point (i.e. cellsize_mask = 0) 7/07 Ben Livneh


# Get command-line parameters
$landmask = shift;
$datafile = shift;
$type = shift;
$outfile = shift;

# Read landmask
open (FILE, $landmask) or die "$0: ERROR: cannot open landmask $landmask\n";
$row = 0;
foreach (<FILE>) {
  chomp;
  if (/^\s*NCOLS\s+(\S+)/i) {
    $ncols_mask = $1;
  }
  elsif (/^\s*NROWS\s+(\S+)/i) {
    $nrows_mask = $1;
  }
  elsif (/^\s*XLLCORNER\s+(\S+)/i) {
    $xllcorner_mask = $1;
  }
  elsif (/^\s*YLLCORNER\s+(\S+)/i) {
    $yllcorner_mask = $1;
  }
  elsif (/^\s*cellsize\s+(\S+)/i) {
    $cellsize_mask = $1;
  }
  elsif (/^\s*NODATA.*\s+(\S+)/i) {
    $nodata_mask = $1;
  }
  else {
    s/^\s+//;
    @fields = split /\s+/;
    if (@fields) {
      for ($col=0; $col<$ncols_mask; $col++) {
        # row index should be nrows_mask-row-1, due to top row occurring first in asc file
        $mask[$nrows_mask-$row-1][$col] = $fields[$col];
      }
      $row++;
    }
  }
}
close (FILE);

# Read datafile
open (FILE, $datafile) or die "$0: ERROR: cannot open datafile $datafile\n";
$row = 0;
foreach (<FILE>) {
  chomp;
  if (/^\s*NCOLS\s+(\S+)/i) {
    $ncols_data = $1;
  }
  elsif (/^\s*NROWS\s+(\S+)/i) {
    $nrows_data = $1;
  }
  elsif (/^\s*XLLCORNER\s+(\S+)/i) {
    $xllcorner_data = $1;
  }
  elsif (/^\s*YLLCORNER\s+(\S+)/i) {
    $yllcorner_data = $1;
  }
  elsif (/^\s*cellsize\s+(\S+)/i) {
    $cellsize_data = $1;
  }
  elsif (/^\s*NODATA.*\s+(\S+)/i) {
    $nodata_data = $1;
  }
  else {
    s/^\s+//;
    @fields = split /\s+/;
    if (@fields) {
      for ($col=0; $col<$ncols_data; $col++) {
        # row index should be nrows_data-row-1, due to top row occurring first in asc file
        $data[$nrows_data-$row-1][$col] = $fields[$col];
      }
      $row++;
    }
  }
}
close (FILE);

# Validate geometry
if ($cellsize_mask != $cellsize_data) {
  print STDERR "$0: ERROR: data cell size $cellsize_data != mask cell size $cell_size_mask\n";
  exit (-1);
}

if ($cellsize_mask == 0) {
  $col_offset = 0;
  $row_offset = 0;
}
else {
  $col_offset = ($xllcorner_mask - $xllcorner_data)/$cellsize_mask;
  if ($col_offset < 0) {
    print STDERR "$0: ERROR: mask\'s left edge lies outside of the grid in $datafile\n";
    exit (-1);
  }
  $row_offset = ($yllcorner_mask - $yllcorner_data)/$cellsize_mask;
  if ($row_offset < 0) {
    print STDERR "$0: ERROR: mask\'s lower edge lies outside of the grid in $datafile\n";
    exit (-1);
  }
}

# Find holes in datafile (cells that are valid in the landmask but have nodata in datafile)
for ($row=0; $row<$nrows_mask; $row++) {
  for ($col=0; $col<$ncols_mask; $col++) {
    if ($mask[$row][$col] != $nodata_mask && $data[$row+$row_offset][$col+$col_offset] == $nodata_data) {
      $is_hole{$row}{$col} = 1;
      $k++;
    }
  }
}
$n_holes = $k;

if ($n_holes > 0) {

# Interpolate in row direction
$row_prev = -1;
$col_prev = -1;
for ($row=0; $row<$nrows_mask; $row++) {
  $count = 0;
  # Note the <= here; we want to go beyond the last column to enforce
  # the end of a series of contiguous holes
  for ($col=0; $col<=$ncols_mask; $col++) {
    if ($is_hole{$row}{$col}) {
#print "$row $col\n";
      if ($count == 0) {
        $min_col = $col-1;
      }
      $count++;
      $row_prev = $row;
      $col_prev = $col;
    }
    elsif ($count > 0) {
      $max_col = $col_prev+1;
#print "min_col $min_col max_col $max_col\n";
      # Case 1: this series of contiguous holes is bounded on both ends by valid data;
      #         linearly interpolate between boundary points
      if ($min_col >= 0 && $data[$row_prev+$row_offset][$min_col+$col_offset] != $nodata_data
          && $max_col < $ncols_mask && $data[$row_prev+$row_offset][$max_col+$col_offset] != $nodata_data) {
#print "case 1\n";
        for ($i=0; $i<$count; $i++) {
          $row_pass[$row_prev][$min_col+1+$i] = $data[$row_prev+$row_offset][$min_col+$col_offset]
                                    + (($i+1)/($count+1))*($data[$row_prev+$row_offset][$max_col+$col_offset]
                                                       -$data[$row_prev+$row_offset][$min_col+$col_offset]);
        }
      }
      # Case 2: this series of contiguous holes has an invalid point to its right;
      #         assign all holes the value of the point to their left
      elsif ($min_col >= 0 && $data[$row_prev+$row_offset][$min_col+$col_offset] != $nodata_data) {
#print "case 2\n";
        for ($i=0; $i<$count; $i++) {
          $row_pass[$row_prev][$min_col+1+$i] = $data[$row_prev+$row_offset][$min_col+$col_offset];
        }
      }
      # Case 3: this series of contiguous holes has an invalid point to its left;
      #         assign all holes the value of the point to their right
      elsif ($max_col < $ncols_mask && $data[$row_prev+$row_offset][$max_col+$col_offset] != $nodata_data) {
#print "case 3\n";
        for ($i=0; $i<$count; $i++) {
          $row_pass[$row_prev][$min_col+1+$i] = $data[$row_prev+$row_offset][$max_col+$col_offset];
        }
      }
      # Case 4: this series of contiguous holes has invalid points to its left and right;
      #         for each point, search for the nearest valid point and take its value
      else {
#print "case 4\n";
        for ($i=0; $i<$count; $i++) {
SEARCH_LOOP1: for ($radius=1; ($radius<$nrows_mask || $radius<$ncols_mask); $radius++) {
            for ($m=-$radius; $m<=$radius; $m++) {
              for ($n=-$radius; $n<=$radius; $n++) {
                if ($row_prev+$m >= 0 && $row_prev+$m < $nrows_mask
                    && $min_col+1+$i+$n >=0 && $min_col+1+$i+$n < $ncols_mask
                    && $data[$row_prev+$m+$row_offset][$min_col+1+$i+$n+$col_offset] != $nodata_data) {
                  $row_pass[$row_prev][$min_col+1+$i] = $data[$row_prev+$m+$row_offset][$min_col+1+$i+$n+$col_offset];
                  last SEARCH_LOOP1;
                }
              }
            }
          }
        }
      }
#for ($i=0; $i<$count; $i++) {
#  print "$row_prev $min_col+1+$i $row_pass[$row_prev][$min_col+1+$i]\n";
#}
      $count = 0;
    }
  }
}
      
# Interpolate in col direction
$row_prev = -1;
$col_prev = -1;
for ($col=0; $col<$ncols_mask; $col++) {
  $count = 0;
  # Note the <= here; we want to go beyond the last row to enforce
  # the end of a series of contiguous holes
  for ($row=0; $row<=$nrows_mask; $row++) {
    if ($is_hole{$row}{$col}) {
#print "$row $col\n";
      if ($count == 0) {
        $min_row = $row-1;
      }
      $count++;
      $row_prev = $row;
      $col_prev = $col;
    }
    elsif ($count > 0) {
      $max_row = $row_prev+1;
#print "min_row $min_row max_row $max_row\n";
      # Case 1: this series of contiguous holes is bounded on both ends by valid data;
      #         linearly interpolate between boundary points
      if ($min_row >= 0 && $data[$min_row+$row_offset][$col_prev+$col_offset] != $nodata_data
          && $max_row < $nrows_mask && $data[$max_row+$row_offset][$col_prev+$col_offset] != $nodata_data) {
#print "case 1\n";
        for ($i=0; $i<$count; $i++) {
          $col_pass[$min_row+1+$i][$col_prev] = $data[$min_row+$row_offset][$col_prev+$col_offset]
                                    + (($i+1)/($count+1))*($data[$max_row+$row_offset][$col_prev+$col_offset]
                                                       -$data[$min_row+$row_offset][$col_prev+$col_offset]);
        }
      }
      # Case 2: this series of contiguous holes has an invalid point above;
      #         assign all holes the value of the point below
      elsif ($min_row >= 0 && $data[$min_row+$row_offset][$col_prev+$col_offset] != $nodata_data) {
#print "case 2\n";
        for ($i=0; $i<$count; $i++) {
          $col_pass[$min_row+1+$i][$col_prev] = $data[$min_row+$row_offset][$col_prev+$col_offset];
        }
      }
      # Case 3: this series of contiguous holes has an invalid point below;
      #         assign all holes the value of the point above
      elsif ($max_row < $nrows_mask && $data[$max_row+$row_offset][$col_prev+$col_offset] != $nodata_data) {
#print "case 3\n";
        for ($i=0; $i<$count; $i++) {
          $col_pass[$min_row+1+$i][$col_prev] = $data[$max_row+$row_offset][$col_prev+$col_offset];
        }
      }
      # Case 4: this series of contiguous holes has invalid points above and below;
      #         for each point, search for the nearest valid point and take its value
      else {
#print "case 4\n";
        for ($i=0; $i<$count; $i++) {
SEARCH_LOOP2: for ($radius=1; ($radius<$nrows_mask || $radius<$ncols_mask); $radius++) {
            for ($m=-$radius; $m<=$radius; $m++) {
              for ($n=-$radius; $n<=$radius; $n++) {
                if ($min_row+1+$i+$n >= 0 && $min_row+1+$i+$n < $nrows_mask
                    && $col_prev+$m >= 0 && $col_prev+$m < $ncols_mask
                    && $data[$min_row+1+$i+$n+$row_offset][$col_prev+$m+$col_offset] != $nodata_data) {
                  $col_pass[$min_row+1+$i][$col_prev] = $data[$min_row+1+$i+$n+$row_offset][$col_prev+$m+$col_offset];
                  last SEARCH_LOOP2;
                }
              }
            }
          }
        }
      }
#for ($i=0; $i<$count; $i++) {
#  print "$min_row+1+$i $col_prev $col_pass[$min_row+1+$i][$col_prev]\n";
#}
      $count = 0;
    }
  }
}

# Average the two interpolations
for ($row=0; $row<$nrows_mask; $row++) {
  for ($col=0; $col<$ncols_mask; $col++) {
    if ($is_hole{$row}{$col}) {
      $data[$row+$row_offset][$col+$col_offset] = ($row_pass[$row][$col]+$col_pass[$row][$col])/2;
    }
  }
}


}  # end if $n_holes > 0

# Write out the new file
open (OUTFILE, ">$outfile") or die "$0: ERROR: cannot open output file $outfile\n";
printf OUTFILE "NCOLS        %4d\n",$ncols_data;
printf OUTFILE "NROWS        %4d\n",$nrows_data;
printf OUTFILE "XLLCORNER    %9.4f\n",$xllcorner_data;
printf OUTFILE "YLLCORNER    %9.4f\n",$yllcorner_data;
printf OUTFILE "cellsize     %9.4f\n",$cellsize_data;
if ($type =~ /^int/i) {
  printf OUTFILE "NODATA_value %4d\n",$nodata_data;
}
else {
  printf OUTFILE "NODATA_value %9.4f\n",$nodata_data;
}
for ($row=$nrows_data-1; $row>=0; $row--) {
  for ($col=0; $col<$ncols_data; $col++) {
    if ($type =~ /^int/i) {
      printf OUTFILE "%4d ", $data[$row][$col];
    }
    else {
      printf OUTFILE "%9.4f ", $data[$row][$col];
    }
  }
  print OUTFILE "\n";
}
close (OUTFILE);
