#!/usr/bin/perl

$indir = shift;
$prefix_in = shift;
$outdir = shift;
$prefix_out = shift;

opendir (INDIR, $indir) or die "$0: ERROR: cannot open input directory $indir for reading\n";
@filelist = grep /^$prefix_in/, readdir(INDIR);
closedir(INDIR);
@filelist = sort(@filelist);

foreach $file (@filelist) {
  $outfile = $file;
  $outfile =~ s/$prefix_in/$prefix_out/g;
  $cmd = "mv $indir/$file $outdir/$outfile";
#print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
}
