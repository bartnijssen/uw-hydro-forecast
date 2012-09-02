#run_model.pl -m noah_2.8 -p mexico -f retro  -s 1925-01-01 -e 2004-12-31 -r spinup.retro -x none

#run_model.pl -m noah_2.8 -p mexico -f retro  -s 1925-01-01 -e 1925-12-31 -r spinup.1925.01 -i /raid8/forecast/sw_monitor/data/mexico/state/spinup.retro/noah_2.8/state.20041231.nc -x none
#run_model.pl -m noah_2.8 -p mexico -f retro  -s 1925-01-01 -e 1925-12-31 -r spinup.1925.02 -i /raid8/forecast/sw_monitor/data/mexico/state/spinup.1925.01/noah_2.8/state.19251231.nc -x none
#run_model.pl -m noah_2.8 -p mexico -f retro  -s 1925-01-01 -e 1925-12-31 -r spinup.1925.03 -i /raid8/forecast/sw_monitor/data/mexico/state/spinup.1925.02/noah_2.8/state.19251231.nc -x none
#run_model.pl -m noah_2.8 -p mexico -f retro  -s 1925-01-01 -e 1925-12-31 -r spinup.1925.04 -i /raid8/forecast/sw_monitor/data/mexico/state/spinup.1925.03/noah_2.8/state.19251231.nc -x none
#run_model.pl -m noah_2.8 -p mexico -f retro  -s 1925-01-01 -e 1925-12-31 -r spinup.1925.05 -i /raid8/forecast/sw_monitor/data/mexico/state/spinup.1925.04/noah_2.8/state.19251231.nc -x none
#run_model.pl -m noah_2.8 -p mexico -f retro  -s 1925-01-01 -e 1925-12-31 -r spinup.1925.06 -i /raid8/forecast/sw_monitor/data/mexico/state/spinup.1925.05/noah_2.8/state.19251231.nc -x none
#run_model.pl -m noah_2.8 -p mexico -f retro  -s 1925-01-01 -e 1925-12-31 -r spinup.1925.07 -i /raid8/forecast/sw_monitor/data/mexico/state/spinup.1925.06/noah_2.8/state.19251231.nc -x none
#run_model.pl -m noah_2.8 -p mexico -f retro  -s 1925-01-01 -e 1925-12-31 -r spinup.1925.08 -i /raid8/forecast/sw_monitor/data/mexico/state/spinup.1925.07/noah_2.8/state.19251231.nc -x none
#run_model.pl -m noah_2.8 -p mexico -f retro  -s 1925-01-01 -e 1925-12-31 -r spinup.1925.09 -i /raid8/forecast/sw_monitor/data/mexico/state/spinup.1925.08/noah_2.8/state.19251231.nc -x none
#run_model.pl -m noah_2.8 -p mexico -f retro  -s 1925-01-01 -e 1925-12-31 -r spinup.1925.10 -i /raid8/forecast/sw_monitor/data/mexico/state/spinup.1925.09/noah_2.8/state.19251231.nc -x none

run_model.pl -m noah_2.8 -p mexico -f retro  -s 1926-01-01 -e 2004-12-31 -i /raid8/forecast/sw_monitor/data/mexico/state/spinup.1925.10/noah_2.8/state.19251231.nc
