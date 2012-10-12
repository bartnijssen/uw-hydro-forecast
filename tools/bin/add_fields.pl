#!<SYSTEM_PERL_EXE> -w
# This script adds groups of ascii text file columns together.  For each group
# of columns, it places the sum in the first column and removes the other
# columns from the file.  The output files overwrite the input files.
# Usage:
# add_fields.pl filename col1_1:col1_2,col2_1:col2_2,...
# For example, to add columns 3,4,and 5 together, and to add columns 7 and 8
# together: add_fields.pl filename 3:4:5,7:8
$file  = shift;  # Input file name
$ndate = shift;  # Number of leading date fields; these won't be processed
$col_group_list = shift;  # format: col1_1:col1_2,col2_1:col2_2,...
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
