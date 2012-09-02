#!/usr/bin/perl

$indir_list = shift; # comma-separated
$prefix_in = shift;
$ndate = shift;
$precision = shift;
$outdir = shift;
$prefix_out = shift;

@indirs = split /,/, $indir_list;

opendir(INDIR,$indirs[0]) or die "$0: ERROR: cannot open directory $indirs[0] for reading\n";
@filelist = grep /^$prefix_in/, readdir(INDIR);
closedir(INDIR);

foreach $file (sort(@filelist)) {
  $file_list_str = "$indirs[0]/$file";
  for ($i=1;$i<@indirs;$i++) {
    $file_list_str .= ",$indirs[$i]/$file";
  }
  $outfile = $file;
  $outfile =~ s/$prefix_in/$prefix_out/g;
  $cmd = "avg_files.pl $file_list_str $ndate $precision > $outdir/$outfile";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
}
