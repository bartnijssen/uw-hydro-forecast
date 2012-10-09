# This package contains a library with a large number of utility functions
# that are useful for the UW Hydro Forecast System 

=pod

=head1 NAME

GenUtils.pm

=head1 SYNOPSIS

use GenUtils;

=head1 DESCRIPTION

The GenUtils module implements a large number of routines that are generally useful for running and operating the UW Hydro Forecast System. Currently it largely serves as a kitchen sink of commonly-used functions and it could be separated into general purpose and forecast specific functions in the future.

=cut

package GenUtils;

use strict;
use Date::Calc qw(check_date
                  leap_year);
                  
use vars qw(@ISA @EXPORT $VERSION);

use Exporter;
$VERSION = 0.99;		
@ISA = qw(Exporter);

# symbols to autoexport (:DEFAULT tag)
@EXPORT = qw(equal
             integer
             isdate
             isleapyear
             isreal
             parse_yyyymmdd
             stripcomments
             system_call
             testpath
             trim);

##################################### equal ####################################
# equal(NUM1, NUM2, ACCURACY) : returns true if NUM1 and NUM2 are
# equal to ACCURACY number of decimal places
# From Perl cookbook
sub equal {
  my ($A, $B, $dp) = @_;
  
  return sprintf("%.${dp}g", $A) eq sprintf("%.${dp}g", $B);
}

#################################### isdate ####################################
sub isdate {
  my (@date) = @_;

  return check_date(@date);
}

################################### isinteger ##################################
sub isinteger {
  my ($string) = @_;

  $string =~ /^-?\d+$/ or return 0;

  return 1;
}

################################## isleapyear ##################################
sub isleapyear {
  my ($year) = @_;

  return leap_year($year);

  return 0;
}

#################################### isreal ####################################
sub isreal {
  my ($string) = @_;

  $string =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/ or return 0;

  return 1;
}

################################ parse_yyyymmdd ################################
sub parse_yyyymmdd {
  my ($datestr, $sep) = @_;
  my @date;

  if (defined($sep)) {
    @date = split /$sep/, $datestr;
  } else {
    @date = ($datestr =~ /^(\d{4})(\d{2})(\d{2})/);
  }
  return @date;
}

################################ stripcomments #################################
sub stripcomments {
  my @out = @_;
  foreach (@out) {
    s/#.*//;
  }
  return wantarray ? @out : $out[0];
}

################################## system_call #################################
sub system_call {
  my ($command, @args) = @_;
  my $dumped_core;
  my $exit_val;
  my $rc;
  my $signal_num;
  

  $rc = 0xffff & system($command, @args);
  $exit_val = $rc >> 8;
  $signal_num = $rc & 127;
  $dumped_core = $rc & 128;

  return ($exit_val, $signal_num, $dumped_core);
}

#################################### testpath ##################################
sub testpath {
  my ($path, $checks) = @_;

  if ($checks =~ /e/) {
    -e $path or return "Error: path does not exist: $path";
  }
  if ($checks =~ /d/) {
    -d $path or return "Error: Not a directory: $path";
  }
  if ($checks =~ /f/) {
    -f $path or return "Error: Not a file: $path";
  }
  if ($checks =~ /r/) {
    -r $path or return "Error: Not readable: $path";
  }
  if ($checks =~ /w/) {
    -w $path or return "Error: Not writable: $path";
  }
  if ($checks =~ /x/) {
    -x $path or return "Error: Not executable: $path";
  }

  return "success";
}

##################################### trim #####################################
sub trim {
  my @out = @_;
  foreach (@out) {
    s/^\s+//;
    s/\s+$//;
  }
  return wantarray ? @out : $out[0];
}

1;
