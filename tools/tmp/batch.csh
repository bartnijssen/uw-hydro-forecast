grds_2_tser.US.pl 2007 11 18 2007 11 15 /raid8/forecast/sw_monitor/data/conus/forcing/curr_spinup/asc_vicinp/
wrap_vicDisagg.pl -p conus -f curr_spinup -pf data -s 2007-09-01 -e 2007-11-18
wrap_vic2nc.pl -p conus -f curr_spinup -pf full_data -s 2007-09-01 -e 2007-11-18
run_model.pl -m noah -p conus -f curr_spinup -pf full_data -s 2007-09-01 -e 2007-11-18 -x Qs,Qsb,SWE,SoilMoist -i /raid8/forecast/sw_monitor/data/conus/state/spinup.05_nearRT/noah/state.200708.nc
run_model.pl -m sac -p conus -f curr_spinup -pf full_data -s 2007-09-01 -e 2007-11-18 -x Qs,Qsb,SWE,SoilMoist -i /raid8/forecast/sw_monitor/data/conus/state/spinup.05_nearRT/sac/state.200708.nc
get_stats.pl noah conus 2007 11 18
get_stats.pl sac conus 2007 11 18
