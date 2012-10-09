#!/usr/bin/env perl
use warnings;

# Wrapper script that calls programs to update real-time ascii forcings
#
# Definitions
#
# MinDays - min num. of days in curr month for which to calc. a unique
#           percentile if $Fday>$MinDays, split update period in 2, else lump
#           together
#
# StnsReq - num of stns that must report for update (50%+ out of total number of
#           stations)
#
# FractReq - fraction of a percentile period that must be present for a
#            given station; otherwise assign void
#
# Void - value to indicate missing data when writing output (raw data voids may
# differ)
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# Determine tools and config directories
#-------------------------------------------------------------------------------
$TOOLS_DIR  = "<SYSTEM_INSTALLDIR>/bin";
$CONFIG_DIR = "<SYSTEM_INSTALLDIR>/config";

#-------------------------------------------------------------------------------
# Include external modules
#-------------------------------------------------------------------------------
use lib "<SYSTEM_SITEPERL_LIB>";
# Subroutine for reading config files
use simma_util;

# Date computation
use Date::Calc qw(Days_in_Month Delta_Days Add_Delta_Days);
use POSIX qw(strftime);

#-------------------------------------------------------------------------------
# Command-line arguments
#-------------------------------------------------------------------------------
$PROJECT = shift;

# These next arguments are optional - can be omitted
$currspin_start_date_override = shift;
$currspin_end_date_override   = shift;
$forcing_upd_date_override    = shift;

#-------------------------------------------------------------------------------
# Set up constants
#-------------------------------------------------------------------------------
# Unique identifier for this job
$JOB_ID = strftime "%y%m%d-%H%M%S", localtime;

# Configuration files
$ConfigProject = "$CONFIG_DIR/config.project.$PROJECT";
$ConfigRegrid  = "$CONFIG_DIR/config.model.regrid";

# Project configuration info
$var_info_project_ref = &read_config($ConfigProject);
%var_info_project     = %{$var_info_project_ref};
$ProjectType          = $var_info_project{"PROJECT_TYPE"};

# This script should only run on "real" projects
if ($ProjectType !~ /real/i) {
  exit(0);
}
$StnRawDir     = $var_info_project{"FORCING_ACIS_RAW_DIR"};
$StnTSDir      = $var_info_project{"FORCING_ACIS_RT_TS_DIR"};
$StnRetroTSDir = $var_info_project{"FORCING_ACIS_LT_TS_DIR"};
$FmtDir        = $var_info_project{"FORCING_GRID_TMP_DIR"};

# HACK -- not sure why these hardwired paths are here - Bart
# Should be moved to config Tue Sep 25 2012
$RetroForcDir       = $var_info_project{"FORCING_RETRO_DIR"} . "/asc_vicinp";
$CurrForcDir        = $var_info_project{"FORCING_CURRSPIN_DIR"} . "/asc_vicinp";
$ParamsDirRegrid    = $var_info_project{"PARAMS_DIR"} . "/regrid";
$StnList            = $var_info_project{"STN_LIST"};
$MetMeansStn        = $var_info_project{"MET_MEANS_STN"};
$MetMeansGrd        = $var_info_project{"MET_MEANS_GRD"};
$DEM                = $var_info_project{"DEM"};
$DataFlist          = $var_info_project{"DATA_FLIST"};
$Clim_Syr           = $var_info_project{"FORC_CLIM_START_YR"};
$Clim_Eyr           = $var_info_project{"FORC_CLIM_END_YR"};
$MinDays            = $var_info_project{"MIN_DAYS"};
$FractReq           = $var_info_project{"FRACT_REQ"};
$StnsReq            = $var_info_project{"STNS_REQ"};
$Void               = $var_info_project{"VOID"};
$LogDir             = $var_info_project{"LOGS_GRID_DIR"};
$RetroStartDateFile = $var_info_project{"FORCING_RETRO_START_DATE_FILE"};
$CurrspinStartDateFile = $var_info_project{"FORCING_CURRSPIN_START_DATE_FILE"};
$CurrspinEndDateFile   = $var_info_project{"FORCING_CURRSPIN_END_DATE_FILE"};

# File names
$p_ndx_fmt_file        = "$FmtDir/p_ndx.fmt";
$tx_ndx_fmt_file       = "$FmtDir/tx_ndx.fmt";
$tn_ndx_fmt_file       = "$FmtDir/tn_ndx.fmt";
$p_ndx_perqnt_fmt_file = "$FmtDir/p_ndx_perqnt.fmt";
$p_perqnt_grd_file     = "$FmtDir/p_perqnt.grd";
$p_peramt_grd_file     = "$FmtDir/p_peramt.grd";
$p_dlyamt_grd_file     = "$FmtDir/p_dlyamt.grd";
$p_dlyamt_rsc_file     = "$FmtDir/p_dlyamt.rsc";
$tx_ndx_anom_fmt_file  = "$FmtDir/tx_ndx_anom.fmt";
$tn_ndx_anom_fmt_file  = "$FmtDir/tn_ndx_anom.fmt";
$tx_anom_grd_file      = "$FmtDir/tx_anom.grd";
$tn_anom_grd_file      = "$FmtDir/tn_anom.grd";
$tx_grd_file           = "$FmtDir/tx.grd";
$tn_grd_file           = "$FmtDir/tn.grd";

# Log File
$LogFile = "$LogDir/log.update_forcings_asc.pl.$JOB_ID";

# Check for directories; create if necessary & appropriate
foreach $dir ($StnRawDir, $StnTSDir, $StnRetroTSDir, $RetroForcDir,
              $CurrForcDir) {
  if (!-d $dir) {
    die "$0: ERROR: directory $dir not found\n";
  }
}
foreach $dir ($LogDir, $FmtDir) {
  $status = &make_dir($dir);
}

#-------------------------------------------------------------------------------
# Read dates from files
#-------------------------------------------------------------------------------
# Date of beginning of retro forcings
open(FILE, $RetroStartDateFile) or
  die "$0: ERROR: cannot open file $RetroStartDateFile\n";
foreach (<FILE>) {
  if (/^(\d+)\s+(\d+)\s+(\d+)\s+/) {
    ($RetroForc_Syr, $RetroForc_Smon, $RetroForc_Sday) = ($1, $2, $3);
  }
}
close(FILE);

# Date of beginning of current spinup forcings
open(FILE, $CurrspinStartDateFile) or
  die "$0: ERROR: cannot open file $CurrspinStartDateFile\n";
foreach (<FILE>) {
  if (/^(\d+)\s+(\d+)\s+(\d+)\s+/) {
    ($Syr, $Smon, $Sday) = ($1, $2, $3);
  }
}
close(FILE);

# Date of end of current spinup forcings
open(FILE, $CurrspinEndDateFile) or
  die "$0: ERROR: cannot open file $CurrspinEndDateFile\n";
foreach (<FILE>) {
  if (/^(\d+)\s+(\d+)\s+(\d+)\s+/) {
    ($Eyr, $Emon, $Eday) = ($1, $2, $3);
  }
}
close(FILE);

# Date of this ACIS update
opendir(ACIS_DIR, $StnRawDir) or
  die "$0: ERROR: cannot open directory $StnRawDir for reading\n";
@acis_files = grep /ymd$/, readdir(ACIS_DIR);
closedir(ACIS_DIR);
@acis_files_sort = sort(@acis_files);
$final_file      = pop @acis_files_sort;
if ($final_file =~ /(\d\d\d\d)(\d\d)(\d\d)(\.\S+)?\.ymd$/) {
  ($Fyr, $Fmon, $Fday) = ($1, $2, $3);
}

# Optional overriding of dates in files
if ($forcing_upd_date_override) {
  ($Fyr, $Fmon, $Fday) = split /-/, $forcing_upd_date_override;
}
if ($currspin_start_date_override) {
  ($Syr, $Smon, $Sday) = split /-/, $currspin_start_date_override;
}
if ($currspin_end_date_override) {
  ($Eyr, $Emon, $Eday) = split /-/, $currspin_end_date_override;
}

#-------------------------------------------------------------------------------
# END settings
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# Examine raw ACIS data
#-------------------------------------------------------------------------------
# Station .fmt datafile preparation; computes number of usable days
$cmd =
  "$TOOLS_DIR/update_fmt.pl $StnTSDir $p_ndx_fmt_file $tx_ndx_fmt_file " .
  "$tn_ndx_fmt_file $Fyr $Fmon $Fday $Syr $Smon $Sday $Eyr $Emon $Eday " .
  "$StnList $StnsReq $Void >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";

#-------------------------------------------------------------------------------
# QUANTILE METHOD PRECIP
#-------------------------------------------------------------------------------
# 1. calculate percentiles of recent precipitation
print "calculating precip percentiles\n";
$cmd =
  "$TOOLS_DIR/calc.per_pcp_stn_qnts.pl $p_ndx_fmt_file $Syr $Smon " .
  "$Fyr $Fmon $Fday $MinDays $FractReq $StnList $StnRetroTSDir " .
  "$Clim_Syr $Clim_Eyr $Void $p_ndx_perqnt_fmt_file >& $LogFile.tmp; " .
  "cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";

# 2. interpolate station percentiles to regular grid
$template = "$ParamsDirRegrid/input.template.p_perqnt";
$cmd =
  "$TOOLS_DIR/run_regrid.pl $TOOLS_DIR $ConfigRegrid $template $StnList " .
  "$DEM $p_ndx_perqnt_fmt_file $p_perqnt_grd_file >& $LogFile.tmp; " .
  "cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $? \n";

# 3. transform gridded quantiles back to gridded period amounts
$cmd =
  "$TOOLS_DIR/grd_qnts_2_vals.pl $p_perqnt_grd_file $Syr $Smon " .
  "$Fyr $Fmon $Fday $Clim_Syr $Clim_Eyr $RetroForc_Syr $RetroForc_Smon " .
  "$RetroForc_Sday $RetroForcDir $DataFlist $p_peramt_grd_file " .
  ">& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";

# 4. interpolate station daily amounts to grid
print " creating dly amt grid and rescaling\n";
$template = "$ParamsDirRegrid/input.template.p_dlyamt";
$cmd =
  "$TOOLS_DIR/run_regrid.pl $TOOLS_DIR $ConfigRegrid $template " .
  "$StnList $DEM $p_ndx_fmt_file $p_dlyamt_grd_file >& $LogFile.tmp; " .
  "cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $? \n";

# 5. disaggregate gridded period amounts to daily amounts
$cmd =
  "$TOOLS_DIR/grd_peramt_2_dlyamt.pl $p_peramt_grd_file " .
  "$p_dlyamt_grd_file $Syr $Smon $Fyr $Fmon $Fday $p_dlyamt_rsc_file >& " .
  "$LogFile.tmp; cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";

#-------------------------------------------------------------------------------
# ANOMALY METHOD TEMP
#-------------------------------------------------------------------------------
# 1. compute daily T anomalies with respect to long-term monthly means
print "calculating T anomalies\n";
$cmd =
  "$TOOLS_DIR/stn_Tvals_2_anoms.pl $tx_ndx_fmt_file $tn_ndx_fmt_file " .
  "$MetMeansStn $Void $tx_ndx_anom_fmt_file $tn_ndx_anom_fmt_file >& " .
  "$LogFile.tmp; cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";

# 2. interpolate station T anomalies to regular grid
$template = "$ParamsDirRegrid/input.template.t_dlyanm";
$cmd =
  "$TOOLS_DIR/run_regrid.pl $TOOLS_DIR $ConfigRegrid $template $StnList " .
  "$DEM $tx_ndx_anom_fmt_file $tx_anom_grd_file >& $LogFile.tmp; " .
  "cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $? \n";
$cmd =
  "$TOOLS_DIR/run_regrid.pl $TOOLS_DIR $ConfigRegrid $template $StnList " .
  "$DEM $tn_ndx_anom_fmt_file $tn_anom_grd_file >& $LogFile.tmp; " .
  "cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $? \n";

# 3. transform gridded T anomalies to daily T values
$cmd =
  "$TOOLS_DIR/Tgrd_anoms_2_vals.pl $tx_anom_grd_file $tn_anom_grd_file " .
  "$MetMeansGrd $tx_grd_file $tn_grd_file >& $LogFile.tmp; cat $LogFile.tmp" .
  ">> $LogFile";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";

#-------------------------------------------------------------------------------
# Update VIC-style Ascii Forcing Files
#-------------------------------------------------------------------------------
$cmd =
  "$TOOLS_DIR/grds_2_tser.pl $p_dlyamt_rsc_file $tx_grd_file " .
  "$tn_grd_file $Fyr $Fmon $Fday $Eyr $Emon $Eday $MetMeansGrd " .
  "$CurrForcDir >& $LogFile.tmp; cat $LogFile.tmp >> $LogFile";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";

# update the FORC.END_DATE file
open(END_DATE_TMP, ">$CurrspinEndDateFile.tmp") or
  die "$0: ERROR: cannot open end_date file $CurrspinEndDateFile.tmp " .
  "for writing\n";
print END_DATE_TMP "$Fyr $Fmon $Fday    # DATE CURRENT RT FORCINGS END\n";
print END_DATE_TMP "# THIS IS A GENERATED FILE; DO NOT EDIT DATE ABOVE\n";
close(END_DATE_TMP);
$cmd = "mv $CurrspinEndDateFile.tmp $CurrspinEndDateFile";
print "$cmd\n";
(system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";

# Clean up tmp files
`rm -f $LogFile.tmp`;
