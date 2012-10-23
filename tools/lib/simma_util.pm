package simma_util;

use strict;

use vars qw(@ISA @EXPORT $VERSION);
use File::Path qw(make_path);
use Log::Log4perl qw(:easy);

use Exporter;
$VERSION = 0.99;		
@ISA = qw(Exporter);

# symbols to autoexport (:DEFAULT tag)
@EXPORT = qw(read_config
             make_dir
             shell_cmd);



#-------------------------------------------------------------------------------
# simma_util.pm - utility subroutines for use in the SIMMA framework.
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# read_config - reads a config file and returns a hash containing the key-value
# pairs
#
# usage: $var_info_ref = &read_config($config_file);
#
# Input:
#   $config_file = Config file name (including path)
#
# Output:
#   $var_info_ref = reference to the hash containing key-value pairs
#                   repeated occurrences of a key result in the new value being
#                   appended to the old value with a ";;" separator
#-------------------------------------------------------------------------------
sub read_config {
  my $config_file;
  my @fields;
  my %var_info;
  my $key;
  my $tmp_key;
  my $value;

  # Get config file name
  $config_file = $_[0];

  # Read config file
  # Find tokens that match previously-read keys and replace them with
  # corresponding values
  open(CONFIG, $config_file) or
    LOGDIE("Cannot open config file $config_file");
  foreach (<CONFIG>) {
    chomp;
    if (!/^#/ && /\S/) {
      @fields = split /\s+/;
      $key    = shift @fields;
      $value  = join " ", @fields;

      # Loop over previously-read hash keys
      # If the current value matches a hash key, substitute the value
      # corresponding to the key
      foreach $tmp_key (keys(%var_info)) {
        $value =~ s/<$tmp_key>/$var_info{$tmp_key}/g;
      }
      if (!$var_info{$key}) {
        $var_info{$key} = $value;
      } else {

        # If this key has been encountered already, append the new value to the
        # previous value with a ";;" as a separator
        $var_info{$key} = $var_info{$key} . ";;" . $value;
      }
    }
  }
  close(CONFIG);
  return \%var_info;
}

#-------------------------------------------------------------------------------
# make_dir - creates a directory, including all necessary parent directories.
#
# usage: $status = &make_dir($fullpath);
#
# Input:
#   $fullpath = directory to create.
#
# Output:
#   0: successfully created the directory.
#   All other codes: these are the operating system error codes returned by the
#   command
#
# Updated to simply use the File::Path qw(make_path) function
#
#-------------------------------------------------------------------------------
sub make_dir {
  my $fullpath = $_[0];
  make_path($fullpath, {error => \my $err});
  return @$err;                 # length 0 if no error
}

#-------------------------------------------------------------------------------
# shell_cmd - given a string containing a command, executes it in the shell.
#
# usage: $status = &shell_cmd($cmd,$log);
#
# Input:
#   $cmd  = String containing the command to execute, appearing exactly as it
#           would be entered by hand.  The entire string should be enclosed in
#           double quotes.
#   $log  = (optional) Name of log file to write any output to.
#           Default: output written to STDOUT.
#
# Output:
#   0: successfully executed the command.
#   All other codes: these are the operating system error codes returned by the
#   command
#-------------------------------------------------------------------------------
sub shell_cmd {
  my $my_cmd = $_[0];
  my $my_log = $_[1];
  my @messages;
  my $exit_code = 0;
  @messages = `$my_cmd 2>&1`;
  if ($?) {
    $exit_code = $?;
  }
  if ($my_log) {
    if (!open(LOGFILE, ">>$my_log")) {
      printf STDERR "$0: ERROR: cannot open log file $my_log\n";
    } else {
      print LOGFILE @messages;
      close(LOGFILE);
    }
  } else {
    print STDOUT @messages;
  }
  return $exit_code;
}

#-------------------------------------------------------------------------------
# This line is necessary for the contents of this file to be included in other
# perl programs via a "require" statement
#-------------------------------------------------------------------------------
1;
