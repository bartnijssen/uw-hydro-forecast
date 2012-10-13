#!<SYSTEM_PERL_EXE> -w
=pod

=head1 NAME

wrap_insert_leap_day.pl

=head1 SYNOPSIS

wrap_insert_leap_day.pl [options] indir prefix outdir start_date end_date

 Options:
    --help|h|?                  brief help message
    --man|info                  full documentation

 All other fields are required

=head1 DESCRIPTION

Wrapper script for insert_leap_day.pl

=cut

use Pod::Usage;
use Getopt::Long;

# Tools directory
$TOOLS_DIR = "<SYSTEM_INSTALLDIR>/bin";

my $result = GetOptions("help|h|?"    => \$help,
                        "man|info"    => \$man);

pod2usage(-verbose => 2, -exitstatus => 0) if $man;
pod2usage(-verbose => 2, -exitstatus => 0) if $help;

# Command-line arguments
$indir      = shift;
$prefix     = shift;
$outdir     = shift;
$start_date = shift;
$end_date   = shift;
pod2usage(-verbose => 1, -exitstatus => 1) 
  if not defined($indir) or not defined($prefix) or not defined($outdir)
  or not defined($start_date) or not defined($end_date);

($start_year, $start_month) = split /-/, $start_date;
($end_year,   $end_month)   = split /-/, $end_date;

# Don't do anything if the time series doesn't contain a leap day
if (!($start_year % 4 == 0 && $start_month * 1 <= 2 && $end_month * 1 > 2) &&
    !($end_year % 4 == 0 && $end_month * 1 > 2)) {
  $copy_files = 1;
}
opendir(INDIR, $indir) or die "$0: ERROR: cannot open $indir\n";
@filelist = grep /^$prefix/, readdir(INDIR);
closedir(INDIR);

if ($copy_files) {
  $cmd = "rm -rf $outdir";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
  $cmd = "cp -r $indir $outdir";
  (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
} else {
  foreach $file (sort(@filelist)) {
    $cmd = "$TOOLS_DIR/insert_leap_day.pl $indir/$file > $outdir/$file";
    (system($cmd) == 0) or die "$0: ERROR: $cmd failed: $?\n";
  }
}
