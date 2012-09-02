#!/usr/bin/perl

# Get config file name
$config_file = shift;

# Read config file
# Find tokens that match previously-read keys and replace them with corresponding values
open (CONFIG, $config_file) or die "$0: ERROR: cannot open config file $config_file\n";
foreach (<CONFIG>) {
  chomp;
  if (!/^#/ && /\S/) {
    @fields = split /\s+/;
    # fields[0] is a key
    # fields[1] is the value corresponding to that key
    $var_info{$fields[0]} = $fields[1];
    # Loop over previously-read hash keys
    # If the current value matches a hash key, substitute the value corresponding to the key
    foreach $key (keys(%var_info)) {
      $var_info{$fields[0]} =~ s/<$key>/$var_info{$key}/g;
    }
  }
  print "$fields[0] $var_info{$fields[0]}\n";
}
close(CONFIG);

