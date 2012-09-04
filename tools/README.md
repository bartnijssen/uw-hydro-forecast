UW Hydro Forecast System
========================
Tools
-----
Following the layout of the original forecast system, most of the scripts and code needed to run a forecast system (except for the routing and model code) are located in the tools subdirectory.

The scripts have been further divided into a series of subdirectories:

* **configure**: configuration scripts to set up a new forecasting system
* **crontab**: crontab listings
* **drivers**: driver scripts that run a series of steps in the forecasting process
* **publish**: plotting and publishing scripts
* **qsub**: scripts to be submitted to a cluster scheduler such as the Sun Grid Engine
* **src**: scripts and programs that perform a specific forecasting task. These are typically called by one of the drivers.

[Surface Water Hydrology Group](http://www.hydro.washington.edu)
University of Washington
