#!/usr/bin/perl -w
# plot_ESP.pl: Script to plot ESP plots

# Ali Akanda, 041805, 050505
# A.Wood, jul07, modified to make runoff plots too
# 2008-05-22 Generalized for multimodel sw monitor.	TJB
# $Id: $
#-------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------
# Determine tools, root, and config directories - assume this script lives in TOOLS_DIR/
#----------------------------------------------------------------------------------------------
if ($0 =~ /^(.+)\/[^\/]+$/) {
  $TOOLS_DIR = $1;
}
elsif ($0 =~ /^[^\/]+$/) {
  $TOOLS_DIR = ".";
}
else {
  die "$0: ERROR: cannot determine tools directory\n";
}
if ($TOOLS_DIR =~ /^(.+)\/tools/i) {
  $ROOT_DIR = $1;
}
else {
  $ROOT_DIR = "$TOOLS_DIR/..";
}
$CONFIG_DIR = "$ROOT_DIR/config";
$COMMON_DIR = "/raid8/forecast/common";

#----------------------------------------------------------------------------------------------
# Include external modules
#----------------------------------------------------------------------------------------------
# Subroutine for reading config files
require "$TOOLS_DIR/simma_util.pl";

# Date arithmetic
use Date::Calc qw(Add_Delta_YM Add_Delta_Days Days_in_Month Delta_Days);

# Other
use LWP::Simple;

#-------------------------------------------------------------------------------
# Parse the command line
#-------------------------------------------------------------------------------

$PROJECT = shift; # project name, e.g. conus mexico
$MODEL = shift; # model name, e.g. vic noah sac clm multimodel
$yr = shift;
$mon = shift;
$day = shift;

#----------------------------------------------------------------------------------------------
# Set up constants
#----------------------------------------------------------------------------------------------

# Derived variables
$MODEL_UC = $MODEL;
$MODEL_UC =~ tr/a-z/A-Z/;
$PROJECT_UC = $PROJECT;
$PROJECT =~ tr/A-Z/a-z/;
$PROJECT_UC =~ tr/a-z/A-Z/;
$datenow = sprintf("%04d%02d%02d", $yr, $mon, $day);

$datestr = "$datenow";
# Unique identifier for this job
$JOB_ID = `date +%y%m%d-%H%M%S`;
if ($JOB_ID =~ /(\S+)/) {
  $JOB_ID = $1;
}


# Read project configuration info
$ConfigProject = "$CONFIG_DIR/config.project.$PROJECT";
$var_info_project_ref = &read_config($ConfigProject);
%var_info_project = %{$var_info_project_ref};

# Read model configuration info
$ConfigModel = "$CONFIG_DIR/config.model.$MODEL";
$var_info_model_ref = &read_config($ConfigModel);
%var_info_model = %{$var_info_model_ref};

# Substitute model-specific information into project variables
foreach $key_proj (keys(%var_info_project)) {
  foreach $key_model (keys(%var_info_model)) {
    $var_info_project{$key_proj} =~ s/<$key_model>/$var_info_model{$key_model}/g;
  }
}

# Save relevant project info in variables
$ESP                = $var_info_project{"ESP"};
#$CPC                = $var_info_project{"CPC"};
$PROJ               = $var_info_project{"MAP_PROJ"};
$COORD              = $var_info_project{"MAP_COORD"};
$ANNOT              = $var_info_project{"MAP_ANNOT"};
$XX                 = $var_info_project{"MAP_XX"};
$YY                 = $var_info_project{"MAP_YY"};
$SCALE_X            = $var_info_project{"MAP_SCALE_X"};
$current_PROJ 	    = $PROJ;
$current_COORD      = $COORD;
$current_ANNOT      = $ANNOT;
$current_XX         = $XX;
$current_YY         = $YY;
$current_SCALE_X    = $SCALE_X;
$WebPubDir       = $var_info_project{"ESP_WEB_PUB_DIR"};
$DepotDir        = $var_info_project{"PLOT_DEPOT_DIR"};


# Derived address 
$XYZZ_DIR = "$ESP/xyzz";
$PLOT_DIR = "$ESP/plots";

$PlotVarList = $var_info_model{"ESP_PLOT_VARS"};
@varnames = split /,/, $PlotVarList;

$Plottype = $var_info_model{"ESP_PLOT_TYPE"};
@plotlist = split /,/, $Plottype;

$ESPLEAD = $var_info_model{"ESP_PLOT_LEAD"};
@leadlist = split /,/, $ESPLEAD;

$ENSTYPE = $var_info_model{"ENS_TYPE"};
@typelist = split /,/, $ENSTYPE;

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
  $status = &make_dir($dir);
}


# Loop over variables
foreach $varname (@varnames) {
foreach $type (@typelist) {
foreach $plotname (@plotlist)
  {

foreach $lead (@leadlist)
{

if ($type eq "full"){
    #  Output filename
    if (($varname eq "sm") && ($plotname eq "qnt")) 
    {
      $outfile = "$PLOT_DIR/$datenow/sm.qnt.fut_lm$lead.ps";
    }
    elsif (($varname eq "sm") && ($plotname eq "prob")) 
    {
      $outfile = "$PLOT_DIR/$datenow/sm.prob-lt20.fut_lm$lead.ps";
    }
    elsif (($varname eq "ro") && ($plotname eq "qnt")) 
    {
      $outfile = "$PLOT_DIR/$datenow/ro3mo.qnt.fut_lm$lead.ps";
    }
    elsif (($varname eq "ro") && ($plotname eq "prob")) 
    {
      $outfile = "$PLOT_DIR/$datenow/ro3mo.prob-lt20.fut_lm$lead.ps";
    }
}
elsif ($type eq "subset"){
    #  Output filename
    if (($varname eq "sm") && ($plotname eq "qnt")) 
    {
      $outfile = "$PLOT_DIR/$datenow/sm.qnt.SUBSET.fut_lm$lead.ps";
    }
    elsif (($varname eq "sm") && ($plotname eq "prob")) 
    {
      $outfile = "$PLOT_DIR/$datenow/sm.prob-lt20.SUBSET.fut_lm$lead.ps";
    }
    elsif (($varname eq "ro") && ($plotname eq "qnt")) 
    {
      $outfile = "$PLOT_DIR/$datenow/ro3mo.qnt.SUBSET.fut_lm$lead.ps";
    }
    elsif (($varname eq "ro") && ($plotname eq "prob")) 
    {
      $outfile = "$PLOT_DIR/$datenow/ro3mo.prob-lt20.SUBSET.fut_lm$lead.ps";
    }
}
    
    
    
    # First title line
    if ($varname eq "sm") 
    {
      $longname = "Soil Moisture";
    }
    elsif ($varname eq "ro") 
    {
      $longname = "Cumulative 3-month Runoff";
    }
    $title1 = "$MODEL_UC Predicted $longname Percentiles";

    # Second title line
    if ($type eq "full")
    {
    if ($plotname eq "qnt") 
    {
      $title2 = "based on ranking of climatological ESP median";
    }
    else
      {
      $title2 = "fraction of climatological ESP traces in lowest quantile";
      }
    }
    elsif ($type eq "subset")
    {if ($plotname eq "qnt")
        {$title2 = "based on ranking of ESP ENSO-Subset median";}
     else
     {$title2 = "fraction of ENSO ESP traces in lowest quantile";
     }
    }
					
## title 3

   $title3 = "Initialized $datenow -- $lead month lead";

    # Color scale
    if ($plotname eq "qnt") 
    {
      $cptlabel1 = "percentile";
      $cptlabel2 = "NODATA";
      $cptfile = "$COMMON_DIR/cpt/CPC_smplot.cpt";
     } 
   
   else 
    {   
      $cptlabel1 = "% chance of below 20th percentile";
      $cptlabel2 = "NODATA";
      $cptfile = "$COMMON_DIR/cpt/prob_of_lt20.midwhite.cpt";
    }

    # Temporary data file for plotting purposes
   $datafile = "$XYZZ_DIR/$datenow/ESP_$PROJECT.$MODEL.$datenow.xyzz";
   
  if (($varname eq "ro") && ($plotname eq "prob"))
   { $QNTS = 2; # number of probabilities given per forecast lead time
     $LDS = 3;  # number of leads
     $VAR = 4; # RO3, out of sm, swe, ro-6, ro-3
   if ($type eq "full")
   {
   $xyzzfile = "$XYZZ_DIR/$datenow/wb_prob.ENS.20-33.$MODEL.$datenow.xyzz";
   $cmd = "awk \'{print \$1,\$2,100-(\$(2+$lead*$QNTS -1 +$QNTS*$LDS*($VAR-1))+\$(2+$lead*$QNTS+$QNTS*$LDS*($VAR-1)))}\' $xyzzfile > $datafile";
   (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
   }
   elsif ($type eq "subset")
   {
   $xyzzfile = "$XYZZ_DIR/$datenow/wb_prob.ENS.20-33.SUBSET.$MODEL.$datenow.xyzz";
   $cmd = "awk \'{print \$1,\$2,100-(\$(2+$lead*$QNTS -1 +$QNTS*$LDS*($VAR-1))+\$(2+$lead*$QNTS+$QNTS*$LDS*($VAR-1)))}\' $xyzzfile > $datafile";
   (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
   }
   }
   elsif (($varname eq "ro") && ($plotname eq "qnt"))
   { $QNTS = 5; # number of quantiles given per forecast
     $LDS = 3;  # number of leads
     $VAR = 4; # SM, out of sm, swe, ro-6, ro-3
     
     if ($type eq "full")
     {
     $xyzzfile = "$XYZZ_DIR/$datenow/wb_qnts.ENS.$MODEL.$datestr.xyzz";
     $cmd = "awk \'{print \$1,\$2,\$($lead*5+$QNTS*$LDS*($VAR-1))*100}' $xyzzfile > $datafile";
   (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
   }
     elsif ($type eq "subset")
     {
     $xyzzfile = "$XYZZ_DIR/$datenow/wb_qnts.ENS.SUBSET.$MODEL.$datestr.xyzz";
     $cmd = "awk \'{print \$1,\$2,\$($lead*5+$QNTS*$LDS*($VAR-1))*100}' $xyzzfile > $datafile";
   (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
   }
   }
   elsif (($varname eq "sm") && ($plotname eq "prob"))
   {
    $QNTS = 2; # number of probabilities given per forecast lead time
    $LDS = 3;  
    $VAR = 1; # SM, out of sm, swe, ro-6, ro-3
   if ($type eq "full"){
   $xyzzfile = "$XYZZ_DIR/$datenow/wb_prob.ENS.20-33.$MODEL.$datenow.xyzz";
    $cmd = "awk \'{print \$1,\$2,100-(\$(2+$lead*$QNTS -1 +$QNTS*$LDS*($VAR-1))+\$(2+$lead*$QNTS+$QNTS*$LDS*($VAR-1)))}\' $xyzzfile > $datafile";
   (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
   }
   
   elsif ($type eq "subset"){
   $xyzzfile = "$XYZZ_DIR/$datenow/wb_prob.ENS.20-33.SUBSET.$MODEL.$datenow.xyzz";
    $cmd = "awk \'{print \$1,\$2,100-(\$(2+$lead*$QNTS -1 +$QNTS*$LDS*($VAR-1))+\$(2+$lead*$QNTS+$QNTS*$LDS*($VAR-1)))}\' $xyzzfile > $datafile";
   (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
   }
   }
   

   elsif (($varname eq "sm") && ($plotname eq "qnt"))
   { $QNTS = 5; 
     $LDS = 3;  
     $VAR = 1; # SM, out of sm, swe, ro-6, ro-3
     if ($type eq "full"){
     $xyzzfile = "$XYZZ_DIR/$datenow/wb_qnts.ENS.$MODEL.$datestr.xyzz";
   $cmd = "awk \'{print \$1,\$2,\$($lead*5+$QNTS*$LDS*($VAR-1))*100}' $xyzzfile > $datafile";
   (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
   }
     elsif ($type eq "subset"){
     $xyzzfile = "$XYZZ_DIR/$datenow/wb_qnts.ENS.SUBSET.$MODEL.$datestr.xyzz";
   $cmd = "awk \'{print \$1,\$2,\$($lead*5+$QNTS*$LDS*($VAR-1))*100}' $xyzzfile > $datafile";
   (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
   }
   }

       $polyfile1 = "NODATA";
       $polyfile2 = "NODATA";
           
	   

    # Call the generic plotting script
    $plot_scr = "$TOOLS_DIR/plot.var_WA_ESP.scr";
    $cmd = "$plot_scr $datafile $outfile $current_COORD $current_PROJ $current_ANNOT $current_XX $current_YY $current_SCALE_X \"$title1\" \"$title2\" \"$title3\" $cptfile \"$cptlabel1\" \"$cptlabel2\" $polyfile1 $polyfile2";
    
    print "$cmd\n";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";

    # Clean up temp data file
    $cmd = "rm -f $datafile";
    (system($cmd)==0) or die "$0: ERROR: $cmd failed: $?\n";
} ### lead
} ### Qnt, Prob
} ### FULL SUBSET
} ### SM, RO
print "Done with all plots!\n";


