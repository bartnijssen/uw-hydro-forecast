mkdir /raid8/forecast/sw_monitor/data/conus.new/results/retro/sac.new/daily/asc.sm.pctl
mkdir /raid8/forecast/sw_monitor/data/conus.new/results/retro/sac.new/daily/asc.swe.pctl
mkdir /raid8/forecast/sw_monitor/data/conus.new/results/retro/sac.new/daily/asc.stot.pctl
compute_retro_pctls.pl /raid8/forecast/sw_monitor/data/conus.new/results/retro/sac.new/daily/asc wb 8,9,10,11,12 0 -99 5 /raid8/forecast/sw_monitor/data/conus.new/results/retro/sac.new/daily/asc.sm.pctl sm
compute_retro_pctls.pl /raid8/forecast/sw_monitor/data/conus.new/results/retro/sac.new/daily/asc wb 7 0 -99 5 /raid8/forecast/sw_monitor/data/conus.new/results/retro/sac.new/daily/asc.swe.pctl swe
compute_retro_pctls.pl /raid8/forecast/sw_monitor/data/conus.new/results/retro/sac.new/daily/asc wb 7,8,9,10,11,12 0 -99 5 /raid8/forecast/sw_monitor/data/conus.new/results/retro/sac.new/daily/asc.stot.pctl stot
