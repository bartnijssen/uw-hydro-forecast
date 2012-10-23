#!<SYSTEM_PERL_EXE>

=pod

=head1 NAME

logtest.pl

=head1 SYNOPSIS

logtest.pl [options]

 Options:
    --help|h|?                  brief help message
    --man|info                  full documentation

=head1 DESCRIPTION

This script generates logging messages and is only meant as a tool for testing
the logging environment. The logging behavior is read from the log4perl
configuration file (SYSTEM_LOG_CONFIG).

=head1 USAGE NOTES

This script is useful when you want to test the logging environment. In the
logging configuration file for the individual applications (SYSTEM_LOG_CONFIG)
you can specify where to log to, for example, a socket, a file, or something
else.

 Examples for (SYSTEM_LOG_CONFIG):
 ---------------------------------
 Log to socket
 -------------
 log4perl.logger                     = TRACE, Socket
 log4perl.appender.Socket            = Log::Log4perl::Appender::Socket
 log4perl.appender.Socket.PeerAddr   = hydra 
 log4perl.appender.Socket.PeerPort   = 12345
 log4perl.appender.Socket.layout     = PatternLayout
 log4perl.appender.Socket.layout.ConversionPattern = %d %H[%P]: %p (%F:%L)> %m%n
 
 Log to file
 -----------
 log4perl.logger                     = TRACE, Logfile
 log4perl.appender.Logfile           = Log::Log4perl::Appender::File
 log4perl.appender.Logfile.filename  = forecast.log
 log4perl.appender.Logfile.mode      = append
 log4perl.appender.Logfile.autoflush = 1
 log4perl.appender.Logfile.syswrite  = 1
 log4perl.appender.Logfile.layout    = PatternLayout
 log4perl.appender.Logfile.layout.ConversionPattern = %d %H[%P]: %p (%F:%L)> %m%n
 
=cut
use warnings;
use strict;
use Log::Log4perl qw(:easy);
use Pod::Usage;
use Getopt::Long;
{
  my $help;
  my $man;
  my $result = GetOptions("help|h|?" => \$help,
                          "man|info" => \$man);
  pod2usage(-verbose => 2, -exitstatus => 0) if $man;
  pod2usage(-verbose => 2, -exitstatus => 0) if $help;
  Log::Log4perl->init('<SYSTEM_LOG_CONFIG>');
  TRACE("trace test message");
  DEBUG("debug test message");
  INFO("info test message");
  WARN("warn test message");
  ERROR("error test message");
  FATAL("fatal test message");
  LOGWARN("logwarn test message");
  LOGDIE("logdie test message");
}
