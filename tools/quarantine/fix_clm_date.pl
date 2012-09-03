#!/usr/bin/perl

# Root Directory - Edit this to reflect location of your SIMMA installation
$ROOT_DIR = "/raid8/forecast/sw_monitor";

# Tools directory
$TOOLS_DIR = "$ROOT_DIR/tools";

# Command-line arguments
$indir = shift;
$prefix = shift;
$start_col = shift; # indexing starts at 1 for "cut" command
$end_col = shift; # indexing starts at 1 for "cut" command
$start_date = shift;
$outdir = shift;

opendir(INDIR,$indir) or die "$0: ERROR: cannot open directory $indir for reading\n";
@filelist = grep /^$prefix/, readdir(INDIR);
#@filelist = grep !/^\./, readdir(INDIR);
closedir(INDIR);

foreach $file (sort(@filelist)) {
  $cmd = "cut -f$start_col-$end_col -d\" \" $indir/$file > $indir/$file.tmp";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
  $cmd = "add_date.pl $indir/$file.tmp $start_date 24 > $outdir/$file";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
  $cmd = "rm -f $indir/$file.tmp";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
}
