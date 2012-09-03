#!/usr/bin/perl

$indir = shift;
$lag = shift;

#opendir(INDIR,$indir) or die "$0: ERROR: cannot open directory $indir for reading\n";
#@filelist = grep !/^\./, readdir(INDIR);
#closedir(INDIR);
$cmd = "ls $indir";
@filelist = `$cmd`;
foreach (@filelist) {
  chomp;
  s/^\s+//;
}

foreach $file (@filelist) {
  if ($file =~ /^[^\_]+\_([^\_]+)\_([^\_]+)$/) {
    ($lat,$lon) = ($1,$2);
  }
  open (FILE, "$indir/$file") or die "$0: ERROR: cannot open file $indir/$file for reading\n";
  $lidx=0;
  LAG_LOOP: foreach (<FILE>) {
    chomp;
    if ($lidx == $lag) {
      $auto = $_;
      last LAG_LOOP;
    }
    $lidx++;
  }
  close(FILE);
  print "$lat $lon $auto\n";
}
