#mkdir /raid8/forecast/sw_monitor/data/conus.new/results/retro/vic/daily/asc.sm.pctl
#mkdir /raid8/forecast/sw_monitor/data/conus.new/results/retro/vic/daily/asc.swe.pctl
#mkdir /raid8/forecast/sw_monitor/data/conus.new/results/retro/vic/daily/asc.stot.pctl
compute_retro_pctls.pl /raid8/forecast/sw_monitor/data/conus.new/results/retro/vic/daily/asc fluxes 8,9,10 0 -99 5 /raid8/forecast/sw_monitor/data/conus.new/results/retro/vic/daily/asc.sm.pctl sm
compute_retro_pctls.pl /raid8/forecast/sw_monitor/data/conus.new/results/retro/vic/daily/asc fluxes 11 0 -99 5 /raid8/forecast/sw_monitor/data/conus.new/results/retro/vic/daily/asc.swe.pctl swe
compute_retro_pctls.pl /raid8/forecast/sw_monitor/data/conus.new/results/retro/vic/daily/asc fluxes 8,9,10,11 0 -99 5 /raid8/forecast/sw_monitor/data/conus.new/results/retro/vic/daily/asc.stot.pctl stot
