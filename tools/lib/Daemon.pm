package Daemon;
# This code is based on Figure 14.7: Daemon.pm module with support for
# restarting the server in Stein, L. D., 2001: Network programming with
# perl. Addison-Wesley, Boston, etc.

# NOTE: It has been changed to use Log4perl for logging and no changing of
# privileges is performed because the daemon is not run as root. It has also
# been simplified since we are not launching additional child processes here. It
# simply puts itself in the background and will relaunch if given the HUP signal

# a logger needs to be specified for 'daemon' in the log4perl config file, e.g.
# log4perl.logger.daemon            = TRACE, A1, Screen
# log4perl.appender.A1              = Log::Log4perl::Appender::File
# log4perl.appender.A1.filename     = daemon.log
# log4perl.appender.A1.mode         = append
# log4perl.appender.A1.autoflush    = 1
# log4perl.appender.A1.syswrite     = 1
# log4perl.appender.A1.layout       = PatternLayout
# log4perl.appender.A1.layout.ConversionPattern = %d %H[%P]: %p (%F:%L)> %m%n
# log4perl.appender.Screen          = Log::Log4perl::Appender::Screen
# log4perl.appender.Screen.stderr   = 0

use strict;
use vars qw(@EXPORT @ISA @EXPORT_OK $VERSION);
use Log::Log4perl qw(get_logger);
use POSIX qw(setsid WNOHANG);
use Cwd;
use IO::File;
require Exporter;

@EXPORT_OK = qw(init_server kill_children do_relaunch
                %CHILDREN);
@EXPORT = @EXPORT_OK;
@ISA = qw(Exporter);
$VERSION = '1.00';

use vars qw(%CHILDREN);

my ($pid, $pidfile, $CWD, $log);

sub init_server {
  ($pidfile) = @_;
  # log4perl must be initialized in the calling code
  $log = get_logger('daemon') or die "Cannot get logger";
  my $fh = open_pid_file($pidfile);
  become_daemon();
  print $fh $$;
  close $fh;
  return $pid = $$;
}

sub become_daemon {
  $log->logdie("Can't fork") unless defined (my $child = fork);
  exit 0 if $child;    # parent dies;
  POSIX::setsid();     # become session leader
  $CWD = getcwd;       # remember working directory
  chdir '/';           # change working directory
  umask(0);            # forget file mode creation mask
  $ENV{PATH} = '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin';
  delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};
  $SIG{CHLD} = \&reap_child;
}

sub reap_child {
  while ( (my $child = waitpid(-1,WNOHANG)) > 0) {
    $CHILDREN{$child}->($child) if ref $CHILDREN{$child} eq 'CODE';
    delete $CHILDREN{$child};
  }
}

sub kill_children {
  kill TERM => keys %CHILDREN;
  # wait until all the children die
  sleep while %CHILDREN;
}

sub do_relaunch {
  chdir $1 if $CWD =~ m!([./a-zA-z0-9_-]+)!;
  $log->logdie("bad program name") unless $0 =~ m!([./a-zA-z0-9_-]+)!;
  my $program = $1;
  unlink $pidfile;
  my @args = ($program);
  exec @args or $log->logdie("Couldn't exec: $!");
}

sub open_pid_file {
  my $file = shift;
  if (-e $file) {  # oops.  pid file already exists
    my $fh = IO::File->new($file) || return;
    my $pid = <$fh>;
    $log->logdie("Invalid PID file") unless $pid =~ /^(\d+)$/;
    $log->warn("Server already running with PID $1\n") and exit(0) if kill 0 => $1;
    $log->warn("Removing PID file for defunct server process $pid.\n");
    $log->logdie("Can't unlink PID file $file") unless -w $file && unlink $file;
  }
  return IO::File->new($file,O_WRONLY|O_CREAT|O_EXCL,0644)
    or $log->logdie("Can't create $file: $!\n");
}

END { 
  unlink($pidfile) if defined $pid and $$ == $pid;
}

1;
__END__
