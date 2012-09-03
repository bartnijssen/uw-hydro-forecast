mkdir /raid8/forecast/sw_monitor/data/conus.new/results/retro/noah_2.8/daily/asc.sm.pctl
mkdir /raid8/forecast/sw_monitor/data/conus.new/results/retro/noah_2.8/daily/asc.swe.pctl
mkdir /raid8/forecast/sw_monitor/data/conus.new/results/retro/noah_2.8/daily/asc.stot.pctl
compute_retro_pctls.pl /raid8/forecast/sw_monitor/data/conus.new/results/retro/noah_2.8/daily/asc wb 8,9,10,11 0 -99 5 /raid8/forecast/sw_monitor/data/conus.new/results/retro/noah_2.8/daily/asc.sm.pctl sm
compute_retro_pctls.pl /raid8/forecast/sw_monitor/data/conus.new/results/retro/noah_2.8/daily/asc wb 7 0 -99 5 /raid8/forecast/sw_monitor/data/conus.new/results/retro/noah_2.8/daily/asc.swe.pctl swe
compute_retro_pctls.pl /raid8/forecast/sw_monitor/data/conus.new/results/retro/noah_2.8/daily/asc wb 7,8,9,10,11 0 -99 5 /raid8/forecast/sw_monitor/data/conus.new/results/retro/noah_2.8/daily/asc.stot.pctl stot
