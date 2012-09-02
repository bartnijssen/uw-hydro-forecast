rm -rf ../data/conus/results/2004-present/clm/asc.part1
mkdir ../data/conus/results/2004-present/clm/asc.part1
nc2vic -i ../data/conus/results/dly_wb.5.1915-2004/clm/nc/conus.clm2.h0.2004-01-02-00000.nc -o ../data/conus/results/2004-present/clm/asc.part1 -p wb -v QOVER,QDRAI,H2OSNO,SOILLIQ,SOILICE -t
nc2vic -i ../data/conus/results/dly_wb.5.1915-2004/clm/nc/conus.clm2.h0.2004-02-02-00000.nc -o ../data/conus/results/2004-present/clm/asc.part1 -p wb -v QOVER,QDRAI,H2OSNO,SOILLIQ,SOILICE -t -a
nc2vic -i ../data/conus/results/dly_wb.5.1915-2004/clm/nc/conus.clm2.h0.2004-03-02-00000.nc -o ../data/conus/results/2004-present/clm/asc.part1 -p wb -v QOVER,QDRAI,H2OSNO,SOILLIQ,SOILICE -t -a
nc2vic -i ../data/conus/results/dly_wb.5.1915-2004/clm/nc/conus.clm2.h0.2004-04-02-00000.nc -o ../data/conus/results/2004-present/clm/asc.part1 -p wb -v QOVER,QDRAI,H2OSNO,SOILLIQ,SOILICE -t -a
nc2vic -i ../data/conus/results/dly_wb.5.1915-2004/clm/nc/conus.clm2.h0.2004-05-02-00000.nc -o ../data/conus/results/2004-present/clm/asc.part1 -p wb -v QOVER,QDRAI,H2OSNO,SOILLIQ,SOILICE -t -a
nc2vic -i ../data/conus/results/dly_wb.5.1915-2004/clm/nc/conus.clm2.h0.2004-06-02-00000.nc -o ../data/conus/results/2004-present/clm/asc.part1 -p wb -v QOVER,QDRAI,H2OSNO,SOILLIQ,SOILICE -t -a
nc2vic -i ../data/conus/results/dly_wb.5.1915-2004/clm/nc/conus.clm2.h0.2004-07-02-00000.nc -o ../data/conus/results/2004-present/clm/asc.part1 -p wb -v QOVER,QDRAI,H2OSNO,SOILLIQ,SOILICE -t -a
nc2vic -i ../data/conus/results/dly_wb.5.1915-2004/clm/nc/conus.clm2.h0.2004-08-02-00000.nc -o ../data/conus/results/2004-present/clm/asc.part1 -p wb -v QOVER,QDRAI,H2OSNO,SOILLIQ,SOILICE -t -a
nc2vic -i ../data/conus/results/dly_wb.5.1915-2004/clm/nc/conus.clm2.h0.2004-09-02-00000.nc -o ../data/conus/results/2004-present/clm/asc.part1 -p wb -v QOVER,QDRAI,H2OSNO,SOILLIQ,SOILICE -t -a
nc2vic -i ../data/conus/results/dly_wb.5.1915-2004/clm/nc/conus.clm2.h0.2004-10-02-00000.nc -o ../data/conus/results/2004-present/clm/asc.part1 -p wb -v QOVER,QDRAI,H2OSNO,SOILLIQ,SOILICE -t -a
nc2vic -i ../data/conus/results/dly_wb.5.1915-2004/clm/nc/conus.clm2.h0.2004-11-02-00000.nc -o ../data/conus/results/2004-present/clm/asc.part1 -p wb -v QOVER,QDRAI,H2OSNO,SOILLIQ,SOILICE -t -a
nc2vic -i ../data/conus/results/dly_wb.5.1915-2004/clm/nc/conus.clm2.h0.2004-12-02-00000.nc -o ../data/conus/results/2004-present/clm/asc.part1 -p wb -v QOVER,QDRAI,H2OSNO,SOILLIQ,SOILICE -t -a
nc2vic -i ../data/conus/results/spinup.05_nearRT/clm/nc/conus.clm2.h0.2005-01-02-00000.nc -o ../data/conus/results/2004-present/clm/asc.part1 -p wb -v QOVER,QDRAI,H2OSNO,SOILLIQ,SOILICE -t -a
nc2vic -i ../data/conus/results/spinup.05_nearRT/clm/nc/conus.clm2.h0.2005-02-02-00000.nc -o ../data/conus/results/2004-present/clm/asc.part1 -p wb -v QOVER,QDRAI,H2OSNO,SOILLIQ,SOILICE -t -a
nc2vic -i ../data/conus/results/spinup.05_nearRT/clm/nc/conus.clm2.h0.2005-03-02-00000.nc -o ../data/conus/results/2004-present/clm/asc.part1 -p wb -v QOVER,QDRAI,H2OSNO,SOILLIQ,SOILICE -t -a
nc2vic -i ../data/conus/results/spinup.05_nearRT/clm/nc/conus.clm2.h0.2005-04-02-00000.nc -o ../data/conus/results/2004-present/clm/asc.part1 -p wb -v QOVER,QDRAI,H2OSNO,SOILLIQ,SOILICE -t -a
add_liq_ice.pl ../data/conus/results/2004-present/clm/asc.part1 wb 7 17
fix_lon.pl ../data/conus/results/2004-present/clm/asc.part1 wb
