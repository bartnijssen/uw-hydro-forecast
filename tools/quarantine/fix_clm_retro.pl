#!/usr/bin/perl

$indir = shift;
$prefix = shift;
$varlist = shift;
$tmpdir = shift;
$tmpdir2 = shift;
$tmpdir3 = shift;
$outdir = shift;

opendir(INDIR,$indir) or die "$0: ERROR: cannot open directory $indir\n";
@filelist = grep /^$prefix/, readdir(INDIR);
closedir(INDIR);

$append = 0;
foreach $file (sort(@filelist)) {
  if ($file =~ /$prefix\.(\d\d\d\d)-/) {
    $year = $1;
  }
  $cmd = "nc2vic -i $indir/$file -o $tmpdir -p $prefix -v $varlist -f scientific -t";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
  opendir(TMPDIR,$tmpdir) or die "$0: ERROR: cannot open directory $tmpdir\n";
  @asc_filelist = grep /^$prefix/, readdir(TMPDIR);
  closedir(TMPDIR);
  foreach $ascfile (sort(@asc_filelist)) {
    $cmd = "mult_fields.pl $tmpdir/$ascfile 4 4,5,6 86400 > $tmpdir2/$ascfile";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
    $cmd = "add_fields.pl $tmpdir2/$ascfile 4 4:5:6,10:20,11:21,12:22,13:23,14:24,15:25,16:26,17:27,18:28,19:29 > $tmpdir3/$ascfile";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
    if ($year % 4 == 0) {
      $cmd = "insert_leap_day.pl $tmpdir3/$ascfile 4,5,6 > $tmpdir3/$ascfile.tmp";
      (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
      $cmd = "mv $tmpdir3/$ascfile.tmp $tmpdir3/$ascfile";
      (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
    }
    if ($append) {
      $cmd = "cat $tmpdir3/$ascfile >> $outdir/$ascfile";
      (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
    }
    else {
      $cmd = "cp $tmpdir3/$ascfile $outdir/";
      (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
    }
  }
  $append = 1;
}
