wrap_add_fields.pl ../data/conus/results/spinup_nearRT/clm/daily/asc wb 4 ../data/conus/results/spinup_nearRT/clm/daily/asc.tmp 4:5:6,10:20,11:21,12:22,13:23,14:24,15:25,16:26,17:27,18:28,19:29
wrap_insert_leap_day.pl ../data/conus/results/spinup_nearRT/clm/daily/asc.tmp wb ../data/conus/results/spinup_nearRT/clm/daily/asc.tmp2 2005-01-01 2008-05-31
clm_fix_lon.pl ../data/conus/results/spinup_nearRT/clm/daily/asc.tmp2 wb
rm -rf ../data/conus/results/spinup_nearRT/clm/daily/asc
rm -rf ../data/conus/results/spinup_nearRT/clm/daily/asc.tmp
mv ../data/conus/results/spinup_nearRT/clm/daily/asc.tmp2 ../data/conus/results/spinup_nearRT/clm/daily/asc
