mv ../data/conus.new/forcing/retro/asc_vicinp ../data/conus.new/forcing/retro/asc_vicinp.old
mkdir ../data/conus.new/forcing/retro/asc_vicinp
wrap_head.pl ../data/conus.new/forcing/retro/asc_vicinp.old 32873 ../data/conus.new/forcing/retro/asc_vicinp
mv ../data/conus.new/results/retro/vic/daily/asc ../data/conus.new/results/retro/vic/daily/asc.old
mkdir ../data/conus.new/results/retro/vic/daily/asc
wrap_head.pl ../data/conus.new/results/retro/vic/daily/asc.old 32508 ../data/conus.new/results/retro/vic/daily/asc
mv ../data/conus.new/results/retro/clm/daily/asc ../data/conus.new/results/retro/clm/daily/asc.old
mkdir ../data/conus.new/results/retro/clm/daily/asc
wrap_head.pl ../data/conus.new/results/retro/clm/daily/asc.old 32508 ../data/conus.new/results/retro/clm/daily/asc
mv ../data/conus.new/results/retro/noah_2.8/daily/asc ../data/conus.new/results/retro/noah_2.8/daily/asc.old
mkdir ../data/conus.new/results/retro/noah_2.8/daily/asc
wrap_head.pl ../data/conus.new/results/retro/noah_2.8/daily/asc.old 32508 ../data/conus.new/results/retro/noah_2.8/daily/asc
mv ../data/conus.new/results/retro/sac/daily/asc ../data/conus.new/results/retro/sac/daily/asc.old
mkdir ../data/conus.new/results/retro/sac/daily/asc
wrap_head.pl ../data/conus.new/results/retro/sac/daily/asc.old 32508 ../data/conus.new/results/retro/sac/daily/asc
