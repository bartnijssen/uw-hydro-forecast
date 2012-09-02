#!/usr/bin/perl

$indir = shift;
$prefix = shift;
$model = shift;
$distdir = shift;
$dist_prefix = shift;
$outdir = shift;

if ($model =~ /vic/i) {
  $collist = "8,9,10";
}
elsif ($model =~ /noah/i) {
  $collist = "6,7,8,9";
}
elsif ($model =~ /sac/i) {
  $collist = "6,7,8,9,10";
}
elsif ($model =~ /clm/i) {
  $collist = "6,7,8,9,10,11,12,13,14,15";
}
elsif ($model =~ /multimodel/i) {
  $collist = "2";
}

# Get list of files
#open(INDIR, $indir) or die "$0: ERROR: cannot open $indir for reading\n";
#@filelist = grep /^$prefix/, readdir(INDIR);
#close(INDIR);
$cmd = "ls $indir";
@filelist = grep /$prefix/, `$cmd`;

foreach $file (@filelist) {
  chomp $file;
  $file =~ s/^\s+//g;
  $distfile = $file;
  $distfile =~ s/$prefix/$dist_prefix/g;
  $dist_file_list = "$distdir/mon01/$distfile";
  for ($mon=2; $mon<=12; $mon++) {
    $subdir = sprintf "mon%02d", $mon;
    $dist_file_list = $dist_file_list . ",$distdir/$subdir/$distfile";
  }

  $cmd = "data2pctl_mly_mlydist.pl $indir/$file $collist $dist_file_list > $outdir/$file";
#print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

}
