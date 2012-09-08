#!/usr/bin/env perl
use warnings;
# Wrapper for the regrid program.  This runs the regrid program to regrid
# station data to a user-specified mask.

# Get command-line arguments
$TOOLS_DIR = shift;
$CONFIG_REGRID = shift;
$template = shift;
$StnList = shift;
$DEM = shift;
$FmtFile = shift;
$GrdFile = shift;

# Subroutine for reading config files
require "$TOOLS_DIR/bin/simma_util.pl";

# Regrid configuration info
$var_info_regrid_ref = &read_config($CONFIG_REGRID);
%var_info_regrid = %{$var_info_regrid_ref};
$RegridExe = $var_info_regrid{"MODEL_EXE_NAME"};
$RegridDir = $var_info_regrid{"MODEL_EXE_DIR"};
$InputFile = $var_info_regrid{"INPUT_FILE"};

# Read template, make appropriate substitutions, and write to input file
open (INPUT, ">$InputFile") or die "$0: ERROR: cannot open input file $InputFile for writing\n";
open (TPLT, $template) or die "$0: ERROR: cannot open template file $template for reading\n";
foreach (<TPLT>) {
  s/<STN_LIST>/$StnList/;
  s/<DEM>/$DEM/;
  s/<FMT_FILE>/$FmtFile/;
  s/<GRD_FILE>/$GrdFile/;
  print INPUT;
}
close(TPLT);
close(INPUT);

# Run the regrid program
$cmd = "cd $RegridDir; $RegridDir/$RegridExe; cd -";
print "$cmd\n";
(system($cmd)==0) or die "$0: ERROR: $cmd failed: $? \n";

