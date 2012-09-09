#!/usr/bin/env perl
use warnings;
# Root Directory - Edit this to reflect location of your SIMMA installation
$ROOT_DIR = "<BASEDIR>";

# Tools directory
$TOOLS_DIR = "$ROOT_DIR/tools";

# Command-line arguments
$indir = shift;
$prefix = shift;
$ndate = shift;
$field = shift;
$factor = shift;
$outdir = shift;

opendir(INDIR,$indir) or die "$0: ERROR: cannot open directory $indir for reading\n";
@filelist = grep /^$prefix/, readdir(INDIR);
#@filelist = grep !/^\./, readdir(INDIR);
closedir(INDIR);

foreach $file (sort(@filelist)) {
  $cmd = "$TOOLS_DIR/bin/mult_fields.pl $indir/$file $ndate $field $factor > $outdir/$file";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
}
