#!<SYSTEM_PERL_EXE> -T
=pod

=head1 NAME

logsocket.pl

=head1 SYNOPSIS

logsocket.pl

=head1 DESCRIPTION

This script starts a daemon that then puts itself in the background. The daemon
can be reinitialized by sending it a HUP signal or terminated by sending it an
INT or TERM signal (e.g. kill -TERM <pid>, where <pid> is the process id of the
server).

The daemon serves as a listener that listens on the port
(SYSTEM_LOG_SERVER_PORT) specified in the log4perl configuration file
(SYSTEM_LOG_SOCKET_CONFIG). All incoming messages are appended to the log file
(SYSTEM_LOG_FILE).

A process id file is created (SYSTEM_LOG_PID_FILE) to store the process id of
the running server. This file should not be deleted.

Configuration of the logging environment can be achieved by managing the
log4perl configuration file. The configuration file must specify a 'daemon' and
a 'socket' logger. The first will log info about the daemon itself. The second
will process the information that it receives on the port it is listening
on. The server re-reads the configuration file every minute, so the logging
environment can be changed dynamically.

Example logging setup for SYSTEM_LOG_SOCKET_CONFIG:
---------------------------------------------------
log4perl.logger.daemon            = TRACE, A1, Screen
log4perl.appender.A1              = Log::Log4perl::Appender::File
log4perl.appender.A1.filename     = daemon.log
log4perl.appender.A1.mode         = append
log4perl.appender.A1.autoflush    = 1
log4perl.appender.A1.syswrite     = 1
log4perl.appender.A1.layout       = PatternLayout
log4perl.appender.A1.layout.ConversionPattern = %d %H[%P]: %p (%F:%L)> %m%n
log4perl.appender.Screen          = Log::Log4perl::Appender::Screen
log4perl.appender.Screen.stderr   = 0
log4perl.appender.Screen.layout   = PatternLayout

log4perl.logger.server            = TRACE, A2
log4perl.appender.A2              = Log::Log4perl::Appender::File
log4perl.appender.A2.filename     = server.log
log4perl.appender.A2.mode         = append
log4perl.appender.A2.autoflush    = 1
log4perl.appender.A2.syswrite     = 1
log4perl.appender.A2.layout       = PatternLayout
log4perl.appender.A2.layout.ConversionPattern = %m

=head1 USAGE NOTES

This script is useful when you want to log information from processes on
multiple machines in a cetral location. For example, if you have a and want to
gather information in a central log file. Note that this may not be the best
solution with many hosts, when a lot of logging information is written, but it
should work in a simple environment.

If you are using this logsocket, then it needs to be started before the rest of
the forecast and it needs to be running. It may be a good idea, to restart the
server periodically to ensure that it is running before the forecast is started.

You can handle the setup of the programs that log to this socket through
log4perl as well. In the forecast system, the logging by the various utilities
is handled by log4perl(:easy). In the logging configuration file for the
individual applications (SYSTEM_LOG_CONFIG) you can specify whether to log to
this socket or whether to log directly to file.

Examples for (SYSTEM_LOG_CONFIG):
---------------------------------
Log to socket
-------------
log4perl.logger                     = TRACE, Socket
log4perl.appender.Socket            = Log::Log4perl::Appender::Socket
log4perl.appender.Socket.PeerAddr   = localhost 
log4perl.appender.Socket.PeerPort   = 12345
log4perl.appender.Socket.layout     = PatternLayout
log4perl.appender.Socket.layout.ConversionPattern = %d %H[%P]: %p (%F:%L)> %m%n

Log to file
-----------
log4perl.logger                     = TRACE, Logfile
log4perl.appender.Logfile           = Log::Log4perl::Appender::File
log4perl.appender.Logfile.filename  = server.log
log4perl.appender.Logfile.mode      = append
log4perl.appender.Logfile.autoflush = 1
log4perl.appender.Logfile.syswrite  = 1
log4perl.appender.Logfile.layout    = PatternLayout
log4perl.appender.Logfile.layout.ConversionPattern = %d %H[%P]: %p (%F:%L)> %m%n

=cut

use lib qw(<SYSTEM_INSTALLDIR>/lib <SYSTEM_PERL_LIBS>);
use warnings;
use strict;
use IO::Select;
use IO::Socket::INET;
use POSIX qw(:signal_h);
use Daemon;
use Log::Log4perl qw(get_logger);

my $listen_socket;
my $pid;
my $pidfile = '<SYSTEM_LOG_PID_FILE>';
my $daemonlog;
my $log;

{
  # initialize logging environment
  Log::Log4perl->init_and_watch('<SYSTEM_LOG_SOCKET_CONFIG>', 60);
  $daemonlog = get_logger('daemon');
  $log = get_logger('server');

  # catch HUP, INT and TERM signals
  my $sigset = POSIX::SigSet->new();
  my $sigaction = POSIX::SigAction->new(\&do_hup, $sigset, &POSIX::SA_NODEFER);
  POSIX::sigaction(&POSIX::SIGHUP, $sigaction);
  $sigaction = POSIX::SigAction->new(\&do_term, $sigset, &POSIX::SA_NODEFER);
  POSIX::sigaction(&POSIX::SIGTERM, $sigaction);
  POSIX::sigaction(&POSIX::SIGINT, $sigaction);

  # start the listener
  $pid = init_server($pidfile);
  $listen_socket = IO::Socket::INET->new(
                                         Listen    => <SYSTEM_LOG_SERVER_MAX_CONN>,
                                         LocalPort => <SYSTEM_LOG_SERVER_PORT>,
                                         Proto     => 'tcp');
  $daemonlog->warn("Server initialized and accepting connections ".
                   "[pid: $pid]\n");

  # listen carefully
  my $readable_handles = new IO::Select($listen_socket);
  while (1) {  #Infinite loop
    # select() scans sockets and moves to next after 0.01 s idle
    my ($new_readable) = IO::Select->select($readable_handles,
                                            undef, undef, 0.01);
    # If it comes here, there is at least one handle
    # to read from or write to. For the moment, worry only about 
    # the read side.
    foreach my $sock (@$new_readable) {
      if ($sock == $listen_socket) {
        my $new_sock = $sock->accept();
        # Add it to the list, and go back to select because the 
        # new socket may not be readable yet.
        $readable_handles->add($new_sock);
      } else {
        # It is an ordinary client socket, ready for reading.
        my $buf = <$sock>;
        if ($buf) {
          #log all messages coming in as they are. fatal() is used to make sure
          #all messages are recorded.
          $log->fatal($buf);
        } else {
          # Client closed socket. We do the same here, and remove
          # it from the readable_handles list
          $readable_handles->remove($sock);
          close($sock);
        }
      }
    }   
  }
}

sub do_hup {
  $daemonlog->warn("HUP signal received, attempting restart\n");
  close $listen_socket;
  kill_children();
  do_relaunch();
}

sub do_term {
  $daemonlog->warn("TERM signal received, exiting daemon\n");
  close $listen_socket;
  kill_children();
  exit 0;
}

END {
  $daemonlog->warn("Server exiting normally\n") if defined $pid and $$ == $pid;
}
