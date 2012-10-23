#!<SYSTEM_PERL_EXE> -w

=pod

=head1 NAME

fcst_stats.pl

=head1 SYNOPSIS

fcst_stats.pl [options] model project year month day [directory]

 Options:
    --help|h|?                  brief help message
    --man|info                  full documentation

 Required (in order):
    infile               input file
    outfile              output file

=head1 DESCRIPTION

Take a SORTED row of data and find interpolated weibull plotting
position of an input value in it, assigning fixed value when it is
beyond the bounds of the column.  program stops if not all rows have
have same number of columns as first row.  also find additive & multiplicative
anomalies wrt mean of distribution.

 input format:  
   each row of tabular input file has
   <target val> <sorted distribution vals, lowest to highest>

 output fmt: 
   each row has <percentile> <additive anom> <multiplicative anom>

=head2 AUTHORS

 A. Wood Aug 2003
 and others since then

=cut

use lib qw(<SYSTEM_INSTALLDIR>/lib <SYSTEM_PERL_LIBS>);
use Log::Log4perl qw(:easy);
use Pod::Usage;
use Getopt::Long;
use Statistics::Lite qw(mean);
Log::Log4perl->init('<SYSTEM_LOG_CONFIG>');
my $result = GetOptions("help|h|?" => \$help,
                        "man|info" => \$man);
pod2usage(-verbose => 2, -exitstatus => 0) if $man;
pod2usage(-verbose => 2, -exitstatus => 0) if $help;

# read in filenames
@ARGV == 2 or pod2usage(-verbose => 1, -exitstatus => 1);

# open files
open(INF, "<$ARGV[0]") or LOGDIE("Can't open $ARGV[0]: $!");
DEBUG("reading $ARGV[0] -- writing $ARGV[1]");
open(OUT, ">$ARGV[1]") or LOGDIE("Can't open $ARGV[1]: $!");
$r   = 0;  # counter
@tmp = ();
while ($line = <INF>) {

  # process first row
  ($targ[$r], @tmp) = split(" ", $line);
  if ($r == 0) {
    $NDIST = @tmp;                            # number in distribution
    $min_p = 1 / ($NDIST + 1) * 0.5;          # def. p-val for targ below dist
    $max_p = $NDIST / ($NDIST + 1) + $min_p;  # ditto for above dist
    DEBUG("climatology distribution has $NDIST elements");
  } else {
    if ($NDIST != @tmp) {
      $ntmp   = @tmp;
      $rowtmp = $r + 1;
      LOGDIE("Input file not a regular table: Row $rowtmp distribution has " .
             "$ntmp instead of $NDIST values");
    }
  }

  # get stats for current row
  $distmean[$r] = mean @tmp;
  $add_anom[$r] = $targ[$r] - $distmean[$r];
  if ($distmean[$r] == 0) {
    $mult_anom[$r] = $weib[$r] = -9999;
  } else {

    # mult anom
    $mult_anom[$r] = ($targ[$r] / $distmean[$r] - 1) * 100;

    # percentiles
    $i = 0;
    while ($i < $NDIST) {
      if ($tmp[$i] >= $targ[$r] && $i == 0) {
        $weib[$r] = $min_p;
        last;
      } elsif ($tmp[$i] <= $targ[$r] && $i == $NDIST - 1) {
        $weib[$r] = $max_p;
        last;
      } elsif ($tmp[$i] >= $targ[$r]) {

        # note, i as counter in weib eq. must start at 1 not 0
        # whereas in arrays, starts at 0
        $weib[$r] =
          ($targ[$r] - $tmp[$i - 1]) /
          ($tmp[$i] - $tmp[$i - 1]) *
          (($i + 1) / ($NDIST + 1) - $i / ($NDIST + 1)) + $i /
          ($NDIST + 1);
        last;
      }
      $i++;
    }  # done calc'ing percentiles
  }      # end if non-zero mean case
  $r++;  # increment row
}  # done reading data file
close(INF);
DEBUG("processed $r rows");

# Make sure stats are reasonable
$min_count = 0;
$max_count = 0;
for ($row = 0 ; $row < $r ; $row++) {
  if ($weib[$row] == $min_p) {
    $min_count++;
  } elsif ($weib[$row] == $max_p) {
    $max_count++;
  }
}
if ($min_count + $max_count == $r) {
  LOGDIE("data in file $ARGV[0] consist only of extreme values");
}

# Write out stats
for ($row = 0 ; $row < $r ; $row++) {
  printf OUT "%.2f %.2f %.1f %.1f %.3f\n",
    $targ[$row], $distmean[$row], $add_anom[$row], $mult_anom[$row],
    $weib[$row];
}
close(OUT);
