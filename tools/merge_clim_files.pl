#!/usr/bin/perl

$file_info = shift; # filename:col_in:col_out,filename:col_in:col_out,filename:col_in:col_out,...
$ndate = shift; # number of date fields (from first file)
$ncols = shift;
$nodata = shift;

$last_date_col = $ndate-1;

$first = 1;
foreach $info (split /,/, $file_info) {

  ($file,$col_in,$col_out) = split /:/, $info;
  open (FILE, "$file") or die "$0: ERROR: cannot open $file for reading\n";
  $i=0;
  foreach (<FILE>) {
    chomp;
    @fields = split /\s+/;
    if ($first) {
      if ($ndate) {
        @{$date[$i]} = @fields[0..$last_date_col];
      }
      for ($j=0; $j<$ncols; $j++) {
        $data[$i][$j] = $nodata;
      }
    }
    $data[$i][$col_out] = $fields[$col_in];
    $i++;
  }
  close(FILE);

  $first = 0;

}
$nRecs = $i;

for ($i=0; $i<$nRecs; $i++) {
  if ($ndate) {
    printf "%s", $date[$i][0];
    for ($j=1; $j<$ndate; $j++) {
      printf " %s", $date[$i][$j];
    }
  }
  for ($j=$ndate; $j<$ncols; $j++) {
    printf " %.4f", $data[$i][$j];
  }
  printf "\n";
}
