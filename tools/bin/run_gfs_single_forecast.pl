#!<SYSTEM_PERL_EXE> -w

=pod

=head1 NAME

run_gfs_single_forecast.pl

=head1 SYNOPSIS

run_gfs_single_forecast.pl
  [options] --model=model --project=project --start=startdate 
            --ensemble_member=id --state_subdir=subdir --spinup_subdir=subdir

 Options:
    --help|h|?                  brief help message
    --man|info                  full documentation
    --verbose|v                 increase verbosity

 Required:
    --model|m=model             model to run
                                Requires a config.model.<model> file in the
                                config directory
    --project|p=project         project to run
                                Requires a config.project.<project> file in the
                                config directory
    --start|s=YYYY-MM-DD        start date for forecast run
    --ensemble_member|em=em     Number of the ensemble member to process
    --state_subdir|st=retro|spinup|curr subdir for the state
    --spinup_subdir|sp=retro_spinup|curr subdir for routing spinup

=head1 DESCRIPTION

Create a forecast run for a single member in a gfs ensemble. Note that all the
other parameters are read from the config.project.<project> file.

=head1 PREREQUISITES

=head2 Software

This script is part of the UW Hydro Forecast system. It relies on other scripts
and libraries in that same system to run. This means that the script does
necessarily work as a standalone program.

=cut

no warnings qw(once);
use lib qw(<SYSTEM_INSTALLDIR>/lib <SYSTEM_PERL_LIBS>);
use Log::Log4perl qw(:easy);
use Getopt::Long;
use Pod::Usage;
use Date::Calc qw(Add_Delta_Days Delta_Days Add_Delta_YMD Add_Delta_YM);
use File::Temp qw(tempfile tempdir);
use File::Copy qw(move);
use File::Path qw(remove_tree);

#use strict;  # sanity!! -- unfortunately doesn't work well with
              # model_specific.pl
my $cleanup = 0;

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
require "$TOOLS_DIR/model_specific.pl";
require "$TOOLS_DIR/rout_specific.pl";

#-------------------------------------------------------------------------------
# Parse the command-line arguments
#-------------------------------------------------------------------------------
# Get the Project name and Current date from nowcast_model.pl
my $help;
my $ensemble_member;
my $man;
my $model;
my $project;
my $start_date;
my $state_subdir;
my $verbose = 0;
Log::Log4perl->init('<SYSTEM_LOG_CONFIG>');
INFO("Running: $0 @ARGV");

# Hash used in GetOptions function
my $status = GetOptions(
                        "help|h|?"    => \$help,
                        "man|info"    => \$man,
                        "verbose|v"   => \$verbose,
                        "model|m=s"   => \$model,
                        "project|p=s" => \$project,
                        "start|s=s"   => \$start_date,
                        "ensemble_member|em=s" => \$ensemble_member,
                        "state_subdir|st=s" => \$state_subdir,
                        "spinup_sub|sp=s" => \$spinup_subdir
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
    not defined $ensemble_member or
    not defined $state_subdir or
    not defined $spinup_subdir;

# Parse & validate start/end dates
my @startdate = parse_yyyymmdd($start_date, "-");
@startdate == 3 or LOGDIE("Start date must have format YYYY-MM-DD");
isdate(@startdate) or LOGDIE("Not a valid start date: $start_date");
$state_subdir =~ m/retro/ or 
  $state_subdir =~ m/spinup/ or 
  $state_subdir =~ m/curr/ or 
  LOGDIE("state_subdir must be one of retro, spinup or curr");
$spinup_subdir =~ m/retro/ or 
  $spinup_subdir =~ m/spinup/ or 
  $spinup_subdir =~ m/curr/ or 
  LOGDIE("spinup_subdir must be one of retro, spinup or curr");

#-------------------------------------------------------------------------------
# Read config info
#-------------------------------------------------------------------------------
# Read project configuration info
my $ConfigProject        = "$CONFIG_DIR/config.project.$project";
my $var_info_project_ref = &read_config($ConfigProject);
%var_info_project     = %{$var_info_project_ref};

# Read model configuration info
my $ConfigModel        = "$CONFIG_DIR/config.model.$model";
my $var_info_model_ref = &read_config($ConfigModel);
my %var_info_model     = %{$var_info_model_ref};

# Read routing model info
$ConfigRoute        = "$CONFIG_DIR/config.model.$var_info_project{ROUT_MODEL}";
$var_info_route_ref = &read_config($ConfigRoute);
%var_info_route     = %{$var_info_route_ref};

# Substitute model-specific information into project variables
foreach my $key_proj (keys(%var_info_project)) {
  foreach my $key_model (keys(%var_info_model)) {
    $var_info_project{$key_proj} =~
      s/<$key_model>/$var_info_model{$key_model}/g;
  }
}

#-------------------------------------------------------------------------------
# Set up and test paths, etc for the hydro model
#-------------------------------------------------------------------------------

# hash in which the keys correspond to entries in the VIC control file
my %hydrocontrol;             

my $init_state_dir;
if ($state_subdir =~ m/retro/) {
  $init_state_dir = $var_info_project{STATE_RETRO_DIR}
} elsif ($state_subdir =~ m/spinup/) {
  $init_state_dir = $var_info_project{STATE_NEAR_RT_DIR}
} elsif ($state_subdir =~ m/curr/) {
  $init_state_dir = $var_info_project{STATE_CURRSPIN_DIR}
}
$init_state_dir .=  '/' . $var_info_model{MODEL_ALIAS};
my @statedate = Add_Delta_Days(@startdate, 0);

my @enddate = Add_Delta_Days(@startdate, $var_info_project{GFS_FCST_HORIZON});
my $end_date = sprintf("%04d-%02d-%02d", @enddate);

my $model_exe = join('/', $var_info_model{MODEL_EXE_DIR}, 
                     $var_info_model{MODEL_EXE_NAME});                     
($hydrocontrol{START_YEAR}, $hydrocontrol{START_MONTH}, $hydrocontrol{START_DAY}) = 
  @startdate;
($hydrocontrol{END_YEAR}, $hydrocontrol{END_MONTH}, $hydrocontrol{END_DAY}) 
  = @enddate;
$hydrocontrol{INITIAL} = $init_state_dir . '/' . 'state_' . 
  sprintf("%04d%02d%02d", @statedate);
$hydrocontrol{FORCING_DIR} = join('/', $var_info_project{FORCING_FCST_DIR}, 
                          $var_info_project{GFS_SUBDIR},
                          sprintf("%04d%02d%02d", @startdate), 
                          "tmpdir_data_$ensemble_member");
($hydrocontrol{FORCE_START_YEAR}, $hydrocontrol{FORCE_START_MONTH}, 
 $hydrocontrol{FORCE_START_DAY}) = @startdate;

($hydrocontrol{PARAMS_DIR} = $var_info_project{PARAMS_MODEL_DIR}) =~
  s/<MODEL_SUBDIR>/$var_info_model{MODEL_ALIAS}/;

$hydrocontrol{STATEYEAR} = 'none';
$hydrocontrol{STATEMONTH} = 'none';
$hydrocontrol{STATEDAY} = 'none';

my $tmprootdir = '<SYSTEM_TMP>';
$tmprootdir = '<SYSTEM_LOCAL_TMP>' if '<SYSTEM_LOCAL_STORAGE>' =~ /true/i;
if (not -e $tmprootdir) {
  (&make_dir($tmprootdir) == 0) or 
    LOGDIE("Cannot create path $tmprootdir: $!");
}
my $tmpdir = tempdir("tmp_gfs_run_${ensemble_member}_XXXXXX",
                     DIR => $tmprootdir, 
                     CLEANUP => $cleanup) or 
  LOGDIE("Cannot create tmpdir in $tmprootdir");

# May need to have a case for local storage or not
$hydrocontrol{RESULTS_DIR} = tempdir('tmp_hydrooutput_XXXXXX',
                                     DIR => $tmpdir, 
                                     CLEANUP => $cleanup) or 
  LOGDIE("Cannot create results_dir in tmpdir");

($fh1, $controlfile) = tempfile('tmp_hydrocontrol_XXXXXX', 
                                DIR => $tmpdir, 
                                CLEANUP => $cleanup) or
  LOGDIE("Cannot create temporary hydrocontrol file");
($fh2, $LOGFILE) = tempfile('tmp_hydrolog_XXXXXX', 
                            DIR => $tmpdir, 
                            CLEANUP => $cleanup) or 
  LOGDIE("Cannot create temporary log file");

my $paramstemplate = join('/', $hydrocontrol{PARAMS_DIR},
                          $var_info_project{GFS_PARAMS_TEMPLATE});
open(PARAMS_TEMPLATE, $paramstemplate) or
  LOGDIE("Cannot open parameter template file $paramstemplate");
@ParamsInfo = <PARAMS_TEMPLATE>;
close(PARAMS_TEMPLATE);

#-------------------------------------------------------------------------------
# Copy the variables to the ones needed by model_specific.pl
# This is a bit convoluted right now, but the way I want to change it is by 
# passing the %hydrocontrol hash and the parameter template, rather than using 
# global parameters. So the above is just prep for that transition
#-------------------------------------------------------------------------------

if ($spinup_subdir =~ m/retro/) {
  $spinup_subdir = $var_info_project{RETRO_SUBDIR}
} elsif ($spinup_subdir =~ m/spinup/) {
  $spinup_subdir = $var_info_project{NEAR_RT_SUBDIR}
} elsif ($spinup_subdir =~ m/curr/) {
  $spinup_subdir = $var_info_project{CURR_SUBDIR}
}
   
($start_year, $start_month, $start_day) = 
  ($hydrocontrol{START_YEAR}, $hydrocontrol{START_MONTH}, $hydrocontrol{START_DAY});
($end_year, $end_month, $end_day) = 
  ($hydrocontrol{END_YEAR}, $hydrocontrol{END_MONTH}, $hydrocontrol{END_DAY});
$ParamsModelDir = $hydrocontrol{PARAMS_DIR};
$init_file = $hydrocontrol{INITIAL};
$ForcingModelDir = $hydrocontrol{FORCING_DIR};
$prefix = $hydrocontrol{FORC_PREFIX};
$Forc_Syr = $hydrocontrol{FORCE_START_YEAR};
$Forc_Smon = $hydrocontrol{FORCE_START_MONTH};
$Forc_Sday = $hydrocontrol{FORCE_START_DAY};
$state_dir = $hydrocontrol{STATE_DIR};
$state_year = $hydrocontrol{STATEYEAR};
$state_month = $hydrocontrol{STATEMONTH};
$state_day = $hydrocontrol{STATEDAY};
$MODEL_EXE_DIR = $var_info_model{MODEL_EXE_DIR};
$MODEL_EXE_NAME = $var_info_model{MODEL_EXE_NAME};
$results_dir_asc = $hydrocontrol{RESULTS_DIR};

#-------------------------------------------------------------------------------
# Run hydro forecast
#-------------------------------------------------------------------------------

$func_name = "wrap_run_" . $var_info_model{MODEL_ALIAS};
&{$func_name}($model_specific);

#-------------------------------------------------------------------------------
# Set up and test paths, etc for the routing model
#-------------------------------------------------------------------------------

# hash in which the keys correspond to entries in the routing control file
my %routecontrol;             

$routecontrol{PARAMS_ROUT_DIR} = $var_info_project{PARAMS_ROUT_DIR};
($routecontrol{SPINUP_DIR} = $var_info_project{SPINUP_MODEL_ASC_DIR}) =~  
  s/<FORCING_SUBDIR>/$spinup_subdir/g;

($routecontrol{SPINUP_END_YEAR}, $routecontrol{SPINUP_END_MON}, 
 $routecontrol{SPINUP_END_DAY}) = Add_Delta_Days(@statedate, -1);

($routecontrol{SPINUP_START_YEAR}, $routecontrol{SPINUP_START_MON}) =
  Add_Delta_YM($routecontrol{SPINUP_END_YEAR}, $routecontrol{SPINUP_END_MON}, 
               $routecontrol{SPINUP_END_DAY}, 0, -2);
$routecontrol{SPINUP_START_DAY} = "01";

# Only if forcing_subdir is curr_spinup
if ($spinup_subdir =~ /curr/) {
  # Date of Spinup Start and END
  open(FILE,  $var_info_project{FORCING_CURRSPIN_START_DATE_FILE}) or
    LOGDIE("Cannot open file ".
           $var_info_project{FORCING_CURRSPIN_START_DATE_FILE});
  foreach (<FILE>) {
    if (/^(\d+)\s+(\d+)\s+(\d+)\s+/) {
      ($routecontrol{SPINUP_START_YEAR}, $routecontrol{SPINUP_START_MON},
       $routecontrol{SPINUP_START_DAY}) = ($1, $2, $3);
    }
  }
  close(FILE);
}

$routecontrol{FLUX_OUTPUT} = $hydrocontrol{RESULTS_DIR};
($routecontrol{FLUX_START_YEAR}, $routecontrol{FLUX_START_MON}, 
 $routecontrol{FLUX_START_DAY}) = @startdate;
($routecontrol{FLUX_END_YEAR}, $routecontrol{FLUX_END_MON},
 $routecontrol{FLUX_END_DAY}) = @enddate;
$routecontrol{ROUT_OUTPUT} = tempdir('tmp_routoutput_XXXXXX',
                                     DIR => $tmpdir, 
                                     CLEANUP => $cleanup) or
  LOGDIE("Cannot create ROUT_OUTPUT in tmpdir");
$routecontrol{ROUT_OUTPUT} .= '/';
($routecontrol{ROUT_START_YEAR}, $routecontrol{ROUT_START_MON}, 
 $routecontrol{ROUT_START_DAY}) = @startdate;
($routecontrol{ROUT_END_YEAR}, $routecontrol{ROUT_END_MON}, 
 $routecontrol{ROUT_END_DAY}) = @enddate;

$routecontrol{ROUTE_EXE_DIR} = $var_info_route{MODEL_EXE_DIR};
$routecontrol{ROUTE_EXE_NAME} = $var_info_route{MODEL_EXE_NAME};

$paramstemplate = join('/', $var_info_project{PARAMS_ROUT_DIR},
                       $var_info_project{PARAMS_ROUT_TEMPLATE});
open(PARAMS_TEMPLATE, $paramstemplate) or
  LOGDIE("Cannot open parameter template file $paramstemplate");
@ParamsInfo = <PARAMS_TEMPLATE>;
close(PARAMS_TEMPLATE);
 
($fh3, $controlfile) = tempfile('tmp_routecontrol_XXXXXX', 
                                DIR => $tmpdir, 
                                CLEANUP => $cleanup) or
  LOGDIE("Cannot create temporary routecontrol file");
($fh4, $LOGFILE) = tempfile('tmp_routelog_XXXXXX', 
                            DIR => $tmpdir, 
                            CLEANUP => $cleanup) or 
  LOGDIE("Cannot create temporary log file");

#-------------------------------------------------------------------------------
# Copy the variables to the ones needed by rout_specific.pl
# This is a bit convoluted right now, but the way I want to change it is by 
# passing the %routecontrol hash and the parameter template, rather than using 
# global parameters. So the above is just prep for that transition
#-------------------------------------------------------------------------------

$ParamsModelDir = $routecontrol{PARAMS_ROUT_DIR};
$SpinupModelAscDir = $routecontrol{SPINUP_DIR};
$Spinup_Syr = $routecontrol{SPINUP_START_YEAR};
$Spinup_Smon = $routecontrol{SPINUP_START_MON};
$Spinup_Sday = $routecontrol{SPINUP_START_DAY};
$Spinup_Eyr = $routecontrol{SPINUP_END_YEAR};
$Spinup_Emon = $routecontrol{SPINUP_END_MON};
$Spinup_Eday = $routecontrol{SPINUP_END_DAY};
$results_dir_asc = $routecontrol{FLUX_OUTPUT};
$start_year = $routecontrol{FLUX_START_YEAR};
$start_month = $routecontrol{FLUX_START_MON};
$start_day = $routecontrol{FLUX_START_DAY};
$end_year = $routecontrol{FLUX_END_YEAR};
$end_month = $routecontrol{FLUX_END_MON};
$end_day = $routecontrol{FLUX_END_DAY};
$Routdir = $routecontrol{ROUT_OUTPUT};
$start_year = $routecontrol{ROUT_START_YEAR};
$start_month = $routecontrol{ROUT_START_MON};
$start_day = $routecontrol{ROUT_START_DAY};
$end_year = $routecontrol{ROUT_END_YEAR};
$end_month = $routecontrol{ROUT_END_MON};
$end_day = $routecontrol{ROUT_END_DAY};
$ROUTE_EXE_DIR = $routecontrol{ROUTE_EXE_DIR};
$ROUTE_EXE_NAME = $routecontrol{ROUTE_EXE_NAME};

#-------------------------------------------------------------------------------
# Route flows
#-------------------------------------------------------------------------------

$func_name = "wrap_run_" . "rout";
&{$func_name}($model_specific);

#-------------------------------------------------------------------------------
# Copy temporary files to final locations
#-------------------------------------------------------------------------------

my $fcstdate = sprintf("%04d%02d%02d", @startdate);

my $destdir = join('/', $var_info_project{FCST_DIR}, 
                   $var_info_project{GFS_SUBDIR},
                   $var_info_model{MODEL_SUBDIR},
                   $fcstdate, 'em' . $ensemble_member);
my $fluxdir = join('/', $destdir, 'flux');
my $flowdir = join('/', $destdir, 'flow');


for my $dir ($destdir, $flowdir, $fluxdir) {
  if (not -e $dir) {
    (&make_dir($dir) == 0) or 
      LOGDIE("Cannot create path $dir: $!");
  }
}

copydir($hydrocontrol{RESULTS_DIR}, $fluxdir) or 
  LOGDIE("Failed to move $hydrocontrol{RESULTS_DIR} to $fluxdir: $!");

copydir($routecontrol{ROUT_OUTPUT}, $flowdir) or 
  LOGDIE("Failed to move $routecontrol{ROUT_OUTPUT} to $flowdir: $!");

#-------------------------------------------------------------------------------
# Cleanup
#-------------------------------------------------------------------------------

# Manual cleanup
if ($cleanup) {
  remove_tree($tmpdir, {error => \my $err}); 
  LOGWARN("Could not remove $tmpdir") if (@$err);
}

INFO("Completed: $0 @ARGV");
