#!/usr/bin/perl

# Root Directory - Edit this to reflect location of your SIMMA installation
$ROOT_DIR = "/raid8/forecast/sw_monitor";

# Tools directory
$TOOLS_DIR = "$ROOT_DIR/tools";

# Command-line arguments
$indir = shift;
$prefix = shift;
$outdir = shift;
$start_date = shift;
$end_date = shift;

($start_year,$start_month,$start_day) = split /-/, $start_date;
($end_year,$end_month,$end_day) = split /-/, $end_date;

# Don't do anything if the time series doesn't contain a leap day
if ( !($start_year % 4 == 0 && $start_month*1 <= 2 && $end_month*1 > 2)
    && !($end_year % 4 == 0 && $end_month*1 > 2) ) {
  $copy_files = 1;
}

opendir (INDIR, $indir) or die "$0: ERROR: cannot open $indir\n";
@filelist = grep /^$prefix/, readdir (INDIR);
closedir (INDIR);
#$cmd = "ls $indir";
#@filelist = grep /^$prefix/, `$cmd`;
#foreach (@filelist) {
#  chomp;
#  s/^\s+//;
#}

if ($copy_files) {
  $cmd = "rm -rf $outdir";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
  $cmd = "cp -r $indir $outdir";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
}
else {
  foreach $file (sort(@filelist)) {
    $cmd = "$TOOLS_DIR/insert_leap_day.pl $indir/$file > $outdir/$file";
    (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
  }
}
