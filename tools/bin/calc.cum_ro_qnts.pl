#!<SYSTEM_PERL_EXE> -w

=pod

=head1 NAME

calc.cum_ro_qnts.pl

=head1 SYNOPSIS

calc.cum_ro_qnts.pl [options] model project year month day [directory]

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

calculate cumulative variable percentile for a variety of cumulation periods
taken prior to the current (latest) day, for all cells in a basin

output format:  one row per cell
  lon lat [percentile for various accumulations
  use avg runoff during the period
  if 1, the period is combined

NOTE:  supply climatology period for calculating percentiles.
Set start of climatology period so that accumulation periods do not
precede start of data.

=head2 AUTHORS

 A. Wood Aug 2007
 Ted Bohn Sep 2008 
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
$CONFIG_DIR = "<SYSTEM_INSTALLDIR>/config";

#-------------------------------------------------------------------------------
# Include external modules
#-------------------------------------------------------------------------------
# Subroutine for reading config files
use simma_util;

# Date arithmetic
use Date::Calc qw(Delta_Days Add_Delta_Days Add_Delta_YM);

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
$Cyr                     = shift;
$Cmon                    = shift;
$Cday                    = shift;
$results_subdir_override = shift; # By default, results are taken from
                                  # curr_spinup, but this can be overridden here
pod2usage(-verbose => 1, -exitstatus => 1)
  if not defined($MODEL) or
    not defined($PROJECT) or
    not defined($Cyr)     or
    not defined($Cmon)    or
    not defined
    ($Cday);

#-------------------------------------------------------------------------------
# Set up constants
#-------------------------------------------------------------------------------
# Derived variables
$PROJECT_UC = $PROJECT;
$PROJECT    =~ tr/A-Z/a-z/;
$PROJECT_UC =~ tr/a-z/A-Z/;
$DATE = sprintf "%04d%02d%02d", $Cyr, $Cmon, $Cday;

# Miscellaneous
@PER = (1, 2, 3, 6, 9, 12, 18, 24, 36, 48, 60);  # in months

# also reserve one final slot for time since beginning of WY
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

# Save relevant project info in variables
$ResultsModelAscDir = $var_info_project{"RESULTS_MODEL_ASC_DIR"};
$XYZZDir            = $var_info_project{"XYZZ_DIR"};
$Flist              = $var_info_project{"FLUX_FLIST"};
$Clim_Syr = $var_info_project{"RO_CLIM_START_YR"};  # Climatology start year
$Clim_Eyr = $var_info_project{"RO_CLIM_END_YR"};    # Climatology end year

# The final processed model results will be stored in the ascii dir
$ResultsModelFinalDir = $ResultsModelAscDir;

# Save relevant model info in variables
$OutputPrefixList = $var_info_model{"OUTPUT_PREFIX"};
($OutputPrefix, $tmp) = split /,/, $OutputPrefixList;

# Directories and files
$RetroDir = $ResultsModelFinalDir;
$RetroDir =~ s/<RESULTS_SUBDIR>/retro/g;
$NearRTDir = $ResultsModelFinalDir;
$NearRTDir =~ s/<RESULTS_SUBDIR>/spinup_nearRT/g;
$RTDir = $ResultsModelFinalDir;
if ($results_subdir_override) {
  $RTDir =~ s/<RESULTS_SUBDIR>/$results_subdir_override/g;
} else {
  $RTDir =~ s/<RESULTS_SUBDIR>/curr_spinup/g;
}
$OUTD  = "$XYZZDir/$DATE";
$Outfl = "$OUTD/ro.$PROJECT_UC.$MODEL.qnt.xyzz";

#-------------------------------------------------------------------------------
# END settings
#-------------------------------------------------------------------------------
# Check for directories; create if necessary & possible
foreach $dir ($RTDir, $NearRTDir, $RetroDir) {
  if (!-d $dir) {
    LOGDIE("directory $dir not found");
  }
}
foreach $dir ($OUTD) {
  (&make_dir($dir) == 0) or LOGDIE("Cannot create path $dir: $!");
}

# read file/station list ----------------------
@cell = `cat $Flist`;
chomp(@cell);
foreach (@cell) {
  s/fluxes/$OutputPrefix/;
}

# check adequacy of data records ---------------
open(FL, "<$RetroDir/$cell[0]") or LOGDIE("can't open $RetroDir/$cell[0]: $!");
$r = 0;
while (<FL>) {
  ($yr[$r], $mo[$r], $dy[$r], @tmp) = split;
  $r++;
}
close(FL);
open(FL, "<$NearRTDir/$cell[0]") or
  LOGDIE("can't open $NearRTDir/$cell[0]: $!");
while (<FL>) {
  ($yr[$r], $mo[$r], $dy[$r], @tmp) = split;
  $r++;
}
close(FL);
$rt_skip = 0; # counter to see if it's necesary to skip days from overlapping rt
              # archive
open(FL, "<$RTDir/$cell[0]") or
  LOGDIE("can't open $RTDir/$cell[0]: $!");
while (<FL>) {
  ($yy, $mm, $dd, @tmp) = split;
  if (Delta_Days($yr[$r - 1], $mo[$r - 1], $dy[$r - 1], $yy, $mm, $dd) < 1) {
    $rt_skip++;  # read an overlapping day
  } else {
    ($yr[$r], $mo[$r], $dy[$r]) = ($yy, $mm, $dd);
    $r++;
  }
}
close(FL);
$datarecs = @yr;

# assign data start & end dates, and target date for percentile calculation
($yr0, $mon0, $day0) = ($yr[0], $mo[0], $dy[0]);  # data start date
$days_needed = Delta_Days($yr[0], $mo[0], $dy[0],
                          $yr[$datarecs - 1],
                          $mo[$datarecs - 1],
                          $dy[$datarecs - 1]) + 1;
if ($datarecs != $days_needed) {
  LOGDIE("read $datarecs days but period from $yr[0]$mo[0]$dy[0] to " .
         "$yr[$datarecs-1]$mo[$datarecs-1]$dy[$datarecs-1] should have " .
         "$days_needed days");
} else {
  DEBUG("read $datarecs days for period from $yr[0]$mo[0]$dy[0] to " .
        "$yr[$datarecs-1]$mo[$datarecs-1]$dy[$datarecs-1]");
}

# == first make matrix of start & end dates for all periods desired
DEBUG("making matrix of start & end records for accumulations periods");

# calculate records bounding CLIM period accumulations ------------- use zero
# element of @recbnd for end record of period; save last element for WY
$ny = 0;  # counter for years, working forward
for ($y = $Clim_Syr ; $y <= $Clim_Eyr ; $y++) {

  # one per year
  $recbnd[$ny][0] = Delta_Days($yr0, $mon0, $day0, $y, $Cmon, $Cday);
  for ($p = 1 ; $p <= @PER ; $p++) {
    ($ty, $tm, $td) = Add_Delta_YM($y, $Cmon, $Cday, 0, -$PER[$p - 1]);
    ($tyr, $tmo, $tdy) = Add_Delta_Days($ty, $tm, $td, 1);
    $recbnd[$ny][$p] = Delta_Days($yr0, $mon0, $day0, $tyr, $tmo, $tdy);
    if ($recbnd[$ny][$p] < 0) {
      LOGDIE("accum. period starts before data -- " .
             "make climatology period later");
    }
  }

  # set start date for WY-to-current-day accumulation period
  if ($Cmon < 10) {
    $recbnd[$ny][$p] = Delta_Days($yr0, $mon0, $day0, $y - 1, 10, 1);
    if ($recbnd[$ny][$p] < 0) {
      LOGDIE("accum. period starts before data -- " .
             "make climatology period later");
    }
  } else {
    $recbnd[$ny][$p] = Delta_Days($yr0, $mon0, $day0, $y, 10, 1);
    if ($recbnd[$ny][$p] < 0) {
      LOGDIE("accum. period starts before data -- " .
             "make climatology period later");
    }
  }
  $ny++;
}

# start & end records for CURRENT period accumulations -------------
#one per year
$recbnd[$ny][0] = Delta_Days($yr0, $mon0, $day0, $Cyr, $Cmon, $Cday);
for ($p = 1 ; $p <= @PER ; $p++) {
  ($ty, $tm, $td) = Add_Delta_YM($Cyr, $Cmon, $Cday, 0, -$PER[$p - 1]);
  ($tyr, $tmo, $tdy) = Add_Delta_Days($ty, $tm, $td, 1);
  $recbnd[$ny][$p] = Delta_Days($yr0, $mon0, $day0, $tyr, $tmo, $tdy);
  if ($recbnd[$ny][$p] < 0) {
    LOGDIE(
      "accum. period starts before data -- " . "make climatology period later");
  }
}

# set start date for WY-to-current-day accumulation period
if ($Cmon < 10) {
  $recbnd[$ny][$p] = Delta_Days($yr0, $mon0, $day0, $Cyr - 1, 10, 1);
  if ($recbnd[$ny][$p] < 0) {
    LOGDIE(
      "accum. period starts before data -- " . "make climatology period later");
  }
} else {
  $recbnd[$ny][$p] = Delta_Days($yr0, $mon0, $day0, $Cyr, 10, 1);
  if ($recbnd[$ny][$p] < 0) {
    LOGDIE(
      "accum. period starts before data -- " . "make climatology period later");
  }
}
$curr_ndx = $ny;  # array index of current record boundaries for periods

# %%%%%%%%%%%%%% loop through cells/stations %%%%%%%%%%%%%%%%%%%%%%%%
@qnt       = ();  # initialize array to store data for a write at one time
@min_count = ();
@max_count = ();
for ($c = 0 ; $c < @cell ; $c++) {
  DEBUG("$c $cell[$c]");
  @data = @accum = ();
  Read_Runoff_One_Cell($cell[$c], $rt_skip, \@data);  # call subr. for getting
                                                      # data only

  # loop through data and get accumulations, including current
  # NOTE:  no checks for whether
  for ($y = 0 ; $y <= $curr_ndx ; $y++) {
    $accum[$y][0] = 0;
    $p = 0;  # do first period separately to include final day in accum.
    for ($r = $recbnd[$y][$p + 1] ; $r <= $recbnd[$y][$p] ; $r++) {
      $accum[$y][$p] += $data[$r];
    }
    for ($p = 1 ; $p < @PER ; $p++) {  # work backward, adding rest of periods
      $accum[$y][$p] = $accum[$y][$p - 1];
      for ($r = $recbnd[$y][$p + 1] ; $r < $recbnd[$y][$p] ; $r++) {
        $accum[$y][$p] += $data[$r];
      }
    }

    # now do WY part separately (note $p has incremented)
    $accum[$y][$p] = 0;
    for ($r = $recbnd[$y][$p + 1] ; $r <= $recbnd[$y][0] ; $r++) {
      $accum[$y][$p] += $data[$r];
    }
  }  # note @accum contains elements 0 to @PER

  # ------------- calc percentile ----------------------
  for ($p = 0 ; $p <= @PER ; $p++) {  # loop through accum periods
    @tmp = ();
    for ($y = 0 ; $y < $curr_ndx ; $y++) {
      $tmp[$y] = $accum[$y][$p];
    }
    ($qnt[$c][$p], $min_p, $max_p) = F_given_val($accum[$curr_ndx][$p], \@tmp);
    if ($qnt[$c][$p] == $min_p) {
      $min_count[$p]++;
    }
    if ($qnt[$c][$p] == $max_p) {
      $max_count[$p]++;
    }
    TRACE("cell $c period $p qnt $qnt[$c][$p]");
  }  # end percentile period loop
}  # end looping through stations %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Quick check on data quality
for ($p = 0 ; $p <= @PER ; $p++) {  # loop through accum periods
  if ($min_count[$p] + $max_count[$p] == @cell) {
    LOGDIE("for period $p, data consist only of extreme values");
  }
}

# ---- now write out format file --------------------------
open(OUT, ">$Outfl") or LOGDIE("can't open $Outfl: $!");
DEBUG("writing...");
for ($c = 0 ; $c < @cell ; $c++) {
  @tmp = split("_", $cell[$c]);
  printf OUT "%.4f %.4f   ", $tmp[2], $tmp[1];
  for ($p = 0 ; $p <= @PER ; $p++) {  # loop through accum periods
    printf OUT "%6.3f ", $qnt[$c][$p];
  }
  printf OUT "\n";
}
close(OUT);

# %%%%%%%%%%%%%%%%%%%% SUBROUTINES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# subroutine to read runoff from one cell
#   uses global variables for directory names
sub Read_Runoff_One_Cell {
  ($cname, $skip_rec, $data_ref) = @_;
  open(FL, "<$RetroDir/$cname") or
    LOGDIE("can't open $RetroDir/$cname: $!");
  $r = 0;
  while (<FL>) {
    @tmp = split;
    $data_ref->[$r] =
      $tmp[5] + $tmp[6];  # reference this way to pass back values
    $r++;
  }
  close(FL);
  open(FL, "<$NearRTDir/$cname") or
    LOGDIE("can't open $NearRTDir/$cname: $!");
  while (<FL>) {
    @tmp = split;
    $data_ref->[$r] = $tmp[5] + $tmp[6];
    $r++;
  }
  close(FL);
  open(FL, "<$RTDir/$cname") or
    LOGDIE("can't open $RTDir/$cname: $!");
  $cnt = 0;
  while (<FL>) {
    if ($cnt >= $skip_rec) {
      @tmp = split;
      $data_ref->[$r] = $tmp[5] + $tmp[6];
      $r++;
    } else {
      $cnt++;
    }
  }
  close(FL);
}

# set sort logic
sub numer {$a <=> $b;}

# given an unsorted array and value, return the associated non-exceed. %-ile.
# not much checking in here
sub F_given_val {

  # allows crude percentile extrapolation; returns void for zero distrib.
  my ($val, $array_ref) = @_;
  @array = @$array_ref;
  $LEN   = @array;                      # dimension of array
  $min_p = 1 / ($LEN + 1) * 0.5;        # def. p-val for targ below dist
  $max_p = $LEN / ($LEN + 1) + $min_p;  # ditto for above dist

  # sort array (using logic set in other subroutine)
  @srt_arr = sort numer @array;
  $i       = 0;
  while ($i < $LEN) {
    if ($srt_arr[$i] >= $val && $i == 0) {

      # handles zero precip case, but gives lowest percentile (!!)
      $qnt = $min_p;
      last;
    } elsif ($srt_arr[$i] < $val && $i == $LEN - 1) {
      $qnt = $max_p;
      last;
    } elsif ($srt_arr[$i] >= $val) {

      # note, i as counter in qnt eq. must start at 1 not 0
      # whereas in arrays, starts at 0
      $qnt =
        ($val - $srt_arr[$i - 1]) /
        ($srt_arr[$i] - $srt_arr[$i - 1]) *
        (($i + 1) / ($LEN + 1) - $i / ($LEN + 1)) + $i /
        ($LEN + 1);
      last;
    }
    $i++;
  }  # done calc'ing percentiles
  return ($qnt, $min_p, $max_p);
}
