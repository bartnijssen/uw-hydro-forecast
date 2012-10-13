#!<SYSTEM_PERL_EXE> -w

=pod

=head1 NAME

add_fields.pl

=head1 SYNOPSIS

add_fields.pl [options] filename skip_columns col1_1:col1_2,col2_1:col2_2,...

 Options:
    --help|h|?                  brief help message
    --man|info                  full documentation

 All other fields are required

=head1 DESCRIPTION

This script adds groups of ascii text file columns together.  For each group of
columns, it places the sum in the first column and removes the other columns
from the file.  The output files overwrite the input files.

For example, to add columns 3,4,and 5 together, and to add columns 7 and 8
together: add_fields.pl filename 3:4:5,7:8

=cut
use Pod::Usage;
use Getopt::Long;
my $result = GetOptions("help|h|?" => \$help,
                        "man|info" => \$man);
pod2usage(-verbose => 2, -exitstatus => 0) if $man;
pod2usage(-verbose => 2, -exitstatus => 0) if $help;
$file  = shift;  # Input file name
$ndate = shift;  # Number of leading date fields; these won't be processed
$col_group_list = shift;  # format: col1_1:col1_2,col2_1:col2_2,...
pod2usage(-verbose => 1, -exitstatus => 1)
  if not defined($file) or
    not defined($ndate) or
    not defined
    ($col_group_list);
@col_groups = split /,/, $col_group_list;
open(FILE, "$file") or die "$0: ERROR: cannot open $file for reading\n";

foreach (<FILE>) {
  chomp;
  @fields = split /\s+/;
  foreach $group (@col_groups) {
    @cols = split /:/, $group;
    for ($i = 1 ; $i < @cols ; $i++) {
      if ($cols[0] >= $ndate && $cols[$i] >= $ndate) {
        $fields[$cols[0]] += $fields[$cols[$i]];
        $skip[$cols[$i]] = 1;
      }
    }
  }
  printf "%s", $fields[0];
  for ($i = 1 ; $i < $ndate ; $i++) {
    printf " %s", $fields[$i];
  }
  for ($i = $ndate ; $i < @fields ; $i++) {
    if (!$skip[$i]) {
      printf " %f", $fields[$i];
    }
  }
  print "\n";
}
close(FILE);
