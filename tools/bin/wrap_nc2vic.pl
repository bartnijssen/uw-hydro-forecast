#!/usr/bin/env perl
use warnings;

# Tools directory
$TOOLS_DIR = "<SYSTEM_INSTALLDIR>/bin";

# Command-line arguments
$indir      = shift;
$prefix     = shift;
$varlist    = shift;
$outdir     = shift;
$prefix_out = shift;
$format     = shift;  # this is optional - if omitted, nc2vic will use its
                      # default format

# Format
if ($format) {
  $format = "-f " . $format;
}
opendir(INDIR, $indir) or die "$0: ERROR: cannot open $indir\n";
@filelist = grep /^$prefix/, readdir(INDIR);
closedir(INDIR);

#$cmd = "ls $indir";
#@filelist = grep /^$prefix/, `$cmd`;
#foreach (@filelist) {
#  chomp;
#  s/^\s+//;
#}
$append = "";
foreach $file (sort(@filelist)) {
  $cmd =
    "$TOOLS_DIR/nc2vic -i $indir/$file -o $outdir -p $prefix_out " .
    "-v $varlist $append $format -t";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
  $append = "-a";
}
