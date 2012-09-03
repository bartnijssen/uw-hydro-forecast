#!/usr/bin/perl

# This script maps out the response time, i.e. number of time step lags for which
# the autocorrelation is > 1/e (0.368)

$indir = shift; # Directory containing autocorrelation time series files, 1 per grid cell

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
    $auto = $_;
    if ($auto < 0.368) {
      last LAG_LOOP;
    }
    $lidx++;
  }
  close(FILE);
  print "$lat $lon $lidx\n";
}
