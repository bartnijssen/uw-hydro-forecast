#!<SYSTEM_PERL_EXE> -w
#
# update_fmt.pl: Script that examines current station observations, computes
# number of usable days of data, and creates "fmt" file for input to gridding
# process.
#
# Author: Ted Bohn
# $Id: $
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# Determine tools and config directories
#-------------------------------------------------------------------------------
$TOOLS_DIR  = "<SYSTEM_INSTALLDIR>/bin";
$CONFIG_DIR = "<SYSTEM_INSTALLDIR>/config";

#-------------------------------------------------------------------------------
# Include external modules
#-------------------------------------------------------------------------------
# Get some modules to help compute dates
use Date::Calc qw(Add_Delta_YM Add_Delta_Days Days_in_Month Delta_Days);

#-------------------------------------------------------------------------------
# Get command-line arguments
#-------------------------------------------------------------------------------
$StnDir          = shift;
$p_ndx_fmt_file  = shift;
$tx_ndx_fmt_file = shift;
$tn_ndx_fmt_file = shift;
$Cyr             = shift;
$Cmon            = shift;
$Cday            = shift;
$Syr             = shift;
$Smon            = shift;
$Sday            = shift;
$Forc_Eyr        = shift;
$Forc_Emon       = shift;
$Forc_Eday       = shift;
$StnList         = shift;
$StnReq          = shift;
$Void            = shift;

#-------------------------------------------------------------------------------
# Create fmt files from raw ACIS data
#-------------------------------------------------------------------------------
$start_date = sprintf "%04d-%02d-%02d", $Syr, $Smon, $Sday;
$end_date   = sprintf "%04d-%02d-%02d", $Cyr, $Cmon, $Cday;

#$cmd = "$TOOLS_DIR/write_fmt_file_from_raw_acis.pl " .
#  "$StnDir/../stn_info/rawdata $StnList $start_date $end_date $Void " .
#  "$p_ndx_fmt_file $tx_ndx_fmt_file $tn_ndx_fmt_file";
$cmd =
  "$TOOLS_DIR/write_fmt_file_from_stn_ts.pl $StnDir $StnList " .
  "$start_date $end_date $p_ndx_fmt_file $tx_ndx_fmt_file $tn_ndx_fmt_file";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $! \n";

# Compute number of usable days
open(PFMT, $p_ndx_fmt_file) or
  die "$0: ERROR: cannot open p fmt file $p_ndx_fmt_file\n";
$UsableDays = 0;
foreach (<PFMT>) {
  chomp;
  @fields = split /\s+/;
  $good   = 0;
  for ($i = 0 ; $i < @fields ; $i++) {

    #    if ($fields[$i] != $Void) {
    if ($fields[$i] ne "") {
      $good++;
    }
  }
  if ($good >= $StnReq) {
    $UsableDays++;
  } else {
    last;
  }
}
close(PFMT);
print "Number of usable days: $UsableDays\n";

# Truncate fmt files back to last usable day
foreach $file ($p_ndx_fmt_file, $tx_ndx_fmt_file, $tn_ndx_fmt_file) {
  $cmd = "head -$UsableDays $file > $file.tmp";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $! \n";
  $cmd = "mv $file.tmp $file";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $! \n";
}

# Set actual forecast date to be used (depending on station coverage)
($Fyr, $Fmon, $Fday) = Add_Delta_Days($Syr, $Smon, $Sday, $UsableDays - 1);
print "Usable data in update period is from $Syr $Smon $Sday to " .
  "$Fyr $Fmon $Fday\n";

# Check to see whether usable day is after existing last forcing day
$Update_Days =
  Delta_Days($Forc_Eyr, $Forc_Emon, $Forc_Eday, $Fyr, $Fmon, $Fday);
print "Number of update days since last update ($Forc_Eyr $Forc_Emon " .
  "$Forc_Eday) is $Update_Days\n";

# Quit if no usable new update days
if ($Update_Days <= 0) {
  if ($p_ndx_fmt_file =~ /^(.*)\/[^\/]+$/) {
    $FmtDir = $1;
  }
  print STDERR "No usable days since previous update on $Forc_Eyr " .
    "$Forc_Emon $Forc_Eday found\n:";
  print STDERR "Quitting.  Check recent station data *.fmt files in " .
    "$FmtDir for coverage\n";
  print STDERR " or lower STNS_REQ setting in the project config file\n";
  die;
}
