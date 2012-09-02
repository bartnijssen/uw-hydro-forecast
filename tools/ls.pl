#!/usr/bin/perl

$dir = shift;

opendir(DIR,$dir);
@files = readdir(DIR);
closedir(DIR);

foreach (@files) {
  print "$_\n";
}
