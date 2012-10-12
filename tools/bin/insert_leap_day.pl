#!<SYSTEM_PERL_EXE> -w
# This script takes an ascii-format data file and inserts leap days.
# The files are expected to have the format YYYY MM DD data1 data2 ...
# The leap day is inserted by taking the record of Feb 28 from a leap year
# and repeating it.
$file     = shift;
$col_list = shift; # comma-separated list of columns to set to 0 in the repeated
                   # records; indexing starts at 0
@month_days   = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
@cols_to_zero = split /,/, $col_list;
$delta_days   = 0;
open(FILE, $file) or die "$0: ERROR: cannot open $file for reading\n";

foreach (<FILE>) {
  chomp;
  @fields = split /\s+/;
  ($year, $month, $day) = @fields[0 .. 2];

  # Convert from strings to numbers
  $day   *= 1;
  $month *= 1;
  $year  *= 1;

  # Modify date if appropriate
  if ($delta_days > 0) {

    # Compute number of days in month
    $days_in_month = $month_days[$month - 1];
    if ($year % 4 == 0 && $month == 2) {
      $days_in_month++;
    }

    # Increment date by delta_days
    $day += $delta_days;
    if ($day > $days_in_month) {
      $day = 1;
      $month++;
    }
    if ($month > 12) {
      $month = 1;
      $year++;
    }
  }

  # Print current record (with possibly modified date)
  printf "%04d %02d %02d", $year, $month, $day;
  for ($i = 3 ; $i < @fields ; $i++) {
    print " $fields[$i]";
  }
  print "\n";

  # Check to see if this is Feb 28 of a leap year
  if ($year % 4 == 0 && $month == 2 && $day == 28) {

    # Repeat Feb 28 and call it Feb 29
    printf "%04d %02d 29", $year, $month;
    $j = 0;
    for ($i = 3 ; $i < @fields ; $i++) {
      if (@cols_to_zero > 0 && $i == $cols_to_zero[$j]) {
        print " 0";
        $j++;
      } else {
        print " $fields[$i]";
      }
    }
    print "\n";

    # Increment delta_days
    $delta_days++;
  }
}
close(FILE);
