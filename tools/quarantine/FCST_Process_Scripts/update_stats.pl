#!/usr/bin/perl -w
# XDZ-2007: update the basin ESP/CPC forecast summary files (currently at ./w_reg/summ_stats/ )

$html = $ARGV[0];  # target file, e.g. ./w_reg/summ_stats/BAS.htm or BAS_diff.htm
$fcst = $ARGV[1];  # data file, e.g.  ./pnw/20070301.ESP/pnw.ESPstats(_DIFF)
$TYPE = $ARGV[2];  # ESP or CPC

#printf "%s\n%s\n%s\n",$html, $fcst, $TYPE;
#die;

$tmp = "$html.tmp";

open(HTML, "<$html") or die "can't open $html: $!\n";
open(DATA, "<$fcst") or die "can't open $fcst: $!\n";
open(TEMP, ">$tmp");

# print the file and search for the FORECAST TYPE
do {
  $line = <HTML>;
  print TEMP $line;
} until ($line =~ m/$TYPE/);

# search for FORECAST DATE
do {
  $line = <HTML>;
  print TEMP $line;
} until ($line =~ m/Forecast Date/);

$line = <HTML>;   # skip the old forecast date
$line = <DATA>;   # replace with current forecast date
print TEMP $line;

# search for "-------------", the line above the forecast data
do {
  $line = <HTML>;
  print TEMP $line;
} until ($line =~ /^-/);

# print current forecast data and close DATA
while ($line = <DATA>) {
  print TEMP $line;
}
close(DATA);

# skip old forecast data in html until "</pre>"
do {
  $line = <HTML>;
} until ($line =~ m/\/pre/);
print TEMP $line; # print "</pre>"

# print the rest part of html
while ($line = <HTML>) {
  print TEMP $line;
}
close(HTML);
close(TEMP);

# replace html with the new file
unlink $html;
rename $tmp, $html;

