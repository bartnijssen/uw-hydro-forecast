#!/usr/bin/perl -w

### Master script to run and plot VIC ESP drought probability forecast.

use LWP::Simple;
use Date::Calc qw(Add_Delta_Days);

# 1.  initial checks
($day,$mon,$yr) = (localtime)[3..5];
($yy,$mm,$dd) = Add_Delta_Days($yr+1900,$mon+1,$day,-1);


#$datestr = sprintf("%04d%02d%02d",$Curr_Yr,$Curr_Mon,$Curr_Day);

$yr = sprintf ("%04d", $yy);
$mon = sprintf ("%02d", $mm);
$day = sprintf ("%02d", $dd);


print "\n Updating VIC ESP forecast for $yr $mon $day";


$PATH = "/raid/forecast/sw_monitor/esp_scripts";


##### Run the VIC ESP run script

sleep 10;

`$PATH/run_VIC_no_rout_ESP.scr $yr $mon $day 1951 2002 190`;

#### Run the script to calculate the statistics and plot

sleep 10;

`$PATH/CALC_and_PLOT.scr $yr $mon $day`;

##### mail after the update is done

chdir "/raid/forecast/sw_monitor";

`echo "SWM VIC ESP plots ok" > done`;
`mail shrad  < done`;
`mail fmunoz  < done`;


