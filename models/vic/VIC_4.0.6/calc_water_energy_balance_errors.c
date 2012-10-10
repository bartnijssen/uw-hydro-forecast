#include <stdio.h>
#include <stdlib.h>
#include <vicNl.h>

static char vcid[] = "$Id: calc_water_energy_balance_errors.c,v 1.1.2.1 2006/09/26 19:49:17 vicadmin Exp $";

void calc_water_balance_error(int    rec,
			      double inflow,
			      double outflow,
			      double storage) {
/***************************************************************
  calc_water_balance_error  Keith Cherkauer        April 1998

  This subroutine computes the overall model water balance, and 
  warns the model user if large errors are found.
***************************************************************/

  static double last_storage;
  static double cum_error;
  static double max_error;
  static int    error_cnt;
  static int    Nrecs;

  double error;

  if(rec<0) {
    last_storage = storage;
    cum_error    = 0.;
    max_error    = 0.;
    error_cnt    = 0;
    Nrecs        = -rec;
  }
  else {
    error = inflow - outflow - (storage - last_storage);
    cum_error += error;
    if(fabs(error)>fabs(max_error) && fabs(error)>1e-5) {
      max_error = error;
      fprintf(stderr,"Maximum Moist Error:\t%i\t%.5f\t%.5f\n",
	      rec,error,cum_error);
    }
    if(rec==Nrecs-1) {
      fprintf(stderr,"Total Cumulative Water Error for Grid Cell = %.4f\n",
	      cum_error);
    }
    last_storage = storage;
  }

}

void calc_energy_balance_error(int    rec,
			       double net_rad,
			       double latent,
			       double sensible,
			       double grnd_flux,
			       double snow_fluxes) {
/***************************************************************
  calc_energy_balance_error   Keith Cherkauer     April 1998

  This subroutine computes the overall model energy balance, and
  reports the maximum time step error above a thresehold to the
  user.  The total cumulative error for the grid cell is also 
  computed and reported at the end of the model run.
***************************************************************/

  static double cum_error;
  static double max_error;
  static int    Nrecs;

  double error;

  if(rec<0) {
    cum_error = 0;
    Nrecs     = -rec;
    max_error = 0;
  }
  else {
    error = net_rad - latent - sensible - grnd_flux + snow_fluxes;
    cum_error += error;
    if(fabs(error)>fabs(max_error) && fabs(error)>0.001) {
      max_error = error;
      if ( rec > 0 ) 
	fprintf(stderr,"Maximum Energy Error:\t%i\t%.4f\t%.4f\n",
		rec,error,cum_error/(double)rec);
      else 
	fprintf(stderr,"Maximum Energy Error:\t%i\t%.4f\t%.4f\n",
		rec,error,cum_error);
    }
    if(rec==Nrecs-1) {
      fprintf(stderr,"Total Cumulative Energy Error for Grid Cell = %.4f\n",
	      cum_error/(double)rec);
    }
  }
}

