#!<SYSTEM_PERL_EXE> -w
$indir   = shift;
$numrecs = shift;
$outdir  = shift;
opendir(INDIR, $indir) or
  die "$0: ERROR: cannot open directory $indir for reading\n";
@filelist = grep !/^\./, readdir(INDIR);
closedir(INDIR);
foreach $file (sort(@filelist)) {
  $cmd = "tail -$numrecs $indir/$file > $outdir/$file";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
}
