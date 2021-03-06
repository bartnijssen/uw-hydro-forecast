#!<SYSTEM_PERL_EXE> -w

=pod

=head1 NAME

plot_qnts.pl

=head1 SYNOPSIS

plot_qnts.pl
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

Script to plot model results

=cut

#-------------------------------------------------------------------------------
use lib qw(<SYSTEM_INSTALLDIR>/lib <SYSTEM_PERL_LIBS>);
use Log::Log4perl qw(:easy);
use Pod::Usage;
use Getopt::Long;

#-------------------------------------------------------------------------------
# Determine tools, config, and common directories
#-------------------------------------------------------------------------------
$TOOLS_DIR  = "<SYSTEM_INSTALLDIR>/bin";
$CONFIG_DIR = "<SYSTEM_INSTALLDIR>/config";
$COMMON_DIR = "<SYSTEM_COMMONDIR>";

#-------------------------------------------------------------------------------
# Include external modules
#-------------------------------------------------------------------------------
# Subroutine for reading config files
use simma_util;

# Date arithmetic
use Date::Calc qw(Add_Delta_Days);

# Other
use LWP::Simple;

#-------------------------------------------------------------------------------
# Parse the command line
#-------------------------------------------------------------------------------
Log::Log4perl->init('<SYSTEM_LOG_CONFIG>');
my $result = GetOptions("help|h|?" => \$help,
                        "man|info" => \$man);
pod2usage(-verbose => 2, -exitstatus => 0) if $man;
pod2usage(-verbose => 2, -exitstatus => 0) if $help;
$PROJECT = shift;  # project name, e.g. conus mexico
$MODEL   = shift;  # model name, e.g. vic noah sac clm multimodel
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
$PROJECT_UC = $PROJECT;
$PROJECT    =~ tr/A-Z/a-z/;
$PROJECT_UC =~ tr/a-z/A-Z/;
$datenow = sprintf("%04d%02d%02d", $yr, $mon, $day);

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
$modelalias         = $var_info_model_ref{MODEL_ALIAS};
$MODEL_UC           = $modelalias;
$MODEL_UC =~ tr/a-z/A-Z/;

# Substitute model-specific information into project variables
foreach $key_proj (keys(%var_info_project)) {
  foreach $key_model (keys(%var_info_model)) {
    $var_info_project{$key_proj} =~
      s/<$key_model>/$var_info_model{$key_model}/g;
  }
}

# Save relevant project info in variables
$XYZZ_DIR      = $var_info_project{"XYZZ_DIR"};
$PLOT_DIR      = $var_info_project{"PLOT_DIR"};
$CLIM_START_YR = $var_info_project{"CLIM_START_YR"};  # Climatology start year
$CLIM_END_YR   = $var_info_project{"CLIM_END_YR"};    # Climatology end year
$swe_thresh    = $var_info_project{"SWE_THRESH"};
$PROJ          = $var_info_project{"MAP_PROJ"};
$COORD         = $var_info_project{"MAP_COORD"};
$ANNOT         = $var_info_project{"MAP_ANNOT"};
$XX            = $var_info_project{"MAP_XX"};
$YY            = $var_info_project{"MAP_YY"};
$SCALE_X       = $var_info_project{"MAP_SCALE_X"};

# Save relevant model info in variables
$PlotVarList = $var_info_model{"PLOT_VARS"};
@varnames = split /,/, $PlotVarList;

#----------------------------------------------------------------------------------------------
# END settings
#----------------------------------------------------------------------------------------------
# Check for directories; create if necessary & possible
foreach $dir ("$XYZZ_DIR/$datenow") {
  if (!-d $dir) {
    die "$0: ERROR: directory $dir not found\n";
  }
}
foreach $dir ("$PLOT_DIR/$datenow") {
  &make_dir($dir) or LOGDIE("Cannot create path $dir: $!");
}
if ($modelalias =~ /vic/i && $PROJECT =~ /conus/i) {
  push @varnames, ("smDM", "smw", "smc", "sme");
}

# Loop over variables
foreach $varname (@varnames) {

  # Set up map parameters
  if ($varname eq "smw") {
    $current_PROJ    = "-JM6.5";
    $current_COORD   = "-126/-100/28/50";
    $current_ANNOT   = "-B4/4:.:WEsN";
    $current_XX      = 0;
    $current_YY      = 1;
    $current_SCALE_X = 3.25;
  } elsif ($varname eq "smc") {
    $current_PROJ    = "-JM6";
    $current_COORD   = "-110/-86/24/50";
    $current_ANNOT   = "-B4/4:.:WEsN";
    $current_XX      = 0;
    $current_YY      = 0.25;
    $current_SCALE_X = 3.00;
  } elsif ($varname eq "sme") {
    $current_PROJ    = "-JM7";
    $current_COORD   = "-94/-66/24/50";
    $current_ANNOT   = "-B4/4:.:WEsN";
    $current_XX      = -0.25;
    $current_YY      = 0.25;
    $current_SCALE_X = 3.5;
  } else {
    $current_PROJ    = $PROJ;
    $current_COORD   = $COORD;
    $current_ANNOT   = $ANNOT;
    $current_XX      = $XX;
    $current_YY      = $YY;
    $current_SCALE_X = $SCALE_X;
  }

  # Set up periods to loop over
  if ($varname eq "sm" || $varname eq "swe") {
    @periods = ("", "1day", "1wk", "2wk", "1mo");
  } elsif ($varname eq "ro") {
    @periods = (
                "1mo",  "2mo",  "3mo",  "6mo",  "9mo",  "12mo",
                "18mo", "24mo", "36mo", "48mo", "60mo", "WY"
               );
    @periodlbls = (
                   "1-Month", "2-Month", "3-Month",  "6-Month",
                   "9-Month", "1-Year",  "18-Month", "2-Year",
                   "3-Year",  "4-Year",  "5-Year",   "Water Year"
                  );
  } else {
    @periods = ("");
  }

  # Loop over periods
  for ($pidx = 0 ; $pidx < @periods ; $pidx++) {

    # First (and/or only) data file
    if ($varname eq "ro") {
      $srcfile1 =
        "$XYZZ_DIR/$datenow/$varname.$PROJECT_UC.$modelalias.qnt.xyzz";
    } elsif ($varname =~ /^sm(DM|w|c|e)$/) {
      $srcfile1 =
        "$XYZZ_DIR/$datenow/sm.$PROJECT_UC.$modelalias.f-c_mean.a-m_anom.qnt.xyzz";
    } else {
      $srcfile1 =
        "$XYZZ_DIR/$datenow/$varname.$PROJECT_UC.$modelalias.f-c_mean.a-m_anom.qnt.xyzz";
    }

    # (optional) second data file
    $srcfile2 = "NODATA";
    if (($varname eq "sm" || $varname eq "swe") & $periods[$pidx] ne "") {
      if ($periods[$pidx] eq "1day") {
        ($yr2, $mon2, $day2) = Add_Delta_Days($yr, $mon, $day, -1);
        $otherdate = sprintf("%04d%02d%02d", $yr2, $mon2, $day2);
      } elsif ($periods[$pidx] eq "1wk") {
        ($yr2, $mon2, $day2) = Add_Delta_Days($yr, $mon, $day, -7);
        $otherdate = sprintf("%04d%02d%02d", $yr2, $mon2, $day2);
      } elsif ($periods[$pidx] eq "2wk") {
        ($yr2, $mon2, $day2) = Add_Delta_Days($yr, $mon, $day, -14);
        $otherdate = sprintf("%04d%02d%02d", $yr2, $mon2, $day2);
      } elsif ($periods[$pidx] eq "1mo") {
        $day2 = $day;
        $mon2 = $mon - 1;
        $yr2  = $yr;
        if ($mon2 < 1) {
          $mon2 = 12;
          $yr2--;
        }
        $days_in_month = $month_days[$mon2 - 1];
        if (($yr2 % 4) == 0 && $mon2 == 2) {
          $days_in_month++;
        }
        if ($day2 > $days_in_month) {
          $day2 = $days_in_month;
        }
        $otherdate = sprintf("%04d%02d%02d", $yr2, $mon2, $day2);
      } else {
        LOGDIE("unsupported period: $periods[$pidx]");
      }
      if (-e "$XYZZ_DIR/$otherdate") {
        $srcfile2 =
          "$XYZZ_DIR/$otherdate/$varname.$PROJECT_UC.$modelalias.f-c_mean.a-m_anom.qnt.xyzz";
        if (!-e $srcfile2) {
          LOGWARN("$srcfile2 not found");
          next;
        }
      } else {
        LOGWARN("$XYZZ_DIR/$otherdate not found");
        next;
      }
    }

    #  Output filename
    if ($periods[$pidx] eq "") {
      $periodstr = "";
    } else {
      $periodstr = "." . $periods[$pidx];
    }
    $outfile =
      "$PLOT_DIR/$datenow/$PROJECT_UC.$modelalias." . $varname . "_qnt" .
      $periodstr . ".ps";
    if ($varname eq "smw") {
      $outfile = "$PLOT_DIR/$datenow/west.$modelalias.sm_qnt.ps";
    } elsif ($varname eq "smc") {
      $outfile = "$PLOT_DIR/$datenow/cent.$modelalias.sm_qnt.ps";
    } elsif ($varname eq "sme") {
      $outfile = "$PLOT_DIR/$datenow/east.$modelalias.sm_qnt.ps";
    } elsif ($varname eq "smDM") {
      $outfile = "$PLOT_DIR/$datenow/$PROJECT_UC.$modelalias.sm_qnt.DM.ps";
    }

    # First title line
    if ($varname =~ /^sm(DM|w|c|e)?$/) {
      $longname = "Soil Moisture";
    } elsif ($varname eq "swe") {
      $longname = "Snow Water Equivalent";
    } elsif ($varname eq "stot") {
      $longname = "Total Moisture Storage";
    } elsif ($varname eq "ro") {
      $longname = "Cumulative $periodlbls[$pidx] Runoff";
    }
    $title1 =
      "$MODEL_UC $longname Percentiles (wrt/ $CLIM_START_YR-$CLIM_END_YR)";

    # Second title line
    if ($varname =~ /^(sm|swe|stot)$/ && $periods[$pidx] ne "") {
      $title2 = "for the period:   $otherdate  to  $datenow";
    } elsif ($varname eq "smw") {
      $title2 = "Western United States - $datenow";
    } elsif ($varname eq "smc") {
      $title2 = "Central United States - $datenow";
    } elsif ($varname eq "sme") {
      $title2 = "Eastern United States - $datenow";
    } else {
      $title2 = $datenow;
      if ($varname eq "swe") {
        $title2 = "$title2   threshold = $swe_thresh mm";
      }
    }

    # Color scale
    if ($varname =~ /^(sm|swe|stot)$/ && $periods[$pidx] ne "") {
      $cptlabel1 = "change in percentile";
      $cptlabel2 = "NODATA";
      $cptfile   = "$COMMON_DIR/cpt/BR_YWG_BL.mod.cpt";
    } else {
      $cptlabel1 = "percentile";
      if ($varname eq "swe") {
        $cptfile   = "$COMMON_DIR/cpt/sw_mon.SWE.cpt";
        $cptlabel2 = "NODATA";
      } elsif ($varname eq "smDM") {
        $cptfile = "$COMMON_DIR/cpt/DM_sm_scale.cpt";
        $cptlabel2 =
          "0.4 -0.022 12 0 5 6 \\t           D4               D3               D2               D1               D0";
      } else {
        $cptfile   = "$COMMON_DIR/cpt/CPC_smplot.cpt";
        $cptlabel2 = "NODATA";
      }
    }

    # Temporary data file for plotting purposes
    $datafile = "$XYZZ_DIR/$datenow/$varname.$PROJECT_UC.$MODEL.tmp.xyzz";
    if ($varname =~ /^sm(DM|w|c|e)?$/ || $varname =~ /^stot$/) {
      if ($periods[$pidx] eq "") {
        $cmd = "awk \'{print \$1,\$2,\$7*100}\' $srcfile1 > $datafile";
        (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
      } else {
        $cmd = "paste $srcfile1 $srcfile2 > $datafile.tmp";
        (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
        $cmd =
          "awk \'{print \$1,\$2,(\$7-\$14)*100}\' $datafile.tmp > $datafile";
        (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
      }
    } elsif ($varname eq "swe") {
      if ($modelalias =~ /multimodel/i) {
        $swe_thresh = 0;
      }
      if ($periods[$pidx] eq "") {
        $cmd =
          "awk \'{if (\$3 > $swe_thresh || \$4 > $swe_thresh) print \$1,\$2,\$7*100}\' $srcfile1 > $datafile";
        (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
      } else {
        $cmd = "paste $srcfile1 $srcfile2 > $datafile.tmp";
        (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
        $cmd =
          "awk \'{if (\$3 > $swe_thresh || \$4 > $swe_thresh) print \$1,\$2,(\$7-\$14)*100}\' $datafile.tmp > $datafile";
        (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
      }
    } else {
      $col = $pidx + 1;
      $cmd = "awk \'{print \$1,\$2,\$(\'$col\'+2)*100}\' $srcfile1 > $datafile";
      (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
    }

    # Plot-specific layers
    if ($varname =~ /^sm(w|c|e)$/) {
      $polyfile1 = "$COMMON_DIR/basdln/us_county.poly";
      $polyfile2 = "$COMMON_DIR/basdln/lower48.poly";
    } else {
      $polyfile1 = "NODATA";
      $polyfile2 = "NODATA";
    }

    # Call the generic plotting script
    $plot_scr = "$TOOLS_DIR/plot.var_qnt.scr";
    $cmd =
      "$plot_scr $datafile $outfile $current_COORD $current_PROJ $current_ANNOT $current_XX $current_YY $current_SCALE_X \"$title1\" \"$title2\" $cptfile \"$cptlabel1\" \"$cptlabel2\" $polyfile1 $polyfile2 $PROJECT $modelalias";
    DEBUG($cmd);
    (system($cmd) == 0) or LOGDIE("$cmd failed: $?");

    # Clean up temp data file
    $cmd = "rm -f $datafile $datafile.tmp";
    (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
  }
}
INFO("Done with all plots!");
