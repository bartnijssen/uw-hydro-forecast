package UWTime;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(Delta_Days
             Add_Delta_Days
             Days_In_Month
             Date_Prev
             Today
             Yesterday
             ddmmyy2yymmdd
             leap_year
             yymmdd2ddmmyy);

use Date::Manip;
sub Delta_Days {

  @args = @_;
#  print "$#args\n";
  if ( $#args == 1 ) {
    ( $date1, $date2 ) = @args;
  } 
  elsif ( $#args == 5 ) {
     ( $yr1, $mon1, $day1, $yr2, $mon2, $day2 ) = @args;
     $date1 = sprintf( "%d%02d%02d", $yr1, $mon1, $day1);
     $date2 = sprintf( "%d%02d%02d", $yr2, $mon2, $day2);
  }
  else {
    # Unrecognized number of args
    return 0;
  }
  
#  print "DD date1 $date1 date2 $date2\n";
  $delta = DateCalc( $date1, $date2, \$err, 0 );
#  print "Delta is $delta\n";
  $str = Delta_Format( $delta, 0, "%dh" );
#  print "Returning $str\n";
  return $str;

}


sub Add_Delta_Days {
  @args = @_;
  if ( $#args == 1 ) {
    ( $date, $delta ) = @args;
    $singledate = 1;
  } 
  elsif ( $#args == 3 ){
    ( $yr, $mon, $day, $delta ) = @args;
    $date = sprintf( "%d%02d%02d", $yr, $mon, $day);
    $singledate = 0;
  }
  else {
  # Unrecognized number of args
    return 0;
  }

  unless ( $delta =~ m/day/ ) {
    $delta = $delta . " days ";
  }
  $date2 = DateCalc( $date, $delta, \$err, 1 );
  $date2 = unpack( "a8",  $date2 );

  if ( $singledate ) {
    return $date2;
  } else {
    ( $yr, $mon, $day ) = unpack("a4a2a2", $date2);
    return ( $yr, $mon, $day );

  }

}


sub Date_Prev {

  ( $date ) = @_;
  $prevdate = Date_GetPrev( $date, undef, 2 );
  return $prevdate;

}

sub Days_In_Month {
  
  ( $yr, $mon ) = @_;
  $days = Date_DaysInMonth( $mon, $yr );
  return $days;

}

sub leap_year {

  ( $yr ) = @_;
  $flag = Date_LeapYear( $yr );
  return $flag;

}

sub ddmmyy2yymmdd {

  ( $ddmmyy ) = @_;
  ( $dd, $mm, $yy ) = unpack("a2a2a2", $ddmmyy);
  $yymmdd = $yy . $mm . $dd;
  return $yymmdd;

}

sub yymmdd2ddmmyy {

  ( $yymmdd ) = @_;
  ( $yy, $mm, $dd ) = unpack("a2a2a2", $yymmdd);
  $ddmmyy = $dd . $mm . $yy;
  return $ddmmyy;

}

sub Today {

  $today = DateCalc("today", "+0 day", 0);
  $today = unpack "a8", $today;
  return $today;

}

      
sub Yesterday {

  $yesterday = DateCalc("today", "- 1 day", 0);
  $yesterday = unpack "a8", $yesterday;
  return $yesterday;

}
  
1;
