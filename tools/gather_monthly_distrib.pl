#!/usr/bin/perl

$histdir = shift; # directory containing ascii-format historical monthly soil moistures
$prefix = shift;  # file prefix within the historical directory
$start_year = shift; # first year of historical record
$end_year = shift; # end year of historical record
$model = shift;   # model name
$outdir = shift;  # directory where normalized soil moistures will be stored
$prefix_out = shift;  # file prefix for output directory

# Create monthly subdirectories
for ($midx=0; $midx<12; $midx++) {
  $month_str = sprintf "%02d", $midx+1;
  $tmp_dir = $outdir . "/mon" . $month_str;
  if (! -e "$tmp_dir") {
    $cmd = "mkdir $tmp_dir";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
  }
}

# Get list of input files
opendir(HISTDIR,$histdir) or die "$0: ERROR: cannot open $histdir for reading\n";
@filelist = grep /^$prefix/, readdir(HISTDIR);
closedir(HISTDIR);

# Gather soil moisture distributions for each input file
foreach $file (@filelist) {

  # Read input file & compute total soil moistures
  open (FILE, "$histdir/$file") or die "$0: ERROR: cannot open $histdir/$file for reading\n";
  foreach (<FILE>) {
    chomp;
    @fields = split /\s+/;
    if ($fields[0] < $start_year || $fields[0] > $end_year) {
      next;
    }
    $yidx = $fields[0] - $start_year;
    $midx = $fields[1]-1;
    if ($model =~ /vic/i) {
      $soilmoist = $fields[8] + $fields[9] + $fields[10];
    }
    elsif ($model =~ /noah/i) {
      $soilmoist = $fields[6] + $fields[7] + $fields[8] + $fields[9];
    }
    elsif ($model =~ /sac/i) {
      $soilmoist = $fields[6] + $fields[7] + $fields[8] + $fields[9] + $fields[10];
    }
    elsif ($model =~ /clm/i) {
      $soilmoist = $fields[6] + $fields[7] + $fields[8] + $fields[9] + $fields[10] + $fields[11] + $fields[12] + $fields[13] + $fields[14] + $fields[15];
    }
    elsif ($model =~ /multimodel/i) {
      $soilmoist = $fields[2];
    }
    $soilmoist_list[$midx][$yidx] = $soilmoist;
  }
  close(FILE);

  # For each month, sort soil moistures and save in a file
  $file_out = $file;
  $file_out =~ s/$prefix/$prefix_out/;
  for ($midx=0; $midx<12; $midx++) {
    @soilmoist_sort = sort { $a <=> $b; } @{$soilmoist_list[$midx]};
    $month_str = sprintf "%02d", $midx+1;
    $tmp_dir = $outdir . "/mon" . $month_str;
    open (OUTFILE, ">$tmp_dir/$file_out") or die "$0: ERROR: cannot open $tmp_dir/$file_out for writing\n";
    for ($i=0; $i<$end_year-$start_year+1; $i++) {
      printf OUTFILE "%.4f\n", $soilmoist_sort[$i];
    }
    close(OUTFILE);
  }
}
