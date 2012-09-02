#!/usr/bin/perl

$indir = shift;
$model = shift;
$prefix_in = shift;
$ext_in = shift;
$prefix_out = shift;
$ext_out = shift;

@month_days = (31,28,31,30,31,30,31,31,30,31,30,31);

opendir (INDIR, $indir) or die "$0: ERROR: cannot open input directory $indir for reading\n";
@filelist = grep /^$prefix_in\S+$ext_in/, readdir(INDIR);
closedir(INDIR);
@filelist = sort(@filelist);

foreach $file (@filelist) {
  if ($model =~ /clm/ && $file =~ /^[\w\.\_\-]+\.(\d\d\d\d)-(\d\d)-[\w\.\_\-]+$/) {
    ($year,$month) = ($1,$2);
    $month--;
    if ($month < 1) {
      $month = 12;
      $year--;
    }
  }
  elsif ($model =~ /(noah|sac)/ && $file =~ /^[\w\.\_\-]+\.(\d\d\d\d)(\d\d)\.[\w\.\_\-]+$/) {
    ($year,$month) = ($1,$2);
  }
  else {
    print "$0: WARNING: filename $file does not match expected pattern for model $model\n";
    next;
  }
  $days_in_month = $month_days[$month-1];
  if ($year % 4 == 0 && $month == 1) {
    $days_in_month++;
  }
  $newfile = sprintf "%s.%04d%02d%02d.%s", $prefix_out,$year,$month,$days_in_month,$ext_out;
  $cmd = "mv $indir/$file $indir/$newfile";
#print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
}
