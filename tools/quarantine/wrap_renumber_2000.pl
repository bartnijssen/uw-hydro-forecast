#!/usr/bin/perl

# Root Directory - Edit this to reflect location of your SIMMA installation
$ROOT_DIR = "/raid8/forecast/sw_monitor";

# Tools directory
$TOOLS_DIR = "$ROOT_DIR/tools";

# Command-line arguments
$indir = shift;
$prefix = shift;
$outdir = shift;

opendir (INDIR, $indir) or die "$0: ERROR: cannot open $indir\n";
@filelist = grep /^$prefix/, readdir (INDIR);
closedir (INDIR);
#$cmd = "ls $indir";
#@filelist = grep /^$prefix/, `$cmd`;
#foreach (@filelist) {
#  chomp;
#  s/^\s+//;
#}

foreach $file (sort(@filelist)) {
  $cmd = "$TOOLS_DIR/renumber_2000.pl $indir/$file > $outdir/$file";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
}
