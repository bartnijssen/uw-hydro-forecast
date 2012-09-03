#!/usr/bin/perl -w
# aggregated long term timeseries to a rolling monthly timestep, based on
# most recent day worth of data

# input format:  y m d p et ro bf ta sm1 sm2 sm3 swe
# output format:  for each cell of the basin, one file per variable with
# one header row, then <yr><mo><value>

# output tailored for SPI/SRI calculation program
# Author:  A. Wood Jan 2008

use Date::Calc qw(Delta_Days Add_Delta_Days Add_Delta_YM);

# ---------- ARGS ------------------------------
# phobic paths
($Cyr, $Cmon, $Cday) = ($ARGV[0],$ARGV[1],$ARGV[2]);
$Flist  = "$ARGV[3]";
$RetroDir = "$ARGV[4]";
$NearRTDir = "$ARGV[5]";
$RTDir = "$ARGV[6]";
$OutDirRoot = "$ARGV[7]";
$Clim_Syr = "$ARGV[8]"; 
# read file/station list ----------------------
@cell = `cat $Flist`;
chomp(@cell);

# check adequacy of data records ---------------
open(FL, "<$RetroDir/$cell[0]") or die "can't open $RetroDir/$cell[0]: $!\n";
$r=0;
while(<FL>) {
  ($yr[$r],$mo[$r],$dy[$r],@tmp) = split;
  $r++;
}
close(FL);
open(FL, "<$NearRTDir/$cell[0]") or die "can't open $NearRTDir/$cell[0]: $!\n";
while(<FL>) {
  ($yr[$r],$mo[$r],$dy[$r],@tmp) = split;
  $r++;
}
close(FL);
$rt_skip = 0;  # counter to see if it's necesary to skip days from overlapping rt archive
open(FL, "<$RTDir/$cell[0]") or die "can't open $RTDir/$cell[0]: $!\n";
while(<FL>) {
  ($yy,$mm,$dd,@tmp) = split;
  if(Delta_Days($yr[$r-1],$mo[$r-1],$dy[$r-1],$yy,$mm,$dd) < 1) {
    $rt_skip++;  # read an overlapping day
  } else {
    ($yr[$r],$mo[$r],$dy[$r]) = ($yy, $mm, $dd);
    $r++;
  }
}
close(FL);
$datarecs = @yr;  # last available record is $datarecs-1

# assign data start & end dates, and target date for final cum. runoff day

($yr0, $mon0, $day0) = ($yr[0],$mo[0],$dy[0]);  # data start date
if(!(defined($ARGV[0]))) {  # default to last day of simulation data
  ($Cyr, $Cmon, $Cday) = ($yr[$datarecs-1],$mo[$datarecs-1],$dy[$datarecs-1]);
}
$days_needed = Delta_Days($yr0,$mon0,$day0,$yr[$datarecs-1],$mo[$datarecs-1],$dy[$datarecs-1])+1;
if($datarecs != $days_needed) {
  die "ERROR:  read $datarecs days but period from $yr0$mon0$day0 to $yr[$datarecs-1]$mo[$datarecs-1]$dy[$datarecs-1] should have $days_needed days\n";
} else {
  print "read $datarecs days for period from $yr0$mon0$day0 to $yr[$datarecs-1]$mo[$datarecs-1]$dy[$datarecs-1]\n";
}
$datestr = sprintf("%04d%02d%02d",$Cyr,$Cmon,$Cday);  # current day
print "accumulations will end on $datestr\n";

# first find start date & record in clim period for rolling accumulation periods
@recbnd = @wyr = @wmo = @wdy = ();
($wyr[0], $wmo[0], $wdy[0]) = ($Clim_Syr, $Cmon, $Cday); # same day, in clim start yr
$recbnd[0] = Delta_Days($yr0,$mon0,$day0,$wyr[0], $wmo[0], $wdy[0]); # accums start 1 day later

# now find rest of start dates for each monthly accum period
$s = 0;
do {
  $s++;
  ($wyr[$s], $wmo[$s], $wdy[$s]) = Add_Delta_YM($wyr[0], $wmo[0], $wdy[0], 0, $s);
  $recbnd[$s] = Delta_Days($yr0,$mon0,$day0, $wyr[$s], $wmo[$s], $wdy[$s]);

} while ( Delta_Days($Cyr,$Cmon,$Cday, $wyr[$s], $wmo[$s], $wdy[$s]) < 0);
$steps = $s;

# %%%%%%%%%%%%%% loop through cells/stations %%%%%%%%%%%%%%%%%%%%%%%%
for($c=0;$c<@cell;$c++) {
#for($c=0;$c<1;$c++) {

  print "$c $cell[$c]\n";
  @data = ();
  Read_Vars_One_Cell($cell[$c], $rt_skip, \@data);  # call subr. for getting data
$Outfl_p = "$OutDirRoot/out.p/$cell[$c]";
$Outfl_r = "$OutDirRoot/out.ro/$cell[$c]";
  open(OUTP, ">$Outfl_p") or die "can't open $Outfl_p: $!\n";
  open(OUTR, ">$Outfl_r") or die "can't open $Outfl_r: $!\n";
  printf OUTP "rolling monthly totals for $datestr (0.01 inches)\n";
  printf OUTR "rolling monthly totals for $datestr (0.01 inches)\n";

  for($s=1;$s<=$steps;$s++) {  # loop through monthly periods
    $ro = $pcp = 0;
    for($r=$recbnd[$s-1]+1;$r<$recbnd[$s];$r++) {  # loop through records in each period
      # custom statement to get tot pcp, avg sm, tot runoff
      $pcp += $data[$r][0];
      $ro  += $data[$r][2];
    }
    printf OUTP "%4d %02d %d\n", $wyr[$s], $wmo[$s], $pcp/25.4*100;
    printf OUTR "%4d %02d %d\n", $wyr[$s], $wmo[$s], $ro/25.4*100;
  }
  close(OUTP);
  close(OUTR);

}  # end looping through stations %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%





# %%%%%%%%%%%%%%%%%%%% SUBROUTINES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# subroutine to read runoff from one cell
#   uses global variables for directory names
sub Read_Vars_One_Cell {
  ($cname, $skip_rec, $data_ref) = @_;

  open(FL, "<$RetroDir/$cname") or die "can't open $RetroDir/$cname: $!\n";
  $r=0;
  while(<FL>) {
    @tmp = split;
    $data_ref->[$r][0] = $tmp[3];            # pcp: reference this way to pass back values
    $data_ref->[$r][1] = $tmp[4];            # et
    $data_ref->[$r][2] = $tmp[5]+$tmp[6];    # ro+bf
    $data_ref->[$r][3] = $tmp[6];            # tair
    $data_ref->[$r][4] = $tmp[7]+$tmp[8]+$tmp[9];           # sm
    $data_ref->[$r][5] = $tmp[10];           # swe
    $r++;
  }
  close(FL);
  open(FL, "<$NearRTDir/$cname") or die "can't open $NearRTDir/$cname: $!\n";
  while(<FL>) {
    @tmp = split;
    $data_ref->[$r][0] = $tmp[3];            # pcp: reference this way to pass back values
    $data_ref->[$r][1] = $tmp[4];            # et
    $data_ref->[$r][2] = $tmp[5]+$tmp[6];    # ro+bf
    $data_ref->[$r][3] = $tmp[6];            # tair
    $data_ref->[$r][4] = $tmp[7]+$tmp[8]+$tmp[9];           # sm
    $data_ref->[$r][5] = $tmp[10];           # swe
    $r++;
  }
  close(FL);
  open(FL, "<$RTDir/$cname") or die "can't open $RTDir/$cname: $!\n";
  $cnt=0;
  while(<FL>) {
    if($cnt>=$skip_rec) {
      @tmp = split;
      $data_ref->[$r][0] = $tmp[3];            # pcp: reference this way to pass back values
      $data_ref->[$r][1] = $tmp[4];            # et
      $data_ref->[$r][2] = $tmp[5]+$tmp[6];    # ro+bf
      $data_ref->[$r][3] = $tmp[6];            # tair
      $data_ref->[$r][4] = $tmp[7]+$tmp[8]+$tmp[9];           # sm
      $data_ref->[$r][5] = $tmp[10];           # swe
      $r++;
    } else {
      $cnt++;
    }
  }
  close(FL);
}

