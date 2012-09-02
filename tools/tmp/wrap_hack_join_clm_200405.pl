#!/usr/bin/perl

$indir1 = shift;
$prefix = shift;
$startcol1 = shift;
$ncols = shift;
$indir2 = shift;
$startcol2 = shift;
$outdir = shift;

opendir(INDIR,$indir1) or die "$0: ERROR: cannot open directory $indir1 for reading\n";
@filelist = grep /^$prefix/, readdir(INDIR);
closedir(INDIR);

foreach $file (sort(@filelist)) {
  open (FILE1, "$indir1/$file") or die "$0: ERROR: cannot open file $indir1/$file for reading\n";
  open (FILE2, "$indir2/$file") or die "$0: ERROR: cannot open file $indir2/$file for reading\n";
  open (OUTFILE, ">$outdir/$file") or die "$0: ERROR: cannot open file $outdir/$file for writing\n";
  foreach (<FILE1>) {
    chomp;
    @fields1 = split /\s+/;
    $line2 = <FILE2>;
    chomp $line2;
    @fields2 = split /\s+/, $line2;
    for ($i=0;$i<$ncols;$i++) {
      $fields1[$startcol1+$i] = $fields2[$startcol2+$i];
    }
    $first = 1;
    foreach $field (@fields1) {
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
  close(FILE1);
  close(FILE2);
  close(OUTFILE);
}
