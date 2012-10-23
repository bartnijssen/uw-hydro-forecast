#!<SYSTEM_PERL_EXE> -w

=pod

=head1 NAME

publish_figs.pl

=head1 SYNOPSIS

publish_figs.pl
 [options] project model year month day

 Options:
    --help|h|?           brief help message
    --man|info           full documentation

 Required (in order):
    project              project (must have config.project.<project> file)

=head1 DESCRIPTION

Script to copy model results plots to web site

=cut

#-------------------------------------------------------------------------------
use lib qw(<SYSTEM_INSTALLDIR>/lib <SYSTEM_PERL_LIBS>);
use Log::Log4perl qw(:easy);
use Pod::Usage;
use Getopt::Long;

#-------------------------------------------------------------------------------
# Determine tools and config directories
#-------------------------------------------------------------------------------
$CONFIG_DIR = "<SYSTEM_INSTALLDIR>/config";

#-------------------------------------------------------------------------------
# Include external modules
#-------------------------------------------------------------------------------
# Subroutine for reading config files
use simma_util;

#-------------------------------------------------------------------------------
# Parse the command line
#-------------------------------------------------------------------------------
Log::Log4perl->init('<SYSTEM_LOG_CONFIG>');
my $result = GetOptions("help|h|?" => \$help,
                        "man|info" => \$man);
pod2usage(-verbose => 2, -exitstatus => 0) if $man;
pod2usage(-verbose => 2, -exitstatus => 0) if $help;
$PROJECT = shift;  # project name, e.g. conus mexico
pod2usage(-verbose => 1, -exitstatus => 1) if not defined($PROJECT);

#-------------------------------------------------------------------------------
# Set up constants
#-------------------------------------------------------------------------------
# Read project configuration info
$ConfigProject        = "$CONFIG_DIR/config.project.$PROJECT";
$var_info_project_ref = &read_config($ConfigProject);
%var_info_project     = %{$var_info_project_ref};

# Save relevant project info in variables
$DepotDir  = $var_info_project{"PLOT_DEPOT_DIR"};
$WebPubDir = $var_info_project{"WEB_PUB_DIR"} . "/$PROJECT";

#-------------------------------------------------------------------------------
# END settings
#-------------------------------------------------------------------------------
# Check for directories; create if necessary & possible
foreach $dir ($DepotDir, $WebPubDir) {
  if (!-d $dir) {
    LOGDIE("Directory $dir not found");
  }
}

# Copy plots
$cmd = "cp $DepotDir/* $WebPubDir/";
DEBUG($cmd);
(system($cmd) == 0) or LOGDIE("$cmd failed: $?");
