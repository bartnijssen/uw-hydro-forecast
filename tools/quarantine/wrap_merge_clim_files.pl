#!/usr/bin/perl

# Root Directory - Edit this to reflect location of your SIMMA installation
$ROOT_DIR = "/raid8/forecast/sw_monitor";

# Tools directory
$TOOLS_DIR = "$ROOT_DIR/tools";

# Command-line arguments
$info_list = shift; # dir:prefix:col_in:col_out,dir:prefix:col_in:col_out,...
$ndate = shift;
$ncols = shift;
$nodata = shift;
$outdir = shift;
$outprefix = shift;

@info = split /,/, $info_list;
($refdir,$refprefix,$tmp,$tmp) = split /:/, $info[0];

opendir(REFDIR,$refdir) or die "$0: ERROR: cannot open directory $refdir for reading\n";
@filelist = grep /^$refprefix/, readdir(REFDIR);
#@filelist = grep !/^\./, readdir(REFDIR);
closedir(REFDIR);

foreach $reffile (sort(@filelist)) {
  $this_info_list = "";
  foreach $info_str (@info) {
    ($indir,$prefix,$col_in,$col_out) = split /:/, $info_str;
    $file = $reffile;
    $file =~ s/^$refprefix/$prefix/;
    if ($this_info_list) {
      $this_info_list = $this_info_list . ",$indir/$file:$col_in:$col_out";
    }
    else {
      $this_info_list = "$indir/$file:$col_in:$col_out";
    }
  }
  $outfile = $reffile;
  $outfile =~ s/^$refprefix/$outprefix/;
  $cmd = "$TOOLS_DIR/merge_clim_files.pl $this_info_list $ndate $ncols $nodata > $outdir/$outfile";
#  print "$cmd\n";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
}
