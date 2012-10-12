#!<SYSTEM_PERL_EXE> -w
# Tools Directory - Edit this to reflect location of your SIMMA installation
$TOOLS_DIR = "<SYSTEM_INSTALLDIR>/bin";

# Command-line arguments
$indir         = shift;
$prefix        = shift;
$ndate         = shift;
$outdir        = shift;
$col_pair_list = shift;
opendir(INDIR, $indir) or die "$0: ERROR: cannot open $indir\n";
@filelist = grep /^$prefix/, readdir(INDIR);
closedir(INDIR);

#$cmd = "ls $indir";
#@filelist = grep /^$prefix/, `$cmd`;
#foreach (@filelist) {
#  chomp;
#  s/^\s+//;
#}
foreach $file (sort(@filelist)) {
  $cmd =
    "$TOOLS_DIR/add_fields.pl $indir/$file $ndate $col_pair_list " .
    "> $outdir/$file";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
}
