#!/usr/bin/perl

$FORC_DIR = "/raid8/forecast/sw_monitor/data/conus/forcing";
$dir1 = "$FORC_DIR/retro";
$dir2 = "$FORC_DIR/spinup_nearRT";
$dir3 = "$FORC_DIR/curr_spinup";

foreach $subdir ("asc_vicinp","asc_disagg") {

  opendir(DIR1,"$dir1/$subdir") or die "$0: ERROR: cannot open directory $dir1/$subdir\n";
  @filelist = grep !/^\./, readdir(DIR1);
  closedir(DIR1);

  foreach $file (@filelist) {
    $cmd = "tail -1045 $dir1/$subdir/$file | head -973 > $dir2/$subdir/$file";
    (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
    $cmd = "tail -72 $dir1/$subdir/$file > $dir3/$subdir/$file";
    (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
  }

}
