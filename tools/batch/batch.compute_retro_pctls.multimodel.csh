mkdir /raid8/forecast/sw_monitor/data/conus.new/results/retro/multimodel/daily/asc.sm.pctl
mkdir /raid8/forecast/sw_monitor/data/conus.new/results/retro/multimodel/daily/asc.swe.pctl
mkdir /raid8/forecast/sw_monitor/data/conus.new/results/retro/multimodel/daily/asc.stot.pctl
compute_retro_pctls.pl /raid8/forecast/sw_monitor/data/conus.new/results/retro/multimodel/daily/asc.sm sm 3 0 -99 5 /raid8/forecast/sw_monitor/data/conus.new/results/retro/multimodel/daily/asc.sm.pctl sm
compute_retro_pctls.pl /raid8/forecast/sw_monitor/data/conus.new/results/retro/multimodel/daily/asc.swe swe 3 0 -99 5 /raid8/forecast/sw_monitor/data/conus.new/results/retro/multimodel/daily/asc.swe.pctl swe
compute_retro_pctls.pl /raid8/forecast/sw_monitor/data/conus.new/results/retro/multimodel/daily/asc.stot stot 3 0 -99 5 /raid8/forecast/sw_monitor/data/conus.new/results/retro/multimodel/daily/asc.stot.pctl stot
