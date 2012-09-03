#!/usr/bin/perl -w

use Date::Calc qw(Add_Delta_Days);
use LWP::Simple;
use Date::Calc qw(Add_Delta_YM Add_Delta_Days Days_in_Month Delta_Days);
($tday,$tmon,$tyr) = (localtime)[3..5];  # get today's date

($yr,$mon,$day) = Add_Delta_Days ($tyr+1900, $tmon+1, $tday,-1);

$cyr  = sprintf ("%04d", $yr);
$cmon = sprintf ("%02d", $mon);
$cday = sprintf ("%02d", $day);
$DATE = sprintf("%04d%02d%02d", $cyr, $cmon, $cday);
print "\nUpdating USwide nowcast for $DATE";

#### Run the USWIDE update script

`/raid8/forecast/proj/uswide/tools/uswide_plots/update_CONUS_ncast_new.scr $cyr $cmon $cday`;

