#!<SYSTEM_PERL_EXE> -w

=pod

=head1 NAME

merge_project_stats.pl

=head1 SYNOPSIS

merge_project_stats.pl [options] model project year month day [directory]

 Options:
    --help|h|?                  brief help message
    --man|info                  full documentation

 Required (in order):
    model                model (must have config.model.<model> file)
    project              project (must have config.project.<project> file)
    year                 output forecast year
    month                output forecast month
    day                  output forecast day

 Optional (last one):
    sourceflag           0 (or omitted) = get sub-project forecasts from
                         "merge_depot"; 1 = get them from directories of the
                         exact same date as the output forecast date directory
                         by default, results are taken from curr_spinup, but
                         this can be overridden here

=head1 DESCRIPTION

Script for merging the model output statistics from a list of project domains
into one larger domain.

=cut

#-------------------------------------------------------------------------------
use lib qw(<SYSTEM_INSTALLDIR>/lib <SYSTEM_PERL_LIBS>);
use Log::Log4perl qw(:easy);
use Pod::Usage;
use Getopt::Long;

#-------------------------------------------------------------------------------
# Determine tools config directories
#-------------------------------------------------------------------------------
$CONFIG_DIR = "<SYSTEM_INSTALLDIR>/config";

#-------------------------------------------------------------------------------
# Include external modules
#-------------------------------------------------------------------------------
# Subroutine for reading config files
use simma_util;

#-------------------------------------------------------------------------------
# Command-line arguments
#-------------------------------------------------------------------------------
Log::Log4perl->init('<SYSTEM_LOG_CONFIG>');
my $result = GetOptions("help|h|?" => \$help,
                        "man|info" => \$man);
pod2usage(-verbose => 2, -exitstatus => 0) if $man;
pod2usage(-verbose => 2, -exitstatus => 0) if $help;
$PROJECT  = shift;
$MODEL    = shift;
$fyear    = shift;  # Output forecast date
$fmonth   = shift;  # Output forecast date
$fday     = shift;  # Output forecast date
$explicit = shift;  # 0 (or omitted) = get sub-project forecasts from
                    # "merge_depot"; 1 = get them from directories of the exact
                    # same date as the output forecast date
pod2usage(-verbose => 1, -exitstatus => 1)
  if not defined($MODEL) or
    not defined($PROJECT) or
    not defined($fyear)   or
    not defined($fmonth)  or
    not defined
    ($fday);

#-------------------------------------------------------------------------------
# Set up constants
#-------------------------------------------------------------------------------
# Derived variables
$PROJECT_UC = $PROJECT;
$PROJECT    =~ tr/A-Z/a-z/;
$PROJECT_UC =~ tr/a-z/A-Z/;
$DateOut = sprintf "%04d%02d%02d", $fyear, $fmonth, $fday;

# Read project configuration info
$ConfigProject        = "$CONFIG_DIR/config.project.$PROJECT";
$var_info_project_ref = &read_config($ConfigProject);
%var_info_project     = %{$var_info_project_ref};

# Read model configuration info
$ConfigModel        = "$CONFIG_DIR/config.model.$MODEL";
$var_info_model_ref = &read_config($ConfigModel);
%var_info_model     = %{$var_info_model_ref};

# Substitute model-specific information into project variables
foreach $key_proj (keys(%var_info_project)) {
  foreach $key_model (keys(%var_info_model)) {
    $var_info_project{$key_proj} =~
      s/<$key_model>/$var_info_model{$key_model}/g;
  }
}

# Save relevant info
$ProjectType = $var_info_project{"PROJECT_TYPE"};
if ($ProjectType =~ /merge/i) {
  $SubProjectList = $var_info_project{"PROJECT_MERGE_LIST"};
  @SubProjects = split /,/, $SubProjectList;
}
$XYZZDir = $var_info_project{"XYZZ_DIR"};

########### $LogDir = $var_info_project{"LOGS_MODEL_DIR"};
########### $LogDir =~ s/<LOGS_SUBDIR>/curr_spinup/;
$StatVarList  = $var_info_model{"STAT_VARS"};
$PlotVarList  = $var_info_model{"PLOT_VARS"};
@varnames     = split /,/, $StatVarList;
@varnames_tmp = split /,/, $PlotVarList;
foreach $varname_tmp (@varnames_tmp) {
  $found = 0;
INNER_LOOP: foreach $varname (@varnames) {
    if ($varname eq $varname_tmp) {
      $found = 1;
      last INNER_LOOP;
    }
  }
  if (!$found) {
    push @varnames, $varname_tmp;
  }
}

# Get info for each subproject in the list
for ($proj_idx = 0 ; $proj_idx < @SubProjects ; $proj_idx++) {

  # Read subproject config file
  $ConfigProject        = "$CONFIG_DIR/config.project.$SubProjects[$proj_idx]";
  $var_info_project_ref = &read_config($ConfigProject);
  %var_info_project     = %{$var_info_project_ref};

  # Substitute model-specific information into project variables
  foreach $key_proj (keys(%var_info_project)) {
    foreach $key_model (keys(%var_info_model)) {
      $var_info_project{$key_proj} =~
        s/<$key_model>/$var_info_model{$key_model}/g;
    }
  }

  # Save relevant info
  # $CurrspinEndDateFileSub[$proj_idx] =
  # $var_info_project{"FORCING_CURRSPIN_END_DATE_FILE"};
  $XYZZDirSub[$proj_idx]       = $var_info_project{"XYZZ_DIR"};
  $MergeDepotDirSub[$proj_idx] = $var_info_project{"MERGE_DEPOT_DIR"};
  $SubProjectUC[$proj_idx]     = $SubProjects[$proj_idx];
  $SubProjectUC[$proj_idx] =~ tr/a-z/A-Z/;
}

# Directories
for ($proj_idx = 0 ; $proj_idx < @SubProjects ; $proj_idx++) {
  if ($explicit) {
    $IND[$proj_idx] = "$XYZZDirSub[$proj_idx]/$DateOut";
  } else {
    $IND[$proj_idx] = "$MergeDepotDirSub[$proj_idx]";
  }
  if (!-e $IND[$proj_idx]) {
    LOGDIE("Input directory $IND[$proj_idx] not found");
  }
}
$OUTD = "$XYZZDir/$DateOut";
(&make_dir($OUTD) == 0) or LOGDIE("Cannot create path $OUTD: $!");

#-------------------------------------------------------------------------------
# END settings
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
# Loop over all stats variables for the given model, merging stats files from
# all projects
# ------------------------------------------------------------------------------
for ($var_idx = 0 ; $var_idx < @varnames ; $var_idx++) {
  if ($varnames[$var_idx] ne "ro") {
    $ext = "f-c_mean.a-m_anom.qnt.xyzz";
  } else {
    $ext = "qnt.xyzz";
  }
  $first = 1;
  for ($proj_idx = 0 ; $proj_idx < @SubProjects ; $proj_idx++) {
    if ($first) {
      $cmd =
        "cp $IND[$proj_idx]/$varnames[$var_idx]." .
        "$SubProjectUC[$proj_idx].$MODEL.$ext " .
        "$OUTD/$varnames[$var_idx].$PROJECT_UC.$MODEL.$ext";
      $first = 0;
    } else {
      $cmd =
        "cat $IND[$proj_idx]/$varnames[$var_idx]." .
        "$SubProjectUC[$proj_idx].$MODEL.$ext >> " .
        "$OUTD/$varnames[$var_idx].$PROJECT_UC.$MODEL.$ext";
    }
    DEBUG($cmd);
    (system($cmd) == 0) or LOGDIE("$cmd failed");
  }
}
