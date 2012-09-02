#!/usr/bin/perl

$distdir = shift;
$dist_prefix = shift;

for ($midx=0; $midx<12; $midx++) {

  $monthstr = sprintf "%02d", $midx+1;
  $dist_full_dir = $distdir . "/mon" . $monthstr;
  $outfile = $distdir . "/smdstr.mon" . $monthstr . ".txt";
  open (OUTFILE, ">$outfile") or die "$0: ERROR: cannot open $outfile for writing\n";

  # Get list of files
  #open(INDIR, $dist_full_dir) or die "$0: ERROR: cannot open $dist_full_dir for reading\n";
  #@filelist = grep /^$prefix/, readdir(INDIR);
  #close(INDIR);
  $cmd = "ls $dist_full_dir";
  @filelist = grep /$prefix/, `$cmd`;

  foreach $file (@filelist) {
    chomp $file;
    $file =~ s/^\s+//g;
    if ($file =~ /$prefix\_([^\_]+)\_([^\_]+)$/) {
      ($lat,$lon) = ($1,$2);
    }
    print OUTFILE "$lat $lon";
    @dist = ();
    open (FILE, "$dist_full_dir/$file") or die "$0: ERROR: cannot open $dist_full_dir/$file for reading\n";
    foreach (<FILE>) {
      chomp;
      push @dist, $_;
    }
    close(FILE);
    $nDist = @dist;
    for ($i=0; $i<$nDist; $i++) {
      print OUTFILE " $dist[$i]";
    }
    print OUTFILE "\n";
  }

  close(OUTFILE);

}
