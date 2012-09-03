#run_model.pl -m vic -p conus.new -f retro -pf data -s 1915-01-01 -e 2004-12-31 -r spinup.retro
#run_model.pl -m vic -p conus.new -f retro -pf data -s 1915-01-01 -e 1915-12-31 -r spinup.1915.01 -i /raid8/forecast/sw_monitor/data/conus.new/state/spinup.retro/vic/state_20041231
#run_model.pl -m vic -p conus.new -f retro -pf data -s 1915-01-01 -e 1915-12-31 -r spinup.1915.02 -i /raid8/forecast/sw_monitor/data/conus.new/state/spinup.1915.01/vic/state_19151231
#run_model.pl -m vic -p conus.new -f retro -pf data -s 1915-01-01 -e 1915-12-31 -r spinup.1915.03 -i /raid8/forecast/sw_monitor/data/conus.new/state/spinup.1915.02/vic/state_19151231
#run_model.pl -m vic -p conus.new -f retro -pf data -s 1915-01-01 -e 1915-12-31 -r spinup.1915.04 -i /raid8/forecast/sw_monitor/data/conus.new/state/spinup.1915.03/vic/state_19151231
#run_model.pl -m vic -p conus.new -f retro -pf data -s 1915-01-01 -e 1915-12-31 -r spinup.1915.05 -i /raid8/forecast/sw_monitor/data/conus.new/state/spinup.1915.04/vic/state_19151231
#run_model.pl -m vic -p conus.new -f retro -pf data -s 1915-01-01 -e 1915-12-31 -r spinup.1915.06 -i /raid8/forecast/sw_monitor/data/conus.new/state/spinup.1915.05/vic/state_19151231
#run_model.pl -m vic -p conus.new -f retro -pf data -s 1915-01-01 -e 1915-12-31 -r spinup.1915.07 -i /raid8/forecast/sw_monitor/data/conus.new/state/spinup.1915.06/vic/state_19151231
#run_model.pl -m vic -p conus.new -f retro -pf data -s 1915-01-01 -e 1915-12-31 -r spinup.1915.08 -i /raid8/forecast/sw_monitor/data/conus.new/state/spinup.1915.07/vic/state_19151231
#run_model.pl -m vic -p conus.new -f retro -pf data -s 1915-01-01 -e 1915-12-31 -r spinup.1915.09 -i /raid8/forecast/sw_monitor/data/conus.new/state/spinup.1915.08/vic/state_19151231
#run_model.pl -m vic -p conus.new -f retro -pf data -s 1915-01-01 -e 1915-12-31 -r spinup.1915.10 -i /raid8/forecast/sw_monitor/data/conus.new/state/spinup.1915.09/vic/state_19151231

run_model.pl -m vic -p conus.new -f retro -pf data -s 1916-01-01 -e 2004-12-31 -i /raid8/forecast/sw_monitor/data/conus.new/state/spinup.1915.10/vic/state_19151231
