# Extract all vars from nc file as usual (SOILLIQ will be messed up during 2nd half of month)
rm -rf ../data/conus/results/2004-present/clm/asc.part2.tmp
mkdir ../data/conus/results/2004-present/clm/asc.part2.tmp
nc2vic -i ../data/conus/results/spinup.05_nearRT/clm/nc/conus.clm2.h0.2005-05-02-00000.nc -o ../data/conus/results/2004-present/clm/asc.part2.tmp -p wb -v QOVER,QDRAI,H2OSNO,SOILLIQ,SOILICE -t
fix_lon.pl ../data/conus/results/2004-present/clm/asc.part2.tmp wb

# Extract SOILLIQ separately (SOILLIQ will be messed up during 2nd half of month)
rm -rf ../data/conus/results/2004-present/clm/asc.part2.soilliq.part1.tmp
mkdir ../data/conus/results/2004-present/clm/asc.part2.soilliq.part1.tmp
nc2vic -i ../data/conus/results/spinup.05_nearRT/clm/nc/conus.clm2.h0.2005-05-02-00000.nc -o ../data/conus/results/2004-present/clm/asc.part2.soilliq.part1.tmp -p wb -v SOILLIQ -t
fix_lon.pl ../data/conus/results/2004-present/clm/asc.part2.soilliq.part1.tmp wb

# Take good SOILLIQ data from files in previous step (1st half of month)
rm -rf ../data/conus/results/2004-present/clm/asc.part2.soilliq.part1.head
mkdir ../data/conus/results/2004-present/clm/asc.part2.soilliq.part1.head
wrap_head.pl ../data/conus/results/2004-present/clm/asc.part2.soilliq.part1.tmp 15 ../data/conus/results/2004-present/clm/asc.part2.soilliq.part1.head

# Extract SOILLIQ via special hack that gets all the data, including bogus cells
rm -rf ../data/conus/results/2004-present/clm/asc.part2.soilliq.part2.raw
mkdir ../data/conus/results/2004-present/clm/asc.part2.soilliq.part2.raw
src/nc2vic.hack/nc2vic -i ../data/conus/results/spinup.05_nearRT/clm/nc/conus.clm2.h0.2005-05-02-00000.nc -o ../data/conus/results/2004-present/clm/asc.part2.soilliq.part2.raw -p wb -v SOILLIQ -t

# Unscramble the cells so that 2nd half of month is good (1st half of month is messed up)
rm -rf ../data/conus/results/2004-present/clm/asc.part2.soilliq.part2.tmp
mkdir ../data/conus/results/2004-present/clm/asc.part2.soilliq.part2.tmp
wrap_hack_clm_200405.pl ../data/conus/results/2004-present/clm/asc.part2.soilliq.part2.raw ../data/conus/results/2004-present/clm/asc.part2.soilliq.part2.tmp
fix_lon.pl ../data/conus/results/2004-present/clm/asc.part2.soilliq.part2.tmp wb

# Take good SOILLIQ data from files in previous step (2nd half of month)
rm -rf ../data/conus/results/2004-present/clm/asc.part2.soilliq.part2
mkdir ../data/conus/results/2004-present/clm/asc.part2.soilliq.part2
wrap_tail.pl ../data/conus/results/2004-present/clm/asc.part2.soilliq.part2.tmp 16 ../data/conus/results/2004-present/clm/asc.part2.soilliq.part2

# Copy the files containing good 1st part of month to new directory, and append 2nd half of month to them
rm -rf ../data/conus/results/2004-present/clm/asc.part2.soilliq
cp -r ../data/conus/results/2004-present/clm/asc.part2.soilliq.part1.head ../data/conus/results/2004-present/clm/asc.part2.soilliq
wrap_append.pl ../data/conus/results/2004-present/clm/asc.part2.soilliq ../data/conus/results/2004-present/clm/asc.part2.soilliq.part2 wb ../data/conus/results/2004-present/clm/asc.part2.soilliq

# Merge these corrected SOILLIQ files with the other vars
rm -rf ../data/conus/results/2004-present/clm/asc.part2.tmp2
mkdir ../data/conus/results/2004-present/clm/asc.part2.tmp2
wrap_hack_join_clm_200405.pl ../data/conus/results/2004-present/clm/asc.part2.tmp wb 7 10 ../data/conus/results/2004-present/clm/asc.part2.soilliq 4 ../data/conus/results/2004-present/clm/asc.part2

# Zero out the ice
rm -rf ../data/conus/results/2004-present/clm/asc.part2
mkdir ../data/conus/results/2004-present/clm/asc.part2
wrap_hack_zeroice_clm_200405.pl ../data/conus/results/2004-present/clm/asc.part2.tmp2 wb 17 10 ../data/conus/results/2004-present/clm/asc.part2

# Add soil liq and soil ice
add_liq_ice.pl ../data/conus/results/2004-present/clm/asc.part2 wb 7 17
