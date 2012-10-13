#!<SYSTEM_PERL_EXE> -w

=pod

=head1 NAME

copy_figs_depot.pl

=head1 SYNOPSIS

copy_figs_depot.pl
 [options] project model year month day

 Options:
    --help|h|?                  brief help message
    --man|info                  full documentation

 Required (in order):
    project              project (must have config.project.<project> file)
    model                model (must have config.model.<model> file)
    year                 year
    month                month
    day                  day

=head1 DESCRIPTION

Script to copy model results plots to web site

=cut
#-------------------------------------------------------------------------------
use lib qw(<SYSTEM_INSTALLDIR>/lib <SYSTEM_PERL_LIBS>);
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
my $result = GetOptions("help|h|?" => \$help,
                        "man|info" => \$man);
pod2usage(-verbose => 2, -exitstatus => 0) if $man;
pod2usage(-verbose => 2, -exitstatus => 0) if $help;
$PROJECT = shift;  # project name, e.g. conus mexico
$MODEL   = shift;  # model name, e.g. vic noah sac clm multimodel all
$yr      = shift;
$mon     = shift;
$day     = shift;
pod2usage(-verbose => 1, -exitstatus => 1)
  if not defined($MODEL) or
    not defined($PROJECT) or
    not defined($yr)      or
    not defined($mon)     or
    not defined
    ($day);

#-------------------------------------------------------------------------------
# Set up constants
#-------------------------------------------------------------------------------
# Derived variables
$PROJECT =~ tr/A-Z/a-z/;
$datenow = sprintf("%04d%02d%02d", $yr, $mon, $day);

# Read project configuration info
$ConfigProject        = "$CONFIG_DIR/config.project.$PROJECT";
$var_info_project_ref = &read_config($ConfigProject);
%var_info_project     = %{$var_info_project_ref};

# Read model configuration info
$ConfigModel        = "$CONFIG_DIR/config.model.$MODEL";
$var_info_model_ref = &read_config($ConfigModel);
%var_info_model     = %{$var_info_model_ref};
$modelalias         = $var_info_model{MODEL_ALIAS};

# Substitute model-specific information into project variables
foreach $key_proj (keys(%var_info_project)) {
  foreach $key_model (keys(%var_info_model)) {
    $var_info_project{$key_proj} =~
      s/<$key_model>/$var_info_model{$key_model}/g;
  }
}

# Save relevant project info in variables
$XYZZDir  = $var_info_project{"XYZZ_DIR"} . "/$datenow";
$PlotDir  = $var_info_project{"PLOT_DIR"} . "/$datenow";
$DepotDir = $var_info_project{"PLOT_DEPOT_DIR"};

#-------------------------------------------------------------------------------
# END settings
#-------------------------------------------------------------------------------
# Check for directories; create if necessary & possible
foreach $dir ($XYZZDir, $PlotDir, $DepotDir) {
  if (!-d $dir) {
    die "$0: ERROR: directory $dir not found\n";
  }
}
foreach $dir ($DepotDir) {
  &make_dir($dir) or die "$0: ERROR: Cannot create path $dir: $!\n";
}

# Copy stats
if ($modelalias eq "all") {
  $cmd = "cp $XYZZDir/* $DepotDir/";
} else {
  $cmd = "cp $XYZZDir/*${modelalias}* $DepotDir/";
}
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";

# Copy plots
if ($modelalias eq "all") {
  $cmd = "cp $PlotDir/* $DepotDir/";
} else {
  $cmd = "cp $PlotDir/*${modelalias}* $DepotDir/";
}
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
