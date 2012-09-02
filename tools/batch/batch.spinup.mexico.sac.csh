run_model.noextract.pl -m sac -p mexico -f retro -pf full_data -s 1925-01-01 -e 2004-12-31 -r spinup.retro

run_model.noextract.pl -m sac -p mexico -f retro -pf full_data -s 1925-01-01 -e 1925-12-31 -r spinup.1925.01 -i /raid8/forecast/sw_monitor/data/mexico/state/spinup.retro/sac/state.200412.nc
run_model.noextract.pl -m sac -p mexico -f retro -pf full_data -s 1925-01-01 -e 1925-12-31 -r spinup.1925.02 -i /raid8/forecast/sw_monitor/data/mexico/state/spinup.1925.01/sac/state.192512.nc
run_model.noextract.pl -m sac -p mexico -f retro -pf full_data -s 1925-01-01 -e 1925-12-31 -r spinup.1925.03 -i /raid8/forecast/sw_monitor/data/mexico/state/spinup.1925.02/sac/state.192512.nc
run_model.noextract.pl -m sac -p mexico -f retro -pf full_data -s 1925-01-01 -e 1925-12-31 -r spinup.1925.04 -i /raid8/forecast/sw_monitor/data/mexico/state/spinup.1925.03/sac/state.192512.nc
run_model.noextract.pl -m sac -p mexico -f retro -pf full_data -s 1925-01-01 -e 1925-12-31 -r spinup.1925.05 -i /raid8/forecast/sw_monitor/data/mexico/state/spinup.1925.04/sac/state.192512.nc
run_model.noextract.pl -m sac -p mexico -f retro -pf full_data -s 1925-01-01 -e 1925-12-31 -r spinup.1925.06 -i /raid8/forecast/sw_monitor/data/mexico/state/spinup.1925.05/sac/state.192512.nc
run_model.noextract.pl -m sac -p mexico -f retro -pf full_data -s 1925-01-01 -e 1925-12-31 -r spinup.1925.07 -i /raid8/forecast/sw_monitor/data/mexico/state/spinup.1925.06/sac/state.192512.nc
run_model.noextract.pl -m sac -p mexico -f retro -pf full_data -s 1925-01-01 -e 1925-12-31 -r spinup.1925.08 -i /raid8/forecast/sw_monitor/data/mexico/state/spinup.1925.07/sac/state.192512.nc
run_model.noextract.pl -m sac -p mexico -f retro -pf full_data -s 1925-01-01 -e 1925-12-31 -r spinup.1925.09 -i /raid8/forecast/sw_monitor/data/mexico/state/spinup.1925.08/sac/state.192512.nc
run_model.noextract.pl -m sac -p mexico -f retro -pf full_data -s 1925-01-01 -e 1925-12-31 -r spinup.1925.10 -i /raid8/forecast/sw_monitor/data/mexico/state/spinup.1925.09/sac/state.192512.nc

run_model.pl -m sac -p mexico -f retro -pf full_data -s 1926-01-01 -e 2004-12-31 -i /raid8/forecast/sw_monitor/data/mexico/state/spinup.1925.10/sac/state.192512.nc
