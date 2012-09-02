#!/usr/bin/perl
#
# ts_plot.pl - script to create a plot with one or more timeseries, via GMT
#              commands.
#
# usage: see usage() function below
#
# Author: Ted Bohn
# $Id: $
#-------------------------------------------------------------------------------

# Global variables
@supported_formats = ("y", "m", "d", "h");
$default_format = "m";
@days_in_month = (
  31,
  28,
  31,
  30,
  31,
  30,
  31,
  31,
  30,
  31,
  30,
  31
);
$month_day_offset[0] = 0;
for ($i=1; $i<12; $i++) {
  $month_day_offset[$i] = $days_in_month[$i-1] + $month_day_offset[$i-1];
}
@line_types = (
  "-W1",
  "-W1/255/0/0:td",
  "-W1/0/255/0:td",
  "-W1/0/0/255:td",
  "-W1ta",
  "-W1/255/0/0:ta",
  "-W1/0/255/0:ta",
  "-W1/0/0/255:ta",
  "-W1to",
  "-W1/255/0/0:to",
  "-W1/0/255/0:to",
  "-W1/0/0/255:to",
);

# Parse command-line arguments and validate them
if (!@ARGV) {
  usage("short");
  exit(1);
}
$tsidx = 0;
$user_start_specified = 0;
$user_end_specified = 0;
$user_min_specified = 0;
$user_max_specified = 0;
while ($arg = shift @ARGV) {
  if ($arg eq "-file") {
    $arg = shift @ARGV;
    ($filename,$format) = split /:/, $arg;
    if (!$filename) {
      print STDERR "$0: ERROR: -file must be followed by a filename\n";
      usage("short");
      exit(1);
    }
    if (! -f $filename) {
      print STDERR "$0: ERROR: $filename does not appear to be a valid file\n";
      usage("short");
      exit(1);
    }
    if ($format) {
      $supported = 0;
      foreach $fmt (@supported_formats) {
        if ($format =~ /^$fmt$/i) {
          $format = $fmt;
          $supported = 1;
        }
      }
      if (!$supported) {
        print STDERR "$0: ERROR: format $format not supported\n";
        usage("short");
        exit(1);
      }
    }
    else {
      $format = $default_format;
    }
    $files{$filename}{fmt} = $format;
    if ($format eq "y") {
      $files{$filename}{first_data_fld} = 1;
    }
    elsif ($format eq "m") {
      $files{$filename}{first_data_fld} = 2;
    }
    elsif ($format eq "d") {
      $files{$filename}{first_data_fld} = 3;
    }
    else {
      $files{$filename}{first_data_fld} = 4;
    }
  }
  elsif ($arg eq "-ts") {
    if (!$filename) {
      print STDERR "$0: ERROR: -file must be specified before -ts\n";
      usage("short");
      exit(1);
    }
    $arg = shift @ARGV;
    @ts = split /,/, $arg;
    foreach $ts_entry (@ts) {
      ($tsname,$field) = split /:/, $ts_entry;
      if (!$tsname) {
        print STDERR "$0: ERROR: :$field timeseries name must be specified\n";
        usage("short");
        exit(1);
      }
      if (!$field) {
        print STDERR "$0: ERROR: field must be specified for timeseries $tsname\n";
        usage("short");
        exit(1);
      }
      if ($field !~ /^\d+$/ || $field < 1) {
        print STDERR "$0: ERROR: $tsname:$field field must be a positive integer\n";
        usage("short");
        exit(1);
      }
      if ($field < $files{$filename}{first_data_fld} + 1) {
        print STDERR "$0: ERROR: $tsname:$field field must not be a date/time field\n";
        usage("short");
        exit(1);
      }
      $field--;
      $tsinfo{$tsname}{fname} = $filename;
      $tsinfo{$tsname}{fld} = $field;
      push @tsnames, $tsname;
      $tsidx++;
      if ($tsidx > scalar(@line_types)) {
        $num_line_types = scalar(@line_types);
        print STDERR "$0: ERROR: too many variables; current limit is $num_line_types\n";
        usage("short");
        exit(1);
      }
    }
  }
  elsif ($arg eq "-title") {
    $title = shift @ARGV;
  }
  elsif ($arg eq "-start") {
    $user_start_specified = 1;
    $arg = shift @ARGV;
    @fields = split /[: -]/, $arg;
    if (scalar(@fields) == 1) {
      $user_start_year = $fields[0];
      $user_start_month = 1;
      $user_start_day = 1;
      $user_start_hour = 0;
    }
    elsif (scalar(@fields) == 2) {
      $user_start_year = $fields[0];
      $user_start_month = $fields[1];
      $user_start_day = 1;
      $user_start_hour = 0;
    }
    elsif (scalar(@fields) == 3) {
      $user_start_year = $fields[0];
      $user_start_month = $fields[1];
      $user_start_day = $fields[2];
      $user_start_hour = 0;
    }
    else {
      $user_start_year = $fields[0];
      $user_start_month = $fields[1];
      $user_start_day = $fields[2];
      $user_start_hour = $fields[3];
    }
    $user_start = &decimal_time($user_start_year, $user_start_month, $user_start_day, $user_start_hour);
  }
  elsif ($arg eq "-end") {
    $user_end_specified = 1;
    $arg = shift @ARGV;
    @fields = split /[: -]/, $arg;
    if (scalar(@fields) == 1) {
      $user_end_year = $fields[0];
      $user_end_month = 1;
      $user_end_day = 1;
      $user_end_hour = 0;
    }
    elsif (scalar(@fields) == 2) {
      $user_end_year = $fields[0];
      $user_end_month = $fields[1];
      $user_end_day = 1;
      $user_end_hour = 0;
    }
    elsif (scalar(@fields) == 3) {
      $user_end_year = $fields[0];
      $user_end_month = $fields[1];
      $user_end_day = $fields[2];
      $user_end_hour = 0;
    }
    else {
      $user_end_year = $fields[0];
      $user_end_month = $fields[1];
      $user_end_day = $fields[2];
      $user_end_hour = $fields[3];
    }
    $user_end = &decimal_time($user_end_year, $user_end_month, $user_end_day, $user_end_hour);
  }
  elsif ($arg eq "-min") {
    $user_min_specified = 1;
    $user_min = shift @ARGV;
    if ($user_min !~ /^\-?\d+(\.\d+)?$/) {
      print STDERR "$0: ERROR: min $user_min must be a number\n";
      usage("short");
      exit(1);
    }
  }
  elsif ($arg eq "-max") {
    $user_max_specified = 1;
    $user_max = shift @ARGV;
    if ($user_max !~ /^\-?\d+(\.\d+)?$/) {
      print STDERR "$0: ERROR: max $user_max must be a number\n";
      usage("short");
      exit(1);
    }
  }
  elsif ($arg eq "-lines") {
    $lines_specified = 1;
    $num_lines = shift @ARGV;
    if ($num_lines !~ /^\d+$/ || $num_lines < 1) {
      print STDERR "$0: ERROR: number of lines must be a positive integer\n";
      usage("short");
      exit(1);
    }
    if ($num_lines > 3) {
      print STDERR "$0: ERROR: number of lines must less than or equal to 3\n";
      usage("short");
      exit(1);
    }
  }
  elsif ($arg eq "-out") {
    $outfile = shift @ARGV;
  }
  elsif ($arg eq "-h") {
    usage("full");
    exit(0);
  }
}

if ($user_start_specified && $user_end_specified && $user_start > $user_end) {
  print STDERR "$0: ERROR: start time $user_start > end time $user_end\n";
  exit(1);
}

if ($user_min_specified && $user_max_specified && $user_min > $user_max) {
  print STDERR "$0: ERROR: min value $user_min > max value $user_max\n";
  exit(1);
}

if (!$lines_specified) {
  $num_lines = 1;
}

# Read data from files
$data_found = 0;
TS_LOOP: for ($tsidx=0; $tsidx<scalar(@tsnames); $tsidx++) {

  $tsname = $tsnames[$tsidx];

  open (FILE, $tsinfo{$tsname}{fname}) or die "$0: ERROR: cannot open $tsinfo{$tsname}{fname}\n";
  $first_line = 1;
  DATA_LOOP: foreach $line (<FILE>) {

    # Remove leading spaces
    $line =~ s/^\s+//;

    # Split line into fields
    @fields = split /\s+/, $line;

    # Get time value
    $year = $fields[0];
    if ($files{ $tsinfo{$tsname}{fname} }{fmt} =~ /^(m|d|h)$/) {
      $month = $fields[1];
    }
    else {
      $month = 1;
    }
    if ($files{ $tsinfo{$tsname}{fname} }{fmt} =~ /^(d|h)$/) {
      $day = $fields[2];
    }
    else {
      $day = 1;
    }
    if ($files{ $tsinfo{$tsname}{fname} }{fmt} =~ /^h$/) {
      $hour = $fields[3];
    }
    else {
      $hour = 0;
    }
    $decimal_year = &decimal_time($year, $month, $day, $hour);

    # Figure out whether we're within desired time period
    if ($user_start_specified && $decimal_year < $user_start) {
      next DATA_LOOP;
    }
    if ($user_end_specified && $decimal_year > $user_end) {
      last DATA_LOOP;
    }

    # Store time value
    push @{ $tsinfo{$tsname}{time} }, $decimal_year;

    # Get data value
    push @{ $tsinfo{$tsname}{data} }, $fields[ $tsinfo{$tsname}{fld} ];

    # Update ts max and min
    if ($first_line) {
      $tsinfo{$tsname}{min} = $fields[ $tsinfo{$tsname}{fld} ];
      $tsinfo{$tsname}{max} = $fields[ $tsinfo{$tsname}{fld} ];
      $first_line = 0;
    }
    else {
      if ($fields[ $tsinfo{$tsname}{fld} ] < $tsinfo{$tsname}{min}) {
        $tsinfo{$tsname}{min} = $fields[ $tsinfo{$tsname}{fld} ];
      }
      if ($fields[ $tsinfo{$tsname}{fld} ] > $tsinfo{$tsname}{max}) {
        $tsinfo{$tsname}{max} = $fields[ $tsinfo{$tsname}{fld} ];
      }
    }

  }
  close (FILE);

  # If no data points found for this time series, omit it from global calculations
  if ( !scalar(@{ $tsinfo{$tsname}{time} }) || !scalar(@{ $tsinfo{$tsname}{data} }) ) {
    next TS_LOOP;
  }

  $data_found = 1;

  # Update global max and min
  if ($tsidx == 0) {
    $data_min = $tsinfo{$tsname}{min};
    $data_max = $tsinfo{$tsname}{max};
  }
  else {
    if ($tsinfo{$tsname}{min} < $data_min) {
      $data_min = $tsinfo{$tsname}{min};
    }
    if ($tsinfo{$tsname}{max} > $data_max) {
      $data_max = $tsinfo{$tsname}{max};
    }
  }

  # Start and end times for this time series
  $tsinfo{$tsname}{start_time} = ${ $tsinfo{$tsname}{time} }[0];
  $tsinfo{$tsname}{end_time}   = ${ $tsinfo{$tsname}{time} }[ $#{ $tsinfo{$tsname}{time} } ];
  
  # Determine global start/end times
  if ($tsidx == 0) {
    $data_start = $tsinfo{$tsname}{start_time};
    $data_end   = $tsinfo{$tsname}{end_time};
  }
  else {
    if ($tsinfo{$tsname}{start_time} < $start) {
      $data_start = $tsinfo{$tsname}{start_time};
    }
    if ($tsinfo{$tsname}{end_time} > $end) {
      $data_end   = $tsinfo{$tsname}{end_time};
    }
  }

}

# Check for no data
if (!$data_found) {
  print STDERR "$0: ERROR: No data points fall within specified start/end interval\n";
  exit(1);
}

#-------------------------------------------------------------------------------------------
# Determine plot min/max
# Basically, try to have 2 - 6 ticks on the y-axis, at nice round numbers, as follows:
# If the data ranges between 6*10**x and 10*10**x, set tick intervals to 2*10**x.
# If the data ranges between 3*10**x and 6*10**x, set tick intervals to 10**x.
# If the data ranges between 1*10**x and 3*10**x, set tick intervals to 0.5*10**x.
# To do this, we need to figure out "x".
# $log10_y_range = "x", and $y_magnitude = 10**x.
# If user hasn't set min/max explicitly,
# set $min = greatest integer multiple of tick interval that's below $data_min.
# set $max = smallest integer multiple of tick interval that's above $data_max.
#-------------------------------------------------------------------------------------------
# Min/max are either user's choice or automatic from data
if ($user_min_specified) {
  $min = $user_min;
}
else {
  $min = $data_min;
}
if ($user_max_specified) {
  $max = $user_max;
}
else {
  $max = $data_max;
}

if ($min > $max) {
  print STDERR "$0: ERROR: min value $min > max value $max\n";
  exit(1);
}

# Adjust min/max if necessary
if ($max == $min) {
  if ($max > 0) {
    $max *= 1.1;
    $min *= 0.9;
  }
  elsif ($max < 0) {
    $max *= 0.9;
    $min *= 1.1;
  }
  else {
    $max = 1;
  }
}

# Figure out y order of magnitude
$data_y_range = $max - $min;
$log10_y_range = log($data_y_range) / log(10);   # log_10(x) = log_e(x)/log_e(10)
$log10_y_range = int($log10_y_range);            # get rid of the fractional part
$y_magnitude = exp( $log10_y_range * log(10) );  # 10**x = e**(xlog_e(10))

# Set tick interval
$mantissa = $data_y_range / $y_magnitude;
if ($mantissa >= 6 && $mantissa < 10) {
  $delta_y = 2 * $y_magnitude;
}
elsif ($mantissa >= 3 && $mantissa < 6) {
  $delta_y = $y_magnitude;
}
else {
  $delta_y = 0.5 * $y_magnitude;
}

# If user didn't explicitly set $min and $max, adjust them to nice round numbers
if (!$user_min_specified) {
  $min = int($min / $delta_y) * $delta_y;
}
if (!$user_max_specified) {
  $max = (int($max / $delta_y) + 1) * $delta_y;
}

#-------------------------------------------------------------------------------------------
# Determine plot start/end
# Use same method as for min/max, but now it's for time range per line
#-------------------------------------------------------------------------------------------
# Start/end are either user's choice or automatic from data
if ($user_start_specified) {
  $start = $user_start;
}
else {
  $start = int $data_start;
}
if ($user_end_specified) {
  $end = $user_end;
}
else {
  $end = int $data_end + 1;
}

if ($start > $end) {
  print STDERR "$0: ERROR: start time $start > end time $end\n";
  exit(1);
}

# Adjust start/end if necessary
if ($end == $start) {
  if ($end > 0) {
    $end *= 1.1;
    $start *= 0.9;
  }
  elsif ($end < 0) {
    $end *= 0.9;
    $start *= 1.1;
  }
  else {
    $end = 1;
  }
}

# Figure out t order of magnitude
$data_t_range_per_line = ($end - $start)/$num_lines;
$log10_t_range_per_line = log($data_t_range_per_line) / log(10);   # log_10(x) = log_e(x)/log_e(10)
$log10_t_range_per_line = int($log10_t_range_per_line);            # get rid of the fractional part
$t_magnitude_per_line = exp( $log10_t_range_per_line * log(10) );  # 10**x = e**(xlog_e(10))

$mantissa = $data_t_range_per_line / $t_magnitude_per_line;
if ($mantissa >= 6 && $mantissa < 10) {
  $delta_t = $t_magnitude_per_line;
}
elsif ($mantissa >=1.2 && $mantissa < 6) {
  $delta_t = 0.5 * $t_magnitude_per_line;
}
else {
  $delta_t = 0.1 * $t_magnitude_per_line;
}

# More plot parameters
$proj = "-JX7/1.5";

# Make plot
for ($line=0; $line<$num_lines; $line++) {

  if ($line == 0) {
    $ts1_options = "-P -K";
    $y_origin = 8.5;
    $ts1_redirect = ">";
  }
  else {
    $ts1_options = "-O -K";
    $y_origin = -2.5;
    $ts1_redirect = ">>";
  }

  $line_start = $start + $line*$data_t_range_per_line;
  $line_end = $start + ($line+1)*$data_t_range_per_line;

  for ($tsidx=0; $tsidx<scalar(@tsnames); $tsidx++) {

    $tsname = $tsnames[$tsidx];

    if ($tsidx == 0) {
      open (PSXY, "| psxy $ts1_options -B$delta_t/$delta_y:.:SWne -R$line_start/$line_end/$min/$max $proj $line_types[$tsidx] -Y$y_origin $ts1_redirect $outfile")
        or die "$0: ERROR: cannot open pipe to psxy\n"; 
      for ($i=0; $i<=$#{ $tsinfo{$tsname}{time} }; $i++) {
        printf PSXY "%8.3f %8.3f\n", $tsinfo{$tsname}{time}[$i], $tsinfo{$tsname}{data}[$i];
      }
      close (PSXY);
    }
    else {
      open (PSXY, "| psxy -O -K -R$line_start/$line_end/$min/$max $proj $line_types[$tsidx] >> $outfile")
        or die "$0: ERROR: cannot open pipe to psxy\n"; 
      for ($i=0; $i<=$#{ $tsinfo{$tsname}{time} }; $i++) {
        printf PSXY "%8.3f %8.3f\n", $tsinfo{$tsname}{time}[$i], $tsinfo{$tsname}{data}[$i];
      }
      close (PSXY);
    }

  }

  # Title
  if ($title) {
    $x_title = $line_start;
    $y_title = $min + (0.9 * ($max - $min));
    open (PSTEXT, "| pstext -O -K -N -R$line_start/$line_end/$min/$max $proj >> $outfile")
      or die "$0: ERROR: cannot open pipe to pstext\n";
    print PSTEXT "$x_title $y_title 12 0 5 5 $title\n";
    close (PSTEXT);
  }

}

# Legend - text
$col1_x = 0.2;
$col2_x = 0.6;
$row1_y = 1.0;
$pos_x = $col1_x;
$pos_y = $row1_y;
$new_column = 0;
open (PSTEXT, "| pstext -O -K -N -R0/1/0/1 $proj -Y-2.0 >> $outfile")
  or die "$0: ERROR: cannot open pipe to pstext\n";
for ($tsidx=0; $tsidx<scalar(@tsnames); $tsidx++) {
  if ($tsidx >= scalar(@tsnames)/2 && !$new_column) {
    $pos_x = $col2_x;
    $pos_y = $row1_y;
    $new_column = 1;
  }
  elsif ($tsidx > 0) {
    $pos_y -= 0.2;
  }
  print PSTEXT "$pos_x $pos_y 12 0 5 6 $tsnames[$tsidx]\n";
}
close (PSTEXT);

# Legend - symbols
$pos_x1 = $col1_x + 0.1;
$pos_x2 = $col1_x + 0.2;
$pos_y = $row1_y;
$new_column = 0;
for ($tsidx=0; $tsidx<scalar(@tsnames); $tsidx++) {
  if ($tsidx >= scalar(@tsnames)/2 && !$new_column) {
    $pos_x1 = $col2_x + 0.1;
    $pos_x2 = $col2_x + 0.2;
    $pos_y = $row1_y;
    $new_column = 1;
  }
  elsif ($tsidx > 0) {
    $pos_y -= 0.2;
  }
  if ($tsidx < scalar(@tsnames)-1) {
    open (PSXY, "| psxy -O -K -N -R0/1/0/1 $proj $line_types[$tsidx] >> $outfile")
      or die "$0: ERROR: cannot open pipe to psxy\n";
    print PSXY "$pos_x1 $pos_y\n";
    print PSXY "$pos_x2 $pos_y\n";
    close (PSXY);
  }
  else {
    open (PSXY, "| psxy -O -N -R0/1/0/1 $proj $line_types[$tsidx] >> $outfile")
      or die "$0: ERROR: cannot open pipe to psxy\n";
    print PSXY "$pos_x1 $pos_y\n";
    print PSXY "$pos_x2 $pos_y\n";
    close (PSXY);
  }
}


#-------------------------------------------------------------------------------
# decimal_time - converts a standard calendar date to a decimal year
#
# Inputs:
#   year  - 4-digit year
#   month - 2-digit month, with January = 01 and December = 12
#   day   - 2-digit day of month, from 01 to 31
#   hour  - 2-digit hour, from 00 to 23
#
# Output:
#   decimal_year - floating-point number consisting of 4-digit year followed by
#                  decimal fraction of year.  For example, Jan 1, 1999, 0h
#                  becomes 1999.0
#-------------------------------------------------------------------------------
sub decimal_time {

  my ($year, $month, $day, $hour) = @_;
  my $days_in_year, $day_of_year;

  if ( $year%4 == 0 && ( $year%100 != 0 || $year%400 == 0 ) ) {

    # Leap Year
    $days_in_year = 366;
    if ($month > 2) {
      # One extra day offset after February
      $day_of_year = $month_day_offset[$month-1] + $day;
    }
    else {
      # Jan and Feb have same offset regardless of leap year
      $day_of_year = $month_day_offset[$month-1] + ($day - 1);
    }

  }
  else {

    # Non-Leap Year
    $days_in_year = 365;
    $day_of_year = $month_day_offset[$month-1] + ($day - 1);

  }

  my $decimal_hour = $hour/24;
  my $decimal_year = $year + ($day_of_year+$decimal_hour)/$days_in_year;

  return $decimal_year;

}


#-------------------------------------------------------------------------------
# Usage
#-------------------------------------------------------------------------------
sub usage {

  print "\n";
  print "$0: script to plot multiple timeseries from ascii data files\n";
  print "\n";
  if ($_[0] eq "full") {
    print "This script takes several user-specified time series, and plots them on the same\n";
    print "postscript-format plot.  Multiple input files may be specified, and multiple\n";
    print "variables can be extracted from each input file.  To extract a variable from a\n";
    print "file, the user must specify the file name and record interval, and the variable\'s\n";
    print "field number within that file.  A different color and line pattern will be\n";
    print "automatically assigned to each variable that is being plotted.  The name specified\n";
    print "by the user for a variable will be used in the legend to identify each line color/\n";
    print "pattern.\n";
    print "\n";
    print "This script will automatically calculate the start/end times and the min/max\n";
    print "values to plot.  The start/end times will automatically be those of the earliest\n";
    print "and latest data points among all selected variables in all selected files, and the\n";
    print "min/max values will be the minimum and maximum values among all the variables\n";
    print "within the start/end times.  However, the user may override any of these start/end\n";
    print "times and/or min/max values by specifying them on the command line.  X- and Y-\n";
    print "axis tick marks are created automatically.\n";
    print "\n";
    print "The plot is made in portrait mode, and each line of the plot is about 1/3 the\n";
    print "height of the page.  By default, all data will be plotted on one line.  However,\n";
    print "the user may specify how many lines to use; the data will be split evenly across\n";
    print "all of these lines.  For example, if the user specifies 3 lines (to fill the page),\n";
    print "the first 1/3 of the time period will be plotted on the top line, the 2nd 1/3 will\n";
    print "be plotted on the middle line, and the final 1/3 will be plotted on the bottom line.\n";
    print "\n";
  }
  print "usage:\n";
  print "  $0 [-h] -file <filename>:<interval> -ts <tsname>:<field>[,<tsname>:<field>,...]\n";
  print "    [-file <filename>:<interval> -ts <tsname>:<field>[,<tsname>:<field>,...] ... ]\n";
  print "    [-start <start_time>] [-end <end_time>] [-min <min_value>] [-max <max_value>]\n";
  print "    [-lines <num_lines>] [-title <plot_title>] -out <outfile>\n";
  print "\n";
  if ($_[0] eq "full") {
    print "  -h\n";
    print "    prints this usage message\n";
    print "\n";
    print "  -file <filename>:<interval>\n";
    print "    <filename> = Name of input file\n";
    print "      Input files should be of the format:\n";
    print "        YEAR [MONTH] [DAY] [HOUR] DATA DATA DATA ...\n";
    print "      where\n";
    print "        YEAR  = 4-digit year\n";
    print "        MONTH = 2-digit month (optional - see below)\n";
    print "        DAY   = 2-digit day (optional - see below)\n";
    print "        HOUR  = 2-digit hour (optional - see below)\n";
    print "        DATA  = data fields\n";
    print "      Fields may be separated by multiple spaces or tabs.\n";
    print "    <interval> = Record interval.  Must be one of the following characters:\n";
    print "      h = input time step is sub-daily (any length less than 24 hours).\n";
    print "          Input file has format:\n";
    print "          YEAR MONTH DAY HOUR DATA DATA DATA ...\n";
    print "      d = input time step is daily.  Input file has format:\n";
    print "          YEAR MONTH DAY DATA DATA DATA ...\n";
    print "      m = input time step is monthly.  Input file has format:\n";
    print "          YEAR MONTH DATA DATA DATA ...\n";
    print "      y = input time step is yearly.  Input file has format:\n";
    print "          YEAR DATA DATA DATA ...\n";
    print "\n";
    print "  -ts <tsname>:<field>[,<tsname>:<field>,...]\n";
    print "    This specifies data to extract from the most recently specified file.\n";
    print "    <tsname> = Name of time series; this will be the label given to the data\n";
    print "               from this field of the associated file.\n";
    print "    <field>  = Number of the field that contains the data for this time series.\n";
    print "               Indexing starts at 1 and all fields are included (i.e. the YEAR\n";
    print "               field is field 1).\n";
    print "    Multiple time series can be extracted from the same file, separated by commas.\n";
    print "    For example, you can type:\n";
    print "      -file my_file:d -ts var1:5,var2:8,var3:6\n";
    print "    in this case, var1, var2, and var3 all are extracted from the file my_file.\n";
    print "    var1 is taken from field 5, var2 is taken from field 8, and var3 is taken\n";
    print "    from field 6.  On the resulting plot, \n";
    print "\n";
    print "  -start <start_time>,\n";
    print "  -end <end_time>\n";
    print "    <start_time> = Time of first data point to plot.\n";
    print "    <end_time>   = Time of last data point to plot.\n";
    print "                   Format for both of these is YYYY:MM:DD:HH, where\n";
    print "                     YYYY = 4-digit year\n";
    print "                     MM   = 2-digit month (from 01 to 12)\n";
    print "                     DD   = 2-digit day (from 01 to 31)\n";
    print "                     HH   = 2-digit hour (from 00 to 23)\n";
    print "                   MM, DD, and HH are optional.\n";
    print "     By default, the plot will begin/end at the first/last data points among all\n";
    print "     specified variables.\n";
    print "\n";
    print "  -min <min_value>,\n";
    print "  -max <max_value>\n";
    print "    <min_value> = minimum value to plot\n";
    print "    <max_value> = maximum value to plot\n";
    print "    By default, the plot\'s min/max values will be the min/max values of all\n";
    print "    variables within the period bounded by the start and end times.\n";
    print "\n";
    print "  -lines <num_lines>\n";
    print "    <num_lines> = If specified, the plot will be broken into num_lines parts,\n";
    print "                  each part taking up 1/3 of a page.  For example, if you\n";
    print "                  specify -lines 3, the first 1/3 of the time period will be\n";
    print "                  plotted on the top line of the page, the 2nd 1/3 will be\n";
    print "                  plotted on the middle line of the page, and the last 1/3\n";
    print "                  will be plotted on the bottom line of the page.\n";
    print "    By default, all data will be plotted on the top line of the page.\n";
    print "\n";
    print "  -title <title>\n";
    print "    <title> = Title of the plot.  This text will be printed at the top of the\n";
    print "              plot.  If the title contains multiple words, you must surround\n";
    print "              the text of the title with double quotes.  For example:\n";
    print "                -title \"This is my title\"\n";
    print "\n";
    print "  -out <outfile>\n";
    print "    <outfile> = name of output postscript file.\n";
    print "\n";
    print "Examples:\n";
    print "\n";
    print "To plot precip, evap, runoff, and baseflow from a daily VIC fluxes file \"my_fluxes_file\":\n";
    print "  $0 -file my_fluxes_file:d -ts precip:4,evap:5,runoff:6,baseflow:7 -title \"Water-Balance Terms\n";
    print "  from my_fluxes_file, (mm)\" -out my_fluxes_wb.ps\n";
    print "\n";
    print "To plot evap from several different hourly VIC fluxes files, spreading the plot over 6 lines:\n";
    print "  $0 -file flux_file_1:h -ts file1:6 -file flux_file_2:h -ts file2:6 -file flux_file_3:h\n";
    print "  -ts file3:6 -title \"Evaporation (mm) from file1, file2, and file3\" -out my_plot.ps\n";
    print "  -lines 6\n";
    print "\n";
  }

}
