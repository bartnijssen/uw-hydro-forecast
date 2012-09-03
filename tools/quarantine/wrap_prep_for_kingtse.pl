#!/usr/bin/perl

$model = shift;
$indir = shift;
$prefix = shift;
$tmpdir = shift;
$tmpdir2 = shift;
$outdir = shift;
$outprefix = shift;

if (!-e $tmpdir) {
  `mkdir $tmpdir`;
}
if (!-e $tmpdir2) {
  `mkdir $tmpdir2`;
}
if (!-e $outdir) {
  `mkdir $outdir`;
}

opendir (INDIR, $indir) or die "$0: ERROR: cannot open input directory $indir for reading\n";
@filelist = grep /^$prefix/, readdir(INDIR);
closedir (INDIR);
@filelist = sort(@filelist);

foreach $file (@filelist) {
  if ($model eq "vic") {
    $cmd = "add_fields.pl $indir/$file 3 8:9:10 > $tmpdir/$file";
  }
  elsif ($model eq "clm") {
    $cmd = "add_fields.pl $indir/$file 4 8:9:10:11:12:13:14:15:16:17 > $tmpdir/$file";
  }
  elsif ($model =~ /noah/) {
    $cmd = "add_fields.pl $indir/$file 4 8:9:10:11 > $tmpdir/$file";
  }
  elsif ($model =~ /sac/) {
    $cmd = "add_fields.pl $indir/$file 4 8:9:10:11:12 > $tmpdir/$file";
  }
  (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
  $cmd = "cut -f1-3,9 -d \" \" $tmpdir/$file > $tmpdir2/$file";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
  $outfile = $file;
  $outfile =~ s/$prefix/$outprefix/;
  $cmd = "agg_time.pl -i $tmpdir2/$file -in daily -o $outdir/$outfile -out monthly";
  (system($cmd)==0) or die "$0: ERROR: $cmd failed\n";
}
