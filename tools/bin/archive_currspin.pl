#!<SYSTEM_PERL_EXE> -w

=pod

=head1 NAME

add_fields.pl

=head1 SYNOPSIS

archive_currspin.pl [options] project model

 Options:
    --help|h|?                  brief help message
    --man|info                  full documentation

 Required:
    project
    model

=head1 DESCRIPTION

This script archives the flux files from the curr_spin directory for the defined
project and model combination (each must have a config file). The archived files
are put into the PLOT_DEPOT_DIR as defined in the config.project.<project> file.

=cut

#-------------------------------------------------------------------------------
use lib qw(<SYSTEM_INSTALLDIR>/lib <SYSTEM_PERL_LIBS>);

#-------------------------------------------------------------------------------
# Determine tool and config directories
#-------------------------------------------------------------------------------
$CONFIG_DIR = "<SYSTEM_INSTALLDIR>/config";

#-------------------------------------------------------------------------------
# Include external modules
#-------------------------------------------------------------------------------
use Pod::Usage;
use Getopt::Long;

# Subroutine for reading config files
use simma_util;

#-------------------------------------------------------------------------------
# Command-line arguments
#-------------------------------------------------------------------------------
my $result = GetOptions("help|h|?"    => \$help,
                        "man|info"    => \$man);

pod2usage(-verbose => 2, -exitstatus => 0) if $man;
pod2usage(-verbose => 2, -exitstatus => 0) if $help;

$PROJECT = shift;
$MODEL   = shift;

pod2usage(-verbose => 1, -exitstatus => 1) 
  if not defined($PROJECT) or not defined($MODEL);

#-------------------------------------------------------------------------------
# Set up constants
#-------------------------------------------------------------------------------
# Read project configuration info
$ConfigProject        = "$CONFIG_DIR/config.project.$PROJECT";
$var_info_project_ref = &read_config($ConfigProject);
%var_info_project     = %{$var_info_project_ref};

# Read model configuration info
$ConfigModel        = "$CONFIG_DIR/config.model.$MODEL";
$var_info_model_ref = &read_config($ConfigModel);
%var_info_model     = %{$var_info_model_ref};
$modelalias         = $var_info_model{MODEL_ALIAS};
if ($modelalias ne "vic") {
  exit(0);
}

# Substitute model-specific information into project variables
foreach $key_proj (keys(%var_info_project)) {
  foreach $key_model (keys(%var_info_model)) {
    $var_info_project{$key_proj} =~
      s/<$key_model>/$var_info_model{$key_model}/g;
  }
}

# Substitute user-specified information into project and model variables
$var_info_project{"RESULTS_MODEL_ASC_DIR"} =~
  s/<RESULTS_SUBDIR>/$var_info_project{"CURR_SUBDIR"}/g;

# Save relevant project info in variables
$ResultsModelAscDir = $var_info_project{"RESULTS_MODEL_ASC_DIR"};

# The final processed model results will be stored in the ascii dir
$ResultsModelFinalDir = $ResultsModelAscDir;
$DepotDir             = $var_info_project{"PLOT_DEPOT_DIR"};

# Check for directories; create if necessary & possible
foreach $dir ($ResultsModelFinalDir, $DepotDir) {
  if (!-d $dir) {
    die "$0: ERROR: directory $dir not found\n";
  }
}
foreach $dir ($DepotDir) {
  (&make_dir($dir) == 0) or die "$0: ERROR: Cannot create path $dir: $!\n";
}
$Archive = "curr_spinup.$PROJECT.$modelalias.tgz";

#-------------------------------------------------------------------------------
# END settings
#-------------------------------------------------------------------------------
# Archive results
if (-e "$ResultsModelFinalDir/../$Archive") {
  $cmd = "rm -f $ResultsModelFinalDir/../$Archive";
  print "$cmd\n";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
}
$cmd = "cd $ResultsModelFinalDir/..; tar -cvzf $Archive asc; cd -";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";

# Copy to depot
$cmd = "cp $ResultsModelFinalDir/../$Archive $DepotDir/";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
