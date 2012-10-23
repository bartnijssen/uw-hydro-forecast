#!<SYSTEM_PERL_EXE> -w

=pod

=head1 NAME

wrap_add_fields.pl

=head1 SYNOPSIS

add_fields.pl [options] indir prefix skip_columns outdir  
                        col1_1:col1_2,col2_1:col2_2,...

 Options:
    --help|h|?                  brief help message
    --man|info                  full documentation

 All other fields are required

=head1 DESCRIPTION

Wrapper script for add_fields.pl

=cut

use Log::Log4perl qw(:easy);
use Pod::Usage;
use Getopt::Long;

# Tools Directory - Edit this to reflect location of your SIMMA installation
$TOOLS_DIR = "<SYSTEM_INSTALLDIR>/bin";

# Command-line arguments
Log::Log4perl->init('<SYSTEM_LOG_CONFIG>');
my $result = GetOptions("help|h|?" => \$help,
                        "man|info" => \$man);
pod2usage(-verbose => 2, -exitstatus => 0) if $man;
pod2usage(-verbose => 2, -exitstatus => 0) if $help;
$indir         = shift;
$prefix        = shift;
$ndate         = shift;
$outdir        = shift;
$col_pair_list = shift;
pod2usage(-verbose => 1, -exitstatus => 1)
  if not defined($indir) or
    not defined($prefix) or
    not defined($ndate)  or
    not defined($outdir) or
    not defined
    ($col_pair_list);
opendir(INDIR, $indir) or LOGDIE("Cannot open $indir");
@filelist = grep /^$prefix/, readdir(INDIR);
closedir(INDIR);

foreach $file (sort(@filelist)) {
  $cmd =
    "$TOOLS_DIR/add_fields.pl $indir/$file $ndate $col_pair_list " .
    "> $outdir/$file";
  (system($cmd) == 0) or LOGDIE("$cmd failed: $?");
}
