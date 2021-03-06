UW Hydro Forecast System
========================
Tools
-----
Following the layout of the original forecast system, most of the scripts and code needed to run a forecast system (except for the routing and model code) are located in the tools subdirectory.

The scripts have been further divided into a series of subdirectories:

* **bin**: executable scripts and programs that perform one or more forecasting tasks.
* **crontab**: crontab listings and driver scripts called by the crontab entries
* **publish**: plotting and publishing scripts
* **qsub**: scripts to be submitted to a cluster scheduler such as the Sun Grid Engine
* **src**: source code for programs that need to be compiled (C, fortran) to
    perform a specific forecasting task. The executable is moved to the **bin** directory.

[Surface Water Hydrology Group](http://www.hydro.washington.edu)
University of Washington
