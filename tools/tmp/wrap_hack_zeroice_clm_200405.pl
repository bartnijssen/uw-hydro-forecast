#!/usr/bin/perl

$indir = shift;
$prefix = shift;
$startcol = shift;
$ncols = shift;
$outdir = shift;

opendir(INDIR,$indir) or die "$0: ERROR: cannot open directory $indir for reading\n";
@filelist = grep /^$prefix/, readdir(INDIR);
closedir(INDIR);

foreach $file (sort(@filelist)) {
  open (FILE, "$indir/$file") or die "$0: ERROR: cannot open file $indir/$file for reading\n";
  open (OUTFILE, ">$outdir/$file") or die "$0: ERROR: cannot open file $outdir/$file for writing\n";
  foreach (<FILE>) {
    chomp;
    @fields = split /\s+/;
    for ($i=0;$i<$ncols;$i++) {
      $fields[$startcol+$i] = 0;
    }
    $first = 1;
    foreach $field (@fields) {
      if ($first) {
        $first = 0;
        print OUTFILE "$field";
      }
      else {
        print OUTFILE " $field";
      }
    }
    print OUTFILE "\n";
  }
  close(FILE);
  close(OUTFILE);
}
