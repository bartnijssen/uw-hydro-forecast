#!/usr/bin/perl

$infile = shift;
$ndate = shift;
$infolist = shift;

@infos = split /,/, $infolist;
foreach $info (@infos) {
  ($col,$factor) = split /:/, $info;
  push @cols, $col;
  push @factors, $factor;
}

open (INFILE,$infile) or die "$0: ERROR: cannot open $infile\n";
foreach (<INFILE>) {
  chomp;
  @fields = split /\s+/;
  @date = $fields[0..$ndate-1];
  print "$date[0]";
  for ($i=1; $i<$ndate; $i++) {
    print " $date[$i]";
  }
  for ($i=0; $i<@cols; $i++) {
    $data = $fields[$cols[$i]-1]*$factors[$i];
    printf " %8.3f\n", $data;
  }
}
close (INFILE);
