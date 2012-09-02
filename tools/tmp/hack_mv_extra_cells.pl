#!/usr/bin/perl

$indir = shift;
$outdir = "$indir.extra";

$multimodel_cell_list = "/raid8/forecast/sw_monitor/data/conus/params/misc/latlon.usa";

open (MM_CELLS, $multimodel_cell_list) or die "$0: ERROR: cannot open $multimodel_cell_list\n";
foreach (<MM_CELLS>) {
  chomp;
  s/^\s+//g;
  @fields = split /\s+/;
  push @mm_lats, $fields[1];
  push @mm_lons, $fields[2];
}
close(MM_CELLS);

opendir(INDIR,$indir) or die "$0: ERROR: cannot open directory $indir\n";
@filelist = grep !/^\./, readdir(INDIR);
closedir(INDIR);

foreach $file (@filelist) {
  if ($file =~ /^\S+_([\d\.-]+)_([\d\.-]+)/) {
    ($lat,$lon) = ($1,$2);
    $found = 0;
    for ($i=0; $i<@mm_lats; $i++) {
      if ($lat == $mm_lats[$i] && $lon == $mm_lons[$i]) {
        $found = 1;
      }
    }
    if (!$found) {
      $cmd = "mv $indir/$file $outdir/";
print "$cmd\n";
#      (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
    }
  }
}
