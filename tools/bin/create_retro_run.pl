#!<SYSTEM_PERL_EXE> -w

=pod

=head1 NAME

create_retro_run.pl

=head1 SYNOPSIS

create_retro_run.pl
 [options] --model=model --project=project --start=startdate --end=enddate

 Options:
    --help|h|?                  brief help message
    --man|info                  full documentation
    --verbose|v                 increase verbosity
    --route|r                   route the flows

 Required:
    --model|m=model             model to run
                                Requires a config.model.<model> file in the
                                config directory
    --project|p=project         project to run
                                Requires a config.project.<project> file in the
                                config directory
    --start|s=YYYY-MM-DD        start date of retrospective run
    --end|e=YYYY-MM-DD          end date of retrospective run


=head1 DESCRIPTION

Create a retrospective run. For details, see 
https://github.com/bartnijssen/uw-hydro-forecast/wiki/Creating-a-retrospective-run

=head1 PREREQUISITES

=head2 Software

This script is part of the UW Hydro Forecast system. It relies on other scripts
and libraries in that same system to run. This means that the script does
necessarily work as a standalone program.

=cut
use lib qw(<SYSTEM_INSTALLDIR>/lib <SYSTEM_PERL_LIBS>);
use Getopt::Long;
use Pod::Usage;
use Date::Calc qw(Delta_Days Add_Delta_YMD);
use POSIX qw(strftime);
use File::Temp qw(tempfile);
use File::Copy qw(move);
use strict;  # sanity!!
my $cleanup = 1;

#-------------------------------------------------------------------------------
# Determine tools and config directories
#-------------------------------------------------------------------------------
my $TOOLS_DIR  = "<SYSTEM_INSTALLDIR>/bin";
my $CONFIG_DIR = "<SYSTEM_INSTALLDIR>/config";

#-------------------------------------------------------------------------------
# Include external modules
#-------------------------------------------------------------------------------
# Subroutine for reading config files
use simma_util;
use GenUtils;

#-------------------------------------------------------------------------------
# Parse the command-line arguments
#-------------------------------------------------------------------------------
# Get the Project name and Current date from nowcast_model.pl
my $help;
my $man;
my $model;
my $project;
my $start_date;
my $end_date;
my $routeflows;
my $verbose = 0;

# Hash used in GetOptions function
my $status = GetOptions(
                        "help|h|?"    => \$help,
                        "man|info"    => \$man,
                        "verbose|v"   => \$verbose,
                        "model|m=s"   => \$model,
                        "project|p=s" => \$project,
                        "start|s=s"   => \$start_date,
                        "end|e=s"     => \$end_date,
                        "route|r"     => \$routeflows
                       );

#-------------------------------------------------------------------------------
# Validate the command-line arguments
#-------------------------------------------------------------------------------
# Help option
pod2usage(-verbose => 2, -exitstatus => 0) if $man;
pod2usage(-verbose => 2, -exitstatus => 0) if $help;
pod2usage(-verbose => 1, -exitstatus => 1)
  if not defined $model or
    not defined $project    or
    not defined $start_date or
    not defined $end_date;

# Parse & validate start/end dates
my @startdate = parse_yyyymmdd($start_date, "-");
@startdate == 3 or die "$0: ERROR: start date must have format YYYY-MM-DD.\n";
isdate(@startdate) or die "Not a valid start date: $start_date\n";
my @enddate = parse_yyyymmdd($end_date, "-");
@enddate == 3 or die "$0: ERROR: end date must have format YYYY-MM-DD.\n";
isdate(@enddate) or die "Not a valid end date: $end_date\n";
Delta_Days(@startdate, @enddate) > 0 or
  die "$0: ERROR: start date is later than end date.\n";

# Unique identifier for this job
my $JOB_ID = strftime "%y%m%d-%H%M%S", localtime;

# Read project configuration info
my $ConfigProject        = "$CONFIG_DIR/config.project.$project";
my $var_info_project_ref = &read_config($ConfigProject);
my %var_info_project     = %{$var_info_project_ref};

# Read model configuration info
my $ConfigModel        = "$CONFIG_DIR/config.model.$model";
my $var_info_model_ref = &read_config($ConfigModel);
my %var_info_model     = %{$var_info_model_ref};

# Substitute model-specific information into project variables
foreach my $key_proj (keys(%var_info_project)) {
  foreach my $key_model (keys(%var_info_model)) {
    $var_info_project{$key_proj} =~
      s/<$key_model>/$var_info_model{$key_model}/g;
  }
}
$var_info_project{"LOGS_MODEL_DIR"} =~ s/<LOGS_SUBDIR>/retro/g;
my $LogDir = $var_info_project{"LOGS_MODEL_DIR"};
foreach my $dir ($LogDir) {
  (&make_dir($dir) == 0) or die "$0: ERROR: Cannot create path $dir: $!\n";
}
my $LogFile = "$LogDir/log.$project.$model.create_retro_run.pl.$JOB_ID";

# First pass through: cold start for full period
my $cmd =
  "$TOOLS_DIR/run_model.pl -m $model -p $project -f retro " .
  "-s $start_date -e $end_date " . ">& $LogFile.tmp";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
$cmd = "cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
$cmd = "rm -f $LogFile.tmp";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";

# Recycle model state from end of run and run for a single year 10 times
my $state_subdir =
  $var_info_project{STATE_DIR} . '/' . $var_info_project{RETRO_SUBDIR} . '/' .
  $var_info_model{MODEL_ALIAS};
my $initfile =
  $state_subdir . '/' . 'state_' . sprintf("%04d%02d%02d", @enddate);
my @enddate_oneyear = Add_Delta_YMD(@startdate, 1, 0, -1);
my $enddate_oneyear = sprintf("%04d-%02d-%02d", @enddate_oneyear);

# Create a temporary state file to store the state we're reading so that
# it is not overwritten by the state we are writing
my ($tmpfh, $tmpfilename) =
  tempfile(
           'tempstate_XXXXXX',
           DIR     => $state_subdir,
           CLEANUP => $cleanup
          );
for (my $i = 0 ; $i < 10 ; $i++) {
  $cmd =
    "$TOOLS_DIR/run_model.pl -m $model -p $project -f retro " .
    "-s $start_date -e $enddate_oneyear -i $initfile";
  $cmd .= " -l" if ("<SYSTEM_LOCAL_STORAGE>" =~ /true/i);
  $cmd .= " >& $LogFile.tmp";
  print "$cmd\n";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
  $cmd = "cat $LogFile.tmp >> $LogFile";
  print "$cmd\n";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
  $cmd = "rm -f $LogFile.tmp";
  print "$cmd\n";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
  $initfile =
    $state_subdir . '/' . 'state_' . sprintf("%04d%02d%02d", @enddate_oneyear);
  move($initfile, $tmpfilename) or
    die "Error: Cannot move $initfile to $tmpfilename: $!\n";
  $initfile = $tmpfilename;
}

# Run the model once more for the full period.
$cmd =
  "$TOOLS_DIR/run_model.pl -m $model -p $project -f retro " .
  "-s $start_date -e $end_date -i $initfile";
$cmd .= " -l" if ("<SYSTEM_LOCAL_STORAGE>" =~ /true/i);
$cmd .= " >& $LogFile.tmp";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
$cmd = "cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
$cmd = "rm -f $LogFile.tmp";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";

# Cleanup: $cleanup = 1 doesn't remove the tempfile, because it was overwritten
# I presume. So we will do it ourselves
if ($cleanup and -e $tmpfilename) {
  unlink $tmpfilename or warn "Warning: Cannot remove $tmpfilename: $!\n";
}
