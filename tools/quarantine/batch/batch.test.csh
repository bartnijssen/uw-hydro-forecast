wrap_tail.pl /raid8/forecast/sw_monitor/data/conus.new/forcing/retro/asc_vicinp 1 /raid8/forecast/sw_monitor/data/conus.new/forcing/curr_spinup/asc_vicinp
update_forcings_asc.pl /raid8/forecast/sw_monitor/tools /raid8/forecast/sw_monitor/config/config.project.conus.new /raid8/forecast/sw_monitor/config/config.model.regrid 2005-01-01 2005-01-01 2005-02-28 >& log.test.txt
mv /raid8/forecast/sw_monitor/data/conus.new/forcing/curr_spinup/asc_vicinp /raid8/forecast/sw_monitor/data/conus.new/forcing/curr_spinup/asc_vicinp.200501.test
mkdir /raid8/forecast/sw_monitor/data/conus.new/forcing/curr_spinup/asc_vicinp
