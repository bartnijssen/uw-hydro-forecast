#!<SYSTEM_PERL_EXE> -w

=pod

=head1 NAME

get_stats.pl

=head1 SYNOPSIS

get_stats.pl [options] model project year month day [directory]

 Options:
    --help|h|?                  brief help message
    --man|info                  full documentation

 Required (in order):
    model                model (must have config.model.<model> file)
    project              project (must have config.project.<project> file)
    year                 year
    month                month
    day                  day

 Optional (last one):
    directory            by default, results are taken from curr_spinup, but
                         this can be overridden here

=head1 DESCRIPTION

Script to convert model results into percentiles of model climatology

=head2 AUTHORS

 Ted Bohn 
 and others since then

=cut

#-------------------------------------------------------------------------------
use lib qw(<SYSTEM_INSTALLDIR>/lib <SYSTEM_PERL_LIBS>);
use Log::Log4perl qw(:easy);
use Pod::Usage;
use Getopt::Long;

#-------------------------------------------------------------------------------
# Determine tools and config directories
#-------------------------------------------------------------------------------
$TOOLS_DIR  = "<SYSTEM_INSTALLDIR>/bin";
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
$MODEL                   = shift;
$PROJECT                 = shift;
$fyear                   = shift;
$fmonth                  = shift;
$fday                    = shift;
$results_subdir_override = shift; # By default, results are taken from
                                  # curr_spinup, but this can be overridden here
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
$DATE = sprintf "%04d%02d%02d", $fyear, $fmonth, $fday;

# Miscellaneous
@month_days = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);

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
$ResultsModelAscDir = $var_info_project{"RESULTS_MODEL_ASC_DIR"};
$XYZZDir            = $var_info_project{"XYZZ_DIR"};
$LONLAT             = $var_info_project{"LONLAT_LIST"};
$FLIST              = $var_info_project{"FLUX_FLIST"};
$SYR   = $var_info_project{"CLIM_START_YR"};  # Climatology start year
$EYR   = $var_info_project{"CLIM_END_YR"};    # Climatology end year
$width = $var_info_project{ "WINDOW_WIDTH"
  };  # width of window (days) about forecast day for grand distribution

# The final processed model results will be stored in the ascii dir
$ResultsModelFinalDir = $ResultsModelAscDir;

# Save relevant model info in variables
$OutputPrefixList = $var_info_model{"OUTPUT_PREFIX"};
($OutputPrefix) = split /,/, $OutputPrefixList;
if ($var_info_model{"ENS_MODEL_LIST"}) {
  $ENS_MODEL_LIST = $var_info_model{"ENS_MODEL_LIST"};
  @ENS_MODELS     = split /,/, $ENS_MODEL_LIST;
  $nModels        = @ENS_MODELS;
}
$SMCOL_LIST = $var_info_model{"SMCOL"};
@SMCols     = split /,/, $SMCOL_LIST;
$SWECol     = $var_info_model{"SWECOL"};
$STOTCol    = $var_info_model{"STOTCOL"};

# Directories and files
$CURRPATH = $ResultsModelFinalDir;
if ($results_subdir_override) {
  $CURRPATH =~ s/<RESULTS_SUBDIR>/$results_subdir_override/g;
} else {
  $CURRPATH =~ s/<RESULTS_SUBDIR>/curr_spinup/g;
}
$HISTPATH = $ResultsModelFinalDir;
$HISTPATH =~ s/<RESULTS_SUBDIR>/retro/g;
$OUTD = "$XYZZDir/$DATE";
if ($modelalias =~ /multimodel/i) {
  $CURRPATH = $OUTD;
}
$SMFILE   = "$OUTD/$PROJECT_UC.$modelalias.sm.curr-srt_hist";
$SWEFILE  = "$OUTD/$PROJECT_UC.$modelalias.swe.curr-srt_hist";
$STOTFILE = "$OUTD/$PROJECT_UC.$modelalias.stot.curr-srt_hist";
if ($modelalias =~ /vic/i) {
  $SM1FILE = "$OUTD/$PROJECT_UC.$modelalias.sm1.curr-srt_hist";
  $SM2FILE = "$OUTD/$PROJECT_UC.$modelalias.sm2.curr-srt_hist";
  $SM3FILE = "$OUTD/$PROJECT_UC.$modelalias.sm3.curr-srt_hist";
}

#-------------------------------------------------------------------------------
# END settings
#-------------------------------------------------------------------------------
# Check for directories; create if necessary & possible
foreach $dir ($CURRPATH, $HISTPATH) {
  if (!-d $dir) {
    LOGDIE("directory $dir not found");
  }
}
foreach $dir ($OUTD) {
  (&make_dir($dir) == 0) or LOGDIE("Cannot create path $dir: $!");
}

# Remove old files
if (-e $SMFILE) {
  $cmd = "rm -f $SMFILE";
  (system($cmd) == 0) or LOGDIE("Cannot remove file $SMFILE");
}
if (-e $SWEFILE) {
  $cmd = "rm -f $SWEFILE";
  (system($cmd) == 0) or LOGDIE("Cannot remove file $SWEFILE");
}
if ($modelalias =~ /vic/i) {
  if (-e $SM1FILE) {
    $cmd = "rm -f $SM1FILE";
    (system($cmd) == 0) or LOGDIE("Cannot remove file $SM1FILE");
  }
  if (-e $SM2FILE) {
    $cmd = "rm -f $SM2FILE";
    (system($cmd) == 0) or LOGDIE("Cannot remove file $SM2FILE");
  }
  if (-e $SM3FILE) {
    $cmd = "rm -f $SM3FILE";
    (system($cmd) == 0) or LOGDIE("Cannot remove file $SM3FILE");
  }
}

# Compute current day of year
# Indexing starts at 1
$julian_day = $fday * 1;
for ($mon = 1 ; $mon < $fmonth ; $mon++) {
  $days_in_month = $month_days[$mon - 1];
  if ($fyear % 4 == 0 && $fmonth == 2) {
    $days_in_month++;
  }
  $julian_day += $days_in_month;
}
if ($julian_day == 366) {
  $julian_day--;
}

# Figure out which days of the year are in the window
@days_to_get = ();
for ($i = -int($width / 2) ; $i < int($width / 2) + 1 ; $i++) {
  $day = $julian_day + $i;
  if ($day < 1) {
    $day += 365;
  } elsif ($day >= 365) {
    $day -= 365;
  }
  push @days_to_get, $day;
}

# Open output files
open(SMFILE, ">$SMFILE") or
  LOGDIE("Cannot open file $SMFILE for writing");
open(SWEFILE, ">$SWEFILE") or
  LOGDIE("Cannot open file $SWEFILE for writing");
open(STOTFILE, ">$STOTFILE") or
  LOGDIE("Cannot open file $STOTFILE for writing");
if ($modelalias =~ /vic/i) {
  open(SM1FILE, ">$SM1FILE") or
    LOGDIE("Cannot open file $SM1FILE for writing");
  open(SM2FILE, ">$SM2FILE") or
    LOGDIE("Cannot open file $SM2FILE for writing");
  open(SM3FILE, ">$SM3FILE") or
    LOGDIE("Cannot open file $SM3FILE for writing");
}

#-------------------------------------------------------------------------------
# Get current & historic distribution for sm & snow for specified date, sorted
#-------------------------------------------------------------------------------
# For multimodel, current values are average of other models' pctls;
# Pctls have different format than model results
if ($modelalias =~ /multimodel/i) {
  $first = 1;
  foreach $ens_model (@ENS_MODELS) {
    $PCTL_FILE = "$OUTD/sm.$PROJECT_UC.$ens_model.f-c_mean.a-m_anom.qnt.xyzz";
    open(PCTL_FILE, $PCTL_FILE) or
      LOGDIE("Cannot open file $PCTL_FILE for reading");
    $cell_idx = 0;
    foreach (<PCTL_FILE>) {
      chomp;
      @fields = split /\s+/;
      if ($first) {
        $MMSoilMoist[$cell_idx] = $fields[6];
      } else {
        $MMSoilMoist[$cell_idx] += $fields[6];
      }
      $cell_idx++;
    }
    close(PCTL_FILE);
    $nCells = $cell_idx;
    $first  = 0;
  }
  for ($cell_idx = 0 ; $cell_idx < $nCells ; $cell_idx++) {
    $MMSoilMoist[$cell_idx] /= $nModels;
  }
  $first = 1;
  foreach $ens_model (@ENS_MODELS) {
    $PCTL_FILE = "$OUTD/swe.$PROJECT_UC.$ens_model.f-c_mean.a-m_anom.qnt.xyzz";
    open(PCTL_FILE, $PCTL_FILE) or
      LOGDIE("Cannot open file $PCTL_FILE for reading");
    $cell_idx = 0;
    foreach (<PCTL_FILE>) {
      chomp;
      @fields = split /\s+/;
      if ($first) {
        $count[$cell_idx] = 0;
      }
      if ($fields[6] > 0) {
        if ($count[$cell_idx] == 0) {
          $MMSWE[$cell_idx] = $fields[6];
        } else {
          $MMSWE[$cell_idx] += $fields[6];
        }
        $count[$cell_idx]++;
      }
      $cell_idx++;
    }
    close(PCTL_FILE);
    $nCells = $cell_idx;
    $first  = 0;
  }
  for ($cell_idx = 0 ; $cell_idx < $nCells ; $cell_idx++) {
    if ($count[$cell_idx] > 0) {
      $MMSWE[$cell_idx] /= $count[$cell_idx];
    } else {
      $MMSWE[$cell_idx] = -9999;
    }
  }
  $first = 1;
  foreach $ens_model (@ENS_MODELS) {
    $PCTL_FILE = "$OUTD/stot.$PROJECT_UC.$ens_model.f-c_mean.a-m_anom.qnt.xyzz";
    open(PCTL_FILE, $PCTL_FILE) or
      LOGDIE("Cannot open file $PCTL_FILE for reading");
    $cell_idx = 0;
    foreach (<PCTL_FILE>) {
      chomp;
      @fields = split /\s+/;
      if ($first) {
        $MMSTOT[$cell_idx] = $fields[6];
      } else {
        $MMSTOT[$cell_idx] += $fields[6];
      }
      $cell_idx++;
    }
    close(PCTL_FILE);
    $nCells = $cell_idx;
    $first  = 0;
  }
  for ($cell_idx = 0 ; $cell_idx < $nCells ; $cell_idx++) {
    $MMSTOT[$cell_idx] /= $nModels;
  }
}

# Loop over grid cells
open(FLIST, $FLIST) or LOGDIE("Cannot open file $FLIST for reading");
$cell_idx = 0;
foreach $F (<FLIST>) {
  chomp $F;
  $F =~ s/fluxes/$OutputPrefix/g;
  $HFILE = "$HISTPATH/$F";
  $CFILE = "$CURRPATH/$F";

  # Current day's values
  # For individual models, read ascii model results
  if ($modelalias !~ /multimodel/i) {
    $CurrSoilMoist  = -1;
    $CurrSoilMoist1 = -1;
    $CurrSoilMoist2 = -1;
    $CurrSoilMoist3 = -1;
    $CurrSWE        = -1;
    $CurrSTOT       = -1;
    open(CFILEH, $CFILE) or
      LOGDIE("Cannot open file $CFILE for reading");
    foreach (<CFILEH>) {
      chomp;
      @fields = split /\s+/;
      if ($fields[0] * 1 == $fyear * 1 &&
          $fields[1] * 1 == $fmonth * 1 &&
          $fields[2] * 1 == $fday * 1) {
        $CurrSoilMoist = 0;
        foreach $col (@SMCols) {
          $CurrSoilMoist += $fields[$col];
        }
        if ($modelalias =~ /vic/i) {
          $CurrSoilMoist1 = $fields[8];
          $CurrSoilMoist2 = $fields[9];
          $CurrSoilMoist3 = $fields[10];
        }
        $CurrSWE = $fields[$SWECol];
        if ($CurrSoilMoist >= 0 && $CurrSWE >= 0) {
          $CurrSTOT = $CurrSoilMoist + $CurrSWE;
        }
      }
    }
    close(CFILEH);
    if ($CurrSoilMoist == -1 || $CurrSWE == -1) {
      LOGDIE("No info for $fyear-$fmonth-$fday found in file $CFILE");
    }
  }

  # For multimodel, use values computed before this loop over grid cells
  else {
    $CurrSoilMoist = $MMSoilMoist[$cell_idx];
    $CurrSWE       = $MMSWE[$cell_idx];
    $CurrSTOT      = $MMSTOT[$cell_idx];
  }
  $cell_idx++;

  # climatological distributions
  # Grand distribution of all values in the $width-day window centered on the
  # current day.
  @HistSoilMoist  = ();
  @HistSoilMoist1 = ();
  @HistSoilMoist2 = ();
  @HistSoilMoist3 = ();
  @HistSWE        = ();
  @HistSTOT       = ();
  @year           = ();
  @month          = ();
  @day            = ();
  $i              = 0;
  open(HFILEH, $HFILE) or
    LOGDIE("Cannot open file $HFILE for reading");

  foreach (<HFILEH>) {
    chomp;
    @fields = split /\s+/;
    ($year, $month, $day) = @fields[0 .. 2];

    # Compute current day of year
    $julian_day = $day;
    for ($mon = 1 ; $mon < $month ; $mon++) {
      $days_in_month = $month_days[$mon - 1];
      if ($year % 4 == 0 && $month == 2) {
        $days_in_month++;
      }
      $julian_day += $days_in_month;
    }

    # Check: is this record's day in the grand distribution?
    $found = 0;
    foreach $day_to_get (@days_to_get) {
      if ($day_to_get == $julian_day) {
        $found = 1;
      }
    }
    if ($year >= $SYR && $year <= $EYR && $found) {
      $HistSoilMoist[$i] = 0;
      foreach $col (@SMCols) {
        $HistSoilMoist[$i] += $fields[$col];
      }
      if ($modelalias =~ /vic/i) {
        $HistSoilMoist1[$i] = $fields[8];
        $HistSoilMoist2[$i] = $fields[9];
        $HistSoilMoist3[$i] = $fields[10];
      }
      $HistSWE[$i] = $fields[$SWECol];
      if ($modelalias !~ /multimodel/i) {
        $HistSTOT[$i] = $HistSoilMoist[$i] + $HistSWE[$i];
      } else {
        $HistSTOT[$i] = $fields[$STOTCol];
      }
      $i++;
    }
  }
  close(HFILEH);

  # Sort the distributions
  @HistSoilMoistSorted = sort {$a <=> $b;} @HistSoilMoist;
  if ($modelalias =~ /vic/i) {
    @HistSoilMoist1Sorted = sort {$a <=> $b;} @HistSoilMoist1;
    @HistSoilMoist2Sorted = sort {$a <=> $b;} @HistSoilMoist2;
    @HistSoilMoist3Sorted = sort {$a <=> $b;} @HistSoilMoist3;
  }
  @HistSWESorted  = sort {$a <=> $b;} @HistSWE;
  @HistSTOTSorted = sort {$a <=> $b;} @HistSTOT;

  # Record the values
  # SoilMoist
  print SMFILE "$CurrSoilMoist";
  foreach (@HistSoilMoistSorted) {
    print SMFILE " $_";
  }
  print SMFILE "\n";

  # SWE
  print SWEFILE "$CurrSWE";
  foreach (@HistSWESorted) {
    print SWEFILE " $_";
  }
  print SWEFILE "\n";

  # STOT
  print STOTFILE "$CurrSTOT";
  foreach (@HistSTOTSorted) {
    print STOTFILE " $_";
  }
  print STOTFILE "\n";

  # Layer-specific SoilMoist
  if ($modelalias =~ /vic/i) {
    print SM1FILE "$CurrSoilMoist1";
    foreach (@HistSoilMoist1Sorted) {
      print SM1FILE " $_";
    }
    print SM1FILE "\n";
    print SM2FILE "$CurrSoilMoist2";
    foreach (@HistSoilMoist2Sorted) {
      print SM2FILE " $_";
    }
    print SM2FILE "\n";
    print SM3FILE "$CurrSoilMoist3";
    foreach (@HistSoilMoist3Sorted) {
      print SM3FILE " $_";
    }
    print SM3FILE "\n";
  }
}
close(FLIST);
close(SMFILE);
close(SWEFILE);
close(STOTFILE);
if ($modelalias =~ /vic/i) {
  close(SM1FILE);
  close(SM2FILE);
  close(SM3FILE);
}

# Find percentiles, anomalies
# SM
$cmd =
  "$TOOLS_DIR/fcst_stats.pl $SMFILE $OUTD/sm.$PROJECT_UC.$modelalias.stats";
DEBUG($cmd);
(system($cmd) == 0) or LOGDIE("$cmd failed: $?");
$cmd =
  "/usr/bin/paste $LONLAT $OUTD/sm.$PROJECT_UC.$modelalias.stats > " .
  "$OUTD/sm.$PROJECT_UC.$modelalias.f-c_mean.a-m_anom.qnt.xyzz";
DEBUG($cmd);
(system($cmd) == 0) or LOGDIE("$cmd failed: $?");

# SWE
$cmd =
  "$TOOLS_DIR/fcst_stats.pl $SWEFILE $OUTD/swe.$PROJECT_UC.$modelalias.stats";
DEBUG($cmd);
(system($cmd) == 0) or LOGDIE("$cmd failed: $?");
$cmd =
  "/usr/bin/paste $LONLAT $OUTD/swe.$PROJECT_UC.$modelalias.stats > " .
  "$OUTD/swe.$PROJECT_UC.$modelalias.f-c_mean.a-m_anom.qnt.xyzz";
DEBUG($cmd);
(system($cmd) == 0) or LOGDIE("$cmd failed: $?");

# STOT
$cmd =
  "$TOOLS_DIR/fcst_stats.pl $STOTFILE $OUTD/stot.$PROJECT_UC.$modelalias.stats";
DEBUG($cmd);
(system($cmd) == 0) or LOGDIE("$cmd failed: $?");
$cmd =
  "/usr/bin/paste $LONLAT $OUTD/stot.$PROJECT_UC.$modelalias.stats > " .
  "$OUTD/stot.$PROJECT_UC.$modelalias.f-c_mean.a-m_anom.qnt.xyzz";
DEBUG($cmd);
(system($cmd) == 0) or LOGDIE("$cmd failed: $?");

# Layer-specific SoilMoist
if ($modelalias =~ /vic/i) {
  $cmd =
    "$TOOLS_DIR/fcst_stats.pl $SM1FILE $OUTD/sm1.$PROJECT_UC.$modelalias.stats";
  DEBUG($cmd);
  (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
  $cmd =
    "/usr/bin/paste $LONLAT $OUTD/sm1.$PROJECT_UC.$modelalias.stats > " .
    "$OUTD/sm1.$PROJECT_UC.$modelalias.f-c_mean.a-m_anom.qnt.xyzz";
  DEBUG($cmd);
  (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
  $cmd =
    "$TOOLS_DIR/fcst_stats.pl $SM2FILE $OUTD/sm2.$PROJECT_UC.$modelalias.stats";
  DEBUG($cmd);
  (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
  $cmd =
    "/usr/bin/paste $LONLAT $OUTD/sm2.$PROJECT_UC.$modelalias.stats > " .
    "$OUTD/sm2.$PROJECT_UC.$modelalias.f-c_mean.a-m_anom.qnt.xyzz";
  DEBUG($cmd);
  (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
  $cmd =
    "$TOOLS_DIR/fcst_stats.pl $SM3FILE $OUTD/sm3.$PROJECT_UC.$modelalias.stats";
  DEBUG($cmd);
  (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
  $cmd =
    "/usr/bin/paste $LONLAT $OUTD/sm3.$PROJECT_UC.$modelalias.stats > " .
    "$OUTD/sm3.$PROJECT_UC.$modelalias.f-c_mean.a-m_anom.qnt.xyzz";
  DEBUG($cmd);
  (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
}

# Clean up
$cmd = "\\rm -f $OUTD/*.stats";
(system($cmd) == 0) or LOGDIE("$cmd failed: $?");

# SM
$cmd = "\\rm -f $SMFILE.gz";
(system($cmd) == 0) or LOGDIE("$cmd failed: $?");
$cmd = "gzip $SMFILE";
(system($cmd) == 0) or LOGDIE("$cmd failed: $?");

# SWE
$cmd = "\\rm -f $SWEFILE.gz";
(system($cmd) == 0) or LOGDIE("$cmd failed: $?");
$cmd = "gzip $SWEFILE";
(system($cmd) == 0) or LOGDIE("$cmd failed: $?");

# STOT
$cmd = "\\rm -f $STOTFILE.gz";
(system($cmd) == 0) or LOGDIE("$cmd failed: $?");
$cmd = "gzip $STOTFILE";
(system($cmd) == 0) or LOGDIE("$cmd failed: $?");

# Layer-specific SoilMoist
if ($modelalias =~ /vic/i) {
  $cmd = "\\rm -f $SM1FILE.gz";
  (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
  $cmd = "gzip $SM1FILE";
  (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
  $cmd = "\\rm -f $SM2FILE.gz";
  (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
  $cmd = "gzip $SM2FILE";
  (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
  $cmd = "\\rm -f $SM3FILE.gz";
  (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
  $cmd = "gzip $SM3FILE";
  (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
}
