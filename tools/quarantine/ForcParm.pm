package ForcParm;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(read_param
             update_param
             write_log_header
             return_err);



#
# read_param - read a parameter file. Return data hash.
#
sub read_param{

  my ( $basin, $parmfile ) = @_;
  
  my $separator = "\\|\\|";
  my %pdh;
  my ($bas, $key, $val);
  my $line;

  open ( PARM, "<$parmfile") or die "Can't open parameter file $parmfile: $!\n";

  while ( <PARM> ) {
    $line = $_;
    chomp( $line );
    if ( ($line =~ /^#/) || ( $line =~ /^\s*$/) ){
      next;
    }

    ($bas, $key, $val) = split(/$separator/, $line);
    $key =~ s/^\s+//;
    $key =~ s/\s+$//;
    $val =~ s/^\s+//;
    if ( ($bas =~ /$basin/) || ( $bas =~ /all/ ) ){
      $pdh{$key} = $val;
    }    

  }
  close( PARM );
  return \%pdh;

}

#
# update_param - update a single entry in the specified parm file 
#
sub update_param{

  my ( $parmfile, $basin, $key, $value ) = @_;

  my $tmpfile = "$parmfile.tmp.tmp";
  my $found = 0;

  # Wait for others to finish the tmp file (quasi-lock)
  while ( -e $tmpfile ){
    sleep 5;
  }

  open ( OLD, "<$parmfile") or die "Can't read the param file $parmfile: $!\n";
  open ( TMP, ">$tmpfile") or die "Can't open tmp file $tmpfile: $! \n";

  while( <OLD> ) {

    $line = $_;
    chomp( $line );

    if ( $line =~ /$basin\s*\S+\s*$key/ ) {
      printf TMP "%s || %-11s || $value\n", $basin, $key;
      $found = 1;
    } else {
      print TMP "$line\n";
    }
  }
  # Handle case of new value to be added to the file.
  if ( $found == 0 ) {
    printf TMP "%s || %-11s || $value\n", $basin, $key;
  }
  close( TMP );
  close( OLD );
  
  rename $tmpfile, $parmfile;

}


#
# write_log_header
#
sub write_log_header{

  my ( $fh, $script ) = @_;
  print $fh "\n###############\n";
  print $fh "Starting run of $script\n";
  print $fh "Time is " . localtime(time) . "\n";

}


#
# return_err
#
sub return_err{

  my ( $fh, $err_string ) = @_;

  print $fh "Error in module $0\n";
  print $fh "$err_string \n";
  print "-99 -99 -99\n";
  exit(1); 

}

1;
