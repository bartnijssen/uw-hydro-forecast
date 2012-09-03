#run_model.pl -m noah_2.8.new -p conus.new -f retro  -s 1915-01-01 -e 2004-12-31 -r spinup.retro -x none

run_model.pl -m noah_2.8.new -p conus.new -f retro  -s 1915-01-01 -e 1915-12-31 -r spinup.1915.01 -i /raid8/forecast/sw_monitor/data/conus.new/state/spinup.retro/noah_2.8.new/state.20041231.nc -x none
run_model.pl -m noah_2.8.new -p conus.new -f retro  -s 1915-01-01 -e 1915-12-31 -r spinup.1915.02 -i /raid8/forecast/sw_monitor/data/conus.new/state/spinup.1915.01/noah_2.8.new/state.19151231.nc -x none
run_model.pl -m noah_2.8.new -p conus.new -f retro  -s 1915-01-01 -e 1915-12-31 -r spinup.1915.03 -i /raid8/forecast/sw_monitor/data/conus.new/state/spinup.1915.02/noah_2.8.new/state.19151231.nc -x none
run_model.pl -m noah_2.8.new -p conus.new -f retro  -s 1915-01-01 -e 1915-12-31 -r spinup.1915.04 -i /raid8/forecast/sw_monitor/data/conus.new/state/spinup.1915.03/noah_2.8.new/state.19151231.nc -x none
run_model.pl -m noah_2.8.new -p conus.new -f retro  -s 1915-01-01 -e 1915-12-31 -r spinup.1915.05 -i /raid8/forecast/sw_monitor/data/conus.new/state/spinup.1915.04/noah_2.8.new/state.19151231.nc -x none
run_model.pl -m noah_2.8.new -p conus.new -f retro  -s 1915-01-01 -e 1915-12-31 -r spinup.1915.06 -i /raid8/forecast/sw_monitor/data/conus.new/state/spinup.1915.05/noah_2.8.new/state.19151231.nc -x none
run_model.pl -m noah_2.8.new -p conus.new -f retro  -s 1915-01-01 -e 1915-12-31 -r spinup.1915.07 -i /raid8/forecast/sw_monitor/data/conus.new/state/spinup.1915.06/noah_2.8.new/state.19151231.nc -x none
run_model.pl -m noah_2.8.new -p conus.new -f retro  -s 1915-01-01 -e 1915-12-31 -r spinup.1915.08 -i /raid8/forecast/sw_monitor/data/conus.new/state/spinup.1915.07/noah_2.8.new/state.19151231.nc -x none
run_model.pl -m noah_2.8.new -p conus.new -f retro  -s 1915-01-01 -e 1915-12-31 -r spinup.1915.09 -i /raid8/forecast/sw_monitor/data/conus.new/state/spinup.1915.08/noah_2.8.new/state.19151231.nc -x none
run_model.pl -m noah_2.8.new -p conus.new -f retro  -s 1915-01-01 -e 1915-12-31 -r spinup.1915.10 -i /raid8/forecast/sw_monitor/data/conus.new/state/spinup.1915.09/noah_2.8.new/state.19151231.nc -x none

run_model.pl -m noah_2.8.new -p conus.new -f retro  -s 1916-01-01 -e 2004-12-31 -i /raid8/forecast/sw_monitor/data/conus.new/state/spinup.1915.10/noah_2.8.new/state.19151231.nc
