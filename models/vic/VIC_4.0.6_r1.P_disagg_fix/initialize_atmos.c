#include <stdio.h>
#include <stdlib.h>
#include <vicNl.h>

static char vcid[] = "$Id: initialize_atmos.c,v 4.4.2.12 2007/01/11 02:01:05 vicadmin Exp $";

void initialize_atmos(atmos_data_struct        *atmos,
                      dmy_struct               *dmy,
		      FILE                    **infile,
                      double                    theta_l,
                      double                    theta_s,
                      double                    phi,
		      double                    elevation,
		      double                    annual_prec,
		      double                    wind_h,
		      double                    roughness,
		      double                    avgJulyAirTemp,
		      double                   *Tfactor,
#if OUTPUT_FORCE
                      char                     *AboveTreeLine,
                      out_data_file_struct     *out_data_files,
                      out_data_struct          *out_data)
#else /* OUTPUT_FORCE */
                      char                     *AboveTreeLine)
#endif /* OUTPUT_FORCE */
/**********************************************************************
  initialize_atmos	Keith Cherkauer		February 3, 1997

  This routine initializes atmospheric variables for both the model
  time step, and the time step used by the snow algorithm (if different).
  Air temperature is estimated using MTCLIM (see routine for reference),
  atmospheric moisture is estimated using Kimball's algorithm (see 
  routine for reference), and radiation is estimated using Bras's algorithms
  (see routines for reference).

  WARNING: This subroutine is site specific.  Location parameters
    must be changed before compilation.

  UNITS: mks
	energy - W/m^2

  Modifications:
  11-18-98  Removed variable array yearly_epot, since yearly potential
            evaporation is no longer used for estimating the dew
            point temperature from daily minimum temperature.   KAC
  11-25-98  Added second check to make sure that the difference 
            between tmax and tmin is positive, after being reset
            when it was equal to 0.                        DAG, EFW
  12-1-98   Changed relative humidity computations so that they 
            use air temperature for the time step, instead of average
            daily temperature.  This allows relative humidity to
            change during the day, when the time step is less than
            daily.                                              KAC
  8-19-99   MIN_TDEW was added to prevent the dew point temperature
            estimated by Kimball's equations from becoming so low
            that svp() fails.                                   Bart
  9-4-99    Code was largely rewritten to change make use of the MTCLIM
            meteorological preprocessor which estimates sub-daily 
	    met forcings for all time steps.  The atmos_data_struct was
	    also reconfigured so that it has a new record for each
	    model time step, but stores sub-time step forcing data
	    (that might be needed for the snow model) within each
	    record, eliminating the on the fly estimations used in
	    previous versions of the model.              Bart and Greg
  03-12-03 Modifed to add AboveTreeLine to soil_con_struct so that
           the model can make use of the computed treeline.     KAC
  09-02-2003 Moved COMPUTE_TREELINE flag from user_def.h to the 
             options structure.  Now when not set to FALSE, the 
             value indicates the default above treeline vegetation
             if no usable vegetation types are in the grid cell 
             (i.e. everything has a canopy).  A negative value  
             will cause the model to use bare soil.  Make sure that 
             positive index value refer to a non-canopied vegetation
             type in the vegetation library.					KAC
  07-May-04 Replaced
		rint(something)
	    with
		(float)(int)(something + 0.5)
	    to handle rounding errors without resorting to rint()
	    function.								TJB
  16-Jun-04 Modified to pass avgJulyAirTemp argument to
	    compute_treeline().							TJB
  2006-Sep-01 (Port from 4.1.0) Modified support for OUTPUT_FORCE option.	TJB
  2006-Sep-11 Implemented flexible output configuration; uses the new
              out_data and out_data_files structures.				TJB
  2006-Sep-14 (Port from 4.1.0) Added support for ALMA input variables.		TJB
  2006-Nov-06 Fixed typo in the "if" statement at line 104 that was
	      preventing AIR_TEMP from being accepted at any time step.		TJB
  2006-Dec-29 Added REL_HUMID to the list of supported met input variables.	TJB
  2006-Dec-29 Added blocks to handle some neglected met input variables.	TJB
  2007-Jan-02 Added CSNOWF and LSSNOWF to list of supported met input
	      variables.							TJB
  2007-Jan-02 Added ALMA_INPUT option; removed TAIR and PSURF from list of
	      supported met input variables.					TJB
  2007-Nov-12 Modified the pressure estimate to take into account elevation
	      and temperature.							TJB

**********************************************************************/
{
  extern option_struct       options;
  extern param_set_struct    param_set;
  extern global_param_struct global_param;
  extern int                 NR, NF;

  int     i;
  int     j;
  int     band;
  int     day;
  int     hour;
  int     rec;
  int     step;
  int     idx;
  int    *tmaxhour;
  int    *tminhour;
  double  deltat;
  double  min_Tfactor;
  double  shortwave;
  double  svp_tair;
  double *hourlyrad;
  double *prec;
  double *tmax;
  double *tmin;
  double *tair;
  double *tskc;
  double *vp;
  double  min, max;
  double  rainonly;
  int     Ndays;
  int     stepspday;
  double  sum;
  double **forcing_data;
  int     type;

  /* compute number of simulation days */
  Ndays = ( global_param.nrecs * global_param.dt) / 24;

  /* compute number of full model time steps per day */
  stepspday = 24/global_param.dt;
  
  if ( !param_set.TYPE[PREC].SUPPLIED
    && ( ( !param_set.TYPE[RAINF].SUPPLIED && ( !param_set.TYPE[LSRAINF].SUPPLIED || !param_set.TYPE[CRAINF].SUPPLIED ) )
      || ( ( !param_set.TYPE[SNOWF].SUPPLIED && ( !param_set.TYPE[LSSNOWF].SUPPLIED || !param_set.TYPE[CSNOWF].SUPPLIED ) ) ) ) )
    nrerror("Precipitation (PREC, or { {RAINF or {LSRAINF and CRAINF}} and {SNOWF or {LSSNOWF and CSNOWF}} }) must be given to the model, check input files\n");
  
  if ((!param_set.TYPE[TMAX].SUPPLIED || !param_set.TYPE[TMIN].SUPPLIED) && !param_set.TYPE[AIR_TEMP].SUPPLIED )
    nrerror("Daily maximum and minimum air temperature or sub-daily air temperature must be given to the model, check input files\n");
  
  if ( param_set.TYPE[AIR_TEMP].SUPPLIED && param_set.FORCE_DT[param_set.TYPE[AIR_TEMP].SUPPLIED-1] == 24 )
    nrerror("Model cannot use daily average temperature, must provide daily maximum and minimum or sub-daily temperatures.");
  
  if ( param_set.TYPE[SHORTWAVE].SUPPLIED
        && !(param_set.TYPE[VP].SUPPLIED || param_set.TYPE[QAIR].SUPPLIED || param_set.TYPE[REL_HUMID].SUPPLIED) )
    nrerror("Sub-daily shortwave and vapor pressure forcing data must be supplied together.");
  
  /* mtclim routine memory allocations */

  hourlyrad  = (double *) calloc(Ndays*24, sizeof(double));
  prec       = (double *) calloc(Ndays*24, sizeof(double));
  tair       = (double *) calloc(Ndays*24, sizeof(double));
  tmax       = (double *) calloc(Ndays, sizeof(double));
  tmaxhour   = (int *)    calloc(Ndays, sizeof(double));
  tmin       = (double *) calloc(Ndays, sizeof(double));
  tminhour   = (int *)    calloc(Ndays, sizeof(double));
  tskc       = (double *) calloc(Ndays*24, sizeof(double));
  vp         = (double *) calloc(Ndays*24, sizeof(double));
  
  if (hourlyrad == NULL || prec == NULL || tair == NULL || tmax == NULL ||
      tmaxhour == NULL ||  tmin == NULL || tminhour == NULL || tskc == NULL ||
      vp == NULL)
    nrerror("Memory allocation failure in initialize_atmos()");
  
  /*******************************
    read in meteorological data 
  *******************************/

  forcing_data = read_forcing_data(infile, global_param);
 
  fprintf(stderr,"\nRead meteorological forcing file\n");
  
  /*************************************************
    Pre-processing
  *************************************************/

  /*************************************************
    Convert units from ALMA to VIC standard, if necessary
  *************************************************/
  if (options.ALMA_INPUT) {
    for (type=0; type<N_FORCING_TYPES; type++) {
      if (param_set.TYPE[type].SUPPLIED) {
        /* Convert moisture flux rates to accumulated moisture flux per time step */
        if (   type == PREC
            || type == RAINF
            || type == CRAINF
            || type == LSRAINF
            || type == SNOWF
            || type == CSNOWF
            || type == LSSNOWF
           ) {
          for (idx=0; idx<(global_param.nrecs*NF); idx++) {
            forcing_data[type][idx] *= global_param.dt * 3600;
          }
        }
        /* Convert temperatures from K to C */
        else if (   type == AIR_TEMP
                 || type == TMIN
                 || type == TMAX
                ) {
          for (idx=0; idx<(global_param.nrecs*NF); idx++) {
            forcing_data[type][idx] -= KELVIN;
          }
        }
        /* Convert pressures from Pa to kPa */
        else if (   type == PRESSURE
                 || type == VP
                ) {
          for (idx=0; idx<(global_param.nrecs*NF); idx++) {
            forcing_data[type][idx] /= 1000.;
          }
        }
      }
    }
  }

  /*************************************************
    Precipitation
  *************************************************/

  /*************************************************
    If provided, translate rainfall and snowfall
    into total precipitation
    NOTE: this overwrites any PREC data that was supplied
  *************************************************/

  if(param_set.TYPE[RAINF].SUPPLIED && param_set.TYPE[SNOWF].SUPPLIED) {
    /* rainfall and snowfall supplied */
    if (forcing_data[PREC] == NULL) {
      forcing_data[PREC] = (double *)calloc((global_param.nrecs * NF),sizeof(double));
    }
    for (idx=0; idx<(global_param.nrecs*NF); idx++) {
      forcing_data[PREC][idx] = forcing_data[RAINF][idx] + forcing_data[SNOWF][idx];
    }
    param_set.TYPE[PREC].SUPPLIED = param_set.TYPE[RAINF].SUPPLIED;
  }
  else if(param_set.TYPE[CRAINF].SUPPLIED && param_set.TYPE[LSRAINF].SUPPLIED
    && param_set.TYPE[CSNOWF].SUPPLIED && param_set.TYPE[LSSNOWF].SUPPLIED) {
    /* convective and large-scale rainfall and snowfall supplied */
    if (forcing_data[PREC] == NULL) {
      forcing_data[PREC] = (double *)calloc((global_param.nrecs * NF),sizeof(double));
    }
    for (idx=0; idx<(global_param.nrecs*NF); idx++) {
      forcing_data[PREC][idx] = forcing_data[CRAINF][idx] + forcing_data[LSRAINF][idx]
                               + forcing_data[CSNOWF][idx] + forcing_data[LSSNOWF][idx];
    }
    param_set.TYPE[PREC].SUPPLIED = param_set.TYPE[LSRAINF].SUPPLIED;
  }

  /*************************************************
    Create sub-daily precipitation if not provided
  *************************************************/

  if(param_set.FORCE_DT[param_set.TYPE[PREC].SUPPLIED-1] == 24) {
    /* daily prec provided */
    rec = 0;
    for (day = 0; day < Ndays; day++) {
      for (i = 0; i < stepspday; i++) {
	sum = 0;
	for (j = 0; j < NF; j++) {
	  atmos[rec].prec[j] = forcing_data[PREC][day] 
	    / (float)(NF * stepspday);
	  sum += atmos[rec].prec[j];
	}
	if(NF>1) atmos[rec].prec[NR] = sum;
	if(global_param.dt == 24) atmos[rec].prec[NR] = forcing_data[PREC][day];
	rec++;
      }
    }
  }
  else {
    /* sub-daily prec provided */
    idx = 0;
    for(rec = 0; rec < global_param.nrecs; rec++) {
      sum = 0;
      for(i = 0; i < NF; i++) {
	atmos[rec].prec[i] = forcing_data[PREC][idx];
	sum += atmos[rec].prec[i];
	idx++;
      }
      if(NF>1) atmos[rec].prec[NR] = sum;
    }
  }

  /*************************************************
    Air Temperature
  *************************************************/

  /************************************************
    Set maximum daily air temperature if provided 
  ************************************************/

  if(param_set.TYPE[TMAX].SUPPLIED) {
    if(param_set.FORCE_DT[param_set.TYPE[TMAX].SUPPLIED-1] == 24) {
      /* daily tmax provided */
      for (day = 0; day < Ndays; day++) {
	tmax[day] = forcing_data[TMAX][day];
      }
    }
    else {
      /* sub-daily tmax provided */
      idx = 0;
      for(rec = 0; rec < global_param.nrecs; rec++) {
	tmax[rec/stepspday] = forcing_data[TMAX][idx];
	for(i = 0; i < NF; i++) idx++;
      }
    }
  }

  /************************************************
    Set minimum daily air temperature if provided 
  ************************************************/

  if(param_set.TYPE[TMIN].SUPPLIED) {
    if(param_set.FORCE_DT[param_set.TYPE[TMIN].SUPPLIED-1] == 24) {
      /* daily tmin provided */
      for (day = 0; day < Ndays; day++) {
	tmin[day] = forcing_data[TMIN][day];
      }
    }
    else {
      /* sub-daily tmin provided */
      idx = 0;
      for(rec = 0; rec < global_param.nrecs; rec++) {
	tmin[rec/stepspday] = forcing_data[TMIN][idx];
	for(i = 0; i < NF; i++) idx++;
      }
    }
  }

  /*************************************************
    Store sub-daily air temperature if provided
  *************************************************/

  if(param_set.TYPE[AIR_TEMP].SUPPLIED) {
    /* forcing data defined as equal to or less than SNOW_STEP */
    idx = 0;
    for (rec = 0; rec < global_param.nrecs; rec++) {
      sum = 0;
      for (i = 0; i < NF; i++, step++) {
	atmos[rec].air_temp[i] = forcing_data[AIR_TEMP][idx];
	sum += atmos[rec].air_temp[i];
	idx++;
      }
      if(NF > 1) atmos[rec].air_temp[NR] = sum / (float)NF;
    }
  }

  /******************************************************
    Determine Tmax and Tmin from sub-daily temperatures
  ******************************************************/

  if(!(param_set.TYPE[TMAX].SUPPLIED && param_set.TYPE[TMIN].SUPPLIED)) {
    rec = 0;
    while(rec < global_param.nrecs) {
      min = max = atmos[rec].air_temp[0];
      for (j = 0; j < stepspday; j++) {
	for (i = 0; i < NF; i++, step++) {
	  if ( atmos[rec].air_temp[i] > max ) max = atmos[rec].air_temp[i];
	  if ( atmos[rec].air_temp[i] < min ) min = atmos[rec].air_temp[i];
	}
	rec++;
      }
      tmax[(rec-1)/stepspday] = max;
      tmin[(rec-1)/stepspday] = min;
    }
  }


  /*************************************************
    Pressures
  *************************************************/

  /*************************************************
    If provided, translate specific humidity and atm. pressure
    into vapor pressure
    NOTE: this overwrites any VP data that was supplied
  *************************************************/

  if(param_set.TYPE[QAIR].SUPPLIED && param_set.TYPE[PRESSURE].SUPPLIED) {
    /* specific humidity and atm. pressure supplied */
    if (forcing_data[VP] == NULL) {
      forcing_data[VP] = (double *)calloc((global_param.nrecs * NF),sizeof(double));
    }
    for (idx=0; idx<(global_param.nrecs*NF); idx++) {
      forcing_data[VP][idx] = forcing_data[QAIR][idx] * forcing_data[PRESSURE][idx] / 0.622;
    }
    param_set.TYPE[VP].SUPPLIED = param_set.TYPE[QAIR].SUPPLIED;
  }

  /*************************************************
    If provided, translate relative humidity and atm. pressure
    into vapor pressure
    NOTE: this overwrites any VP data that was supplied
  *************************************************/

  if(param_set.TYPE[REL_HUMID].SUPPLIED && param_set.TYPE[PRESSURE].SUPPLIED) {
    /* relative humidity and atm. pressure supplied */
    if (forcing_data[VP] == NULL) {
      forcing_data[VP] = (double *)calloc((global_param.nrecs * NF),sizeof(double));
    }
    for (idx=0; idx<(global_param.nrecs*NF); idx++) {
      forcing_data[VP][idx] = forcing_data[REL_HUMID][idx] * svp(forcing_data[AIR_TEMP][idx]) / 100.;
    }
    param_set.TYPE[VP].SUPPLIED = param_set.TYPE[REL_HUMID].SUPPLIED;
  }


  /*************************************************
    Shortwave, vp, air temp, pressure, and density
  *************************************************/

  /**************************************************
    use the mtclim code to get the hourly shortwave 
    and the daily dew point temperature 

    requires prec, tmax, and tmin
  **************************************************/
  if(!(param_set.TYPE[VP].SUPPLIED && param_set.TYPE[SHORTWAVE].SUPPLIED)) {
    /** do not use mtclim estimates if vapor pressure and shortwave
	radiation are supplied **/
    for (i = 0; i < Ndays; i++)
      prec[i] = 0;
    for (rec = 0; rec < global_param.nrecs; rec++) {
      prec[rec/stepspday] += atmos[rec].prec[NR];
    }
    mtclim42_wrapper(0, 0, (theta_l-theta_s)*24./360., elevation, annual_prec,
		     phi, &global_param, dmy, prec, tmax, tmin, tskc, vp,
		     hourlyrad);
  }

  /***********************************************************
    reaggregate the hourly shortwave to the larger timesteps 
  ***********************************************************/

  if(!param_set.TYPE[SHORTWAVE].SUPPLIED) {
    for (rec = 0, hour = 0; rec < global_param.nrecs; rec++) {
      for (i = 0; i < NF; i++) {
	atmos[rec].shortwave[i] = 0;
	for (j = 0; j < options.SNOW_STEP; j++, hour++) {
	  atmos[rec].shortwave[i] += hourlyrad[hour];
	}
	atmos[rec].shortwave[i] /= options.SNOW_STEP;
      }
      if (NF > 1) {
	atmos[rec].shortwave[NR] = 0;
	for (i = 0; i < NF; i++) {
	  atmos[rec].shortwave[NR] += atmos[rec].shortwave[i];
	}
	atmos[rec].shortwave[NR] /= NF;
      }
    }
  }
  else {
    /* sub-daily shortwave provided, so it will be used instead
       of the mtclim estimates */
    idx = 0;
    for (rec = 0, hour = 0; rec < global_param.nrecs; rec++) {
      sum = 0;
      for (i = 0; i < NF; i++, step++) {
	atmos[rec].shortwave[i] = ( forcing_data[SHORTWAVE][idx] < 0 ) ? 0 : forcing_data[SHORTWAVE][idx];
	sum += atmos[rec].shortwave[i];
	idx++;
      }
      if (NF > 1) atmos[rec].shortwave[NR] = sum / (float)NF;
    }
  }

  /**************************************************************************
    Calculate the hours at which the minimum and maximum temperatures occur
  **************************************************************************/
  if(!param_set.TYPE[AIR_TEMP].SUPPLIED) {
    set_max_min_hour(hourlyrad, Ndays, tmaxhour, tminhour);

  /**********************************************************************
    Calculate the subdaily and daily temperature based on tmax and tmin 
  **********************************************************************/

    HourlyT(options.SNOW_STEP, Ndays, tmaxhour, tmax, tminhour, tmin, tair);
    for (rec = 0, step = 0; rec < global_param.nrecs; rec++) {
      for (i = 0; i < NF; i++, step++) {
	atmos[rec].air_temp[i] = tair[step];
      }
      if (NF > 1) {
	atmos[rec].air_temp[NR] = 0;
	for (i = 0; i < NF; i++) {
	  atmos[rec].air_temp[NR] += atmos[rec].air_temp[i];
	}
	atmos[rec].air_temp[NR] /= NF;
      }
    }
  }

  /**************************************************
    calculate the subdaily and daily vapor pressure 
    and vapor pressure deficit
  **************************************************/

  if(!param_set.TYPE[VP].SUPPLIED) {
    for (rec = 0; rec < global_param.nrecs; rec++) {
      atmos[rec].vp[NR] = vp[rec/stepspday];
      atmos[rec].vpd[NR] = svp(atmos[rec].air_temp[NR]) - atmos[rec].vp[NR];

      if(atmos[rec].vpd[NR]<0) {
	atmos[rec].vpd[NR]=0;
	atmos[rec].vp[NR]=svp(atmos[rec].air_temp[NR]);
      }
      
      for (i = 0; i < NF; i++) {
	atmos[rec].vp[i]  = atmos[rec].vp[NR];
	atmos[rec].vpd[i]  = (svp(atmos[rec].air_temp[i]) - atmos[rec].vp[i]);

	if(atmos[rec].vpd[i]<0) {
	  atmos[rec].vpd[i]=0;
	  atmos[rec].vp[i]=svp(atmos[rec].air_temp[i]);
	}
      
      }
    }
  }
  else {
    if(param_set.FORCE_DT[param_set.TYPE[VP].SUPPLIED-1] == 24) {
      /* daily vp provided */
      rec = 0;
      for (day = 0; day < Ndays; day++) {
	for (i = 0; i < stepspday; i++) {
	  sum = 0;
	  for (j = 0; j < NF; j++) {
	    atmos[rec].vp[j] = forcing_data[VP][day];
	    atmos[rec].vpd[j] = (svp(atmos[rec].air_temp[j]) 
				 - atmos[rec].vp[j]);
	    sum += atmos[rec].vp[j];
	  }
	  if(NF > 1) {
	    atmos[rec].vp[NR] = sum / (float)NF;
	    atmos[rec].vpd[NR] = (svp(atmos[rec].air_temp[NR]) 
				  - atmos[rec].vp[NR]);
	    rec++;
	  }
	}
      }
    }
    else {
      /* sub-daily vp provided */
      idx = 0;
      for(rec = 0; rec < global_param.nrecs; rec++) {
	sum = 0;
	for(i = 0; i < NF; i++) {
	  atmos[rec].vp[i] = forcing_data[VP][idx];


	  atmos[rec].vp[i] = ((float)(int)(atmos[rec].vp[i]*1000 + 0.5)/1000);


	  atmos[rec].vpd[i] = (svp(atmos[rec].air_temp[i]) 
			       - atmos[rec].vp[i]);
	  sum += atmos[rec].vp[i];
	  idx++;
	}
	if(NF > 1) {
	  atmos[rec].vp[NR] = sum / (float)NF;
	  atmos[rec].vpd[NR] = (svp(atmos[rec].air_temp[NR]) 
				    - atmos[rec].vp[NR]);
	}
      }
    }
  }

  /*************************************************
    Longwave
  *************************************************/

  /****************************************************************************
    calculate the daily and sub-daily longwave.  There is a separate case for
    the full energy and the water balance modes.  For water balance mode we 
    need to calculate the net longwave for the daily timestep and the incoming
    longwave for the SNOW_STEPs, for the full energy balance mode we always
    want the incoming longwave. 
  ****************************************************************************/

  if ( !param_set.TYPE[LONGWAVE].SUPPLIED ) {
    /** Incoming longwave radiation not supplied **/
    for (rec = 0; rec < global_param.nrecs; rec++) {
      if( NF > 1 ) {
	for (i = 0; i < NF; i++) {
	  calc_longwave(&(atmos[rec].longwave[i]), tskc[rec/stepspday],
			atmos[rec].air_temp[i], atmos[rec].vp[i]);
	}
	calc_netlongwave(&(atmos[rec].longwave[NR]), tskc[rec/stepspday],
			 atmos[rec].air_temp[NR], atmos[rec].vp[NR]);
      }
      else {
	calc_longwave(&(atmos[rec].longwave[NR]), tskc[rec/stepspday],
		      atmos[rec].air_temp[NR], atmos[rec].vp[NR]);
      }
    }
  }
  else if(param_set.FORCE_DT[param_set.TYPE[LONGWAVE].SUPPLIED-1] == 24) {
    /* daily incoming longwave radiation provided */
    rec = 0;
    for (day = 0; day < Ndays; day++) {
      for (i = 0; i < stepspday; i++) {
	sum = 0;
	for (j = 0; j < NF; j++) {
	  atmos[rec].longwave[j] = forcing_data[LONGWAVE][day];
	  sum += atmos[rec].longwave[j];
	}
	if(NF>1) atmos[rec].longwave[NR] = sum / (float)NF - STEFAN_B 
		   * atmos[rec].air_temp[NR] * atmos[rec].air_temp[NR] 
		   * atmos[rec].air_temp[NR] * atmos[rec].air_temp[NR];
	rec++;
      }
    }
  }
  else {
    /* sub-daily incoming longwave radiation provided */
    idx = 0;
    for(rec = 0; rec < global_param.nrecs; rec++) {
      sum = 0;
      for(i = 0; i < NF; i++) {
	atmos[rec].longwave[i] = forcing_data[LONGWAVE][idx];
	sum += atmos[rec].longwave[i];
	idx++;
      }
      if(NF>1) atmos[rec].longwave[NR] = sum / (float)NF - STEFAN_B 
		 * atmos[rec].air_temp[NR] * atmos[rec].air_temp[NR] 
		 * atmos[rec].air_temp[NR] * atmos[rec].air_temp[NR];
    }
  }

  /*************************************************
    Wind Speed
  *************************************************/

  /*************************************************
    If provided, translate WIND_E and WIND_N into WIND
    NOTE: this overwrites any WIND data that was supplied
  *************************************************/

  if(param_set.TYPE[WIND_E].SUPPLIED && param_set.TYPE[WIND_N].SUPPLIED) {
    /* specific humidity and atm. pressure supplied */
    if (forcing_data[WIND] == NULL) {
      forcing_data[WIND] = (double *)calloc((global_param.nrecs * NF),sizeof(double));
    }
    for (idx=0; idx<(global_param.nrecs*NF); idx++) {
      forcing_data[WIND][idx] = sqrt( forcing_data[WIND_E][idx]*forcing_data[WIND_E][idx]
                                    + forcing_data[WIND_N][idx]*forcing_data[WIND_N][idx] );
    }
    param_set.TYPE[WIND].SUPPLIED = param_set.TYPE[WIND_E].SUPPLIED;
  }

  /********************
    set the windspeed 
  ********************/

  if (param_set.TYPE[WIND].SUPPLIED) {
    if(param_set.FORCE_DT[param_set.TYPE[WIND].SUPPLIED-1] == 24) {
      /* daily wind provided */
      rec = 0;
      for (day = 0; day < Ndays; day++) {
	for (i = 0; i < stepspday; i++) {
	  sum = 0;
	  for (j = 0; j < NF; j++) {
	    if(forcing_data[WIND][day] < options.MIN_WIND_SPEED)
	      atmos[rec].wind[j] = options.MIN_WIND_SPEED;
	    else 
	      atmos[rec].wind[j] = forcing_data[WIND][day];
	    sum += atmos[rec].wind[j];
	  }
	  if(NF>1) atmos[rec].wind[NR] = sum / (float)NF;
	  if(global_param.dt == 24) {
	    if(forcing_data[WIND][day] < options.MIN_WIND_SPEED)
	      atmos[rec].wind[j] = options.MIN_WIND_SPEED;
	    else 
	      atmos[rec].wind[NR] = forcing_data[WIND][day];
	  }
	  rec++;
	}
      }
    }
    else {
      /* sub-daily wind speed provided */
      idx = 0;
      for(rec = 0; rec < global_param.nrecs; rec++) {
	sum = 0;
	for(i = 0; i < NF; i++) {
	  if(forcing_data[WIND][idx] <options.MIN_WIND_SPEED)
	    atmos[rec].wind[i] = options.MIN_WIND_SPEED;
	  else
	    atmos[rec].wind[i] = forcing_data[WIND][idx];
	  sum += atmos[rec].wind[i];
	  idx++;
	}
	if(NF>1) atmos[rec].wind[NR] = sum / (float)NF;
      }
    }
  }
  else {
    /* no wind data provided, use default constant */
    for (rec = 0; rec < global_param.nrecs; rec++) {
      for (i = 0; i < NF; i++) {
	atmos[rec].wind[i] = 1.5;
      }
      atmos[rec].wind[NR] = 1.5;	
    }
  }

  /*************************************************
    Store atmospheric density if provided (kg/m^3)
  *************************************************/

  if(param_set.TYPE[DENSITY].SUPPLIED) {
    if(param_set.FORCE_DT[param_set.TYPE[DENSITY].SUPPLIED-1] == 24) {
      /* daily density provided */
      rec = 0;
      for (day = 0; day < Ndays; day++) {
	for (i = 0; i < stepspday; i++) {
	  sum = 0;
	  for (j = 0; j < NF; j++) {
	    atmos[rec].density[j] = forcing_data[DENSITY][day];
	    sum += atmos[rec].density[j];
	  }
	  if(NF>1) atmos[rec].density[NR] = sum / (float)NF;
	  rec++;
	}
      }
    }
    else {
      /* sub-daily density provided */
      idx = 0;
      for(rec = 0; rec < global_param.nrecs; rec++) {
	sum = 0;
	for(i = 0; i < NF; i++) {
	  atmos[rec].density[i] = forcing_data[DENSITY][idx];
	  sum += atmos[rec].density[i];
	  idx++;
	}
	if(NF>1) atmos[rec].density[NR] = sum / (float)NF;
      }
    }
  }

  /**************************************
    Estimate Atmospheric Pressure (kPa) 
  **************************************/

  if(!param_set.TYPE[PRESSURE].SUPPLIED) {
    if(!param_set.TYPE[DENSITY].SUPPLIED) {
      /* Estimate pressure */
      for (rec = 0; rec < global_param.nrecs; rec++) {
        /* Assume average virtual temperature in air column
           between ground and sea level = KELVIN+atmos[rec].air_temp[NR] + 0.5*elevation*LAPSE_PM */
        atmos[rec].pressure[NR] = PS_PM*exp(-elevation*G/(Rd*(KELVIN+atmos[rec].air_temp[NR]+0.5*elevation*LAPSE_PM)))/1000;
        for (i = 0; i < NF; i++) {
          atmos[rec].pressure[i] = PS_PM*exp(-elevation*G/(Rd*(KELVIN+atmos[rec].air_temp[i]+0.5*elevation*LAPSE_PM)))/1000;
        }
      }
    }
    else {
      /* use observed densities to estimate pressure */
      for (rec = 0; rec < global_param.nrecs; rec++) {
        atmos[rec].pressure[NR] = (KELVIN+atmos[rec].air_temp[NR])*atmos[rec].density[NR]*Rd/1000;
        for (i = 0; i < NF; i++) {
          atmos[rec].pressure[i] = (KELVIN+atmos[rec].air_temp[i])*atmos[rec].density[i]*Rd/1000;
        }
      }
    }
  }
  else {
    /* observed atmospheric pressure supplied */
    if(param_set.FORCE_DT[param_set.TYPE[PRESSURE].SUPPLIED-1] == 24) {
      /* daily pressure provided */
      rec = 0;
      for (day = 0; day < Ndays; day++) {
	for (i = 0; i < stepspday; i++) {
	  sum = 0;
	  for (j = 0; j < NF; j++) {
	    atmos[rec].pressure[j] = forcing_data[PRESSURE][day];
	    sum += atmos[rec].pressure[j];
	  }
	  if(NF>1) atmos[rec].pressure[NR] = sum / (float)NF;
	  rec++;
	}
      }
    }
    else {
      /* sub-daily pressure provided */
      idx = 0;
      for(rec = 0; rec < global_param.nrecs; rec++) {
	sum = 0;
	for(i = 0; i < NF; i++) {
	  atmos[rec].pressure[i] = forcing_data[PRESSURE][idx];
	  sum += atmos[rec].pressure[i];
	  idx++;
	}
	if(NF>1) atmos[rec].pressure[NR] = sum / (float)NF;
      }
    }
  }

  /********************************************************
    Estimate Atmospheric Density if not provided (kg/m^3)
  ********************************************************/

  if(!param_set.TYPE[DENSITY].SUPPLIED) {
    /* use pressure to estimate density */
    for (rec = 0; rec < global_param.nrecs; rec++) {
      atmos[rec].density[NR] = 1000*atmos[rec].pressure[NR]/(Rd*(KELVIN+atmos[rec].air_temp[NR]));
      for (i = 0; i < NF; i++) {
        atmos[rec].density[i] = 1000*atmos[rec].pressure[i]/(Rd*(KELVIN+atmos[rec].air_temp[i]));
      }
    }
  }

  /****************************************************
    Determine if Snow will Fall During Each Time Step
  ****************************************************/

#if !OUTPUT_FORCE
  min_Tfactor = Tfactor[0];
  for (band = 1; band < options.SNOW_BAND; band++) {
    if (Tfactor[band] < min_Tfactor)
      min_Tfactor = Tfactor[band];
  }
  for (rec = 0; rec < global_param.nrecs; rec++) {
    atmos[rec].snowflag[NR] = FALSE;
    for (i = 0; i < NF; i++) {
      if ((atmos[rec].air_temp[i] + min_Tfactor) < global_param.MAX_SNOW_TEMP
	  &&  atmos[rec].prec[i] > 0) {
	atmos[rec].snowflag[i] = TRUE;
	atmos[rec].snowflag[NR] = TRUE;
      }
      else
	atmos[rec].snowflag[i] = FALSE;
    }
  }
#endif
 
  // Free temporary parameters
  free(hourlyrad);
  free(prec);
  free(tair);
  free(tmax);
  free(tmaxhour);
  free(tmin);
  free(tminhour);
  free(tskc);
  free(vp);

  for(i=0;i<N_FORCING_TYPES;i++) 
    if (param_set.TYPE[i].SUPPLIED) 
      free((char *)forcing_data[i]);
  free((char *)forcing_data);

#if !OUTPUT_FORCE

  // If COMPUTE_TREELINE is TRUE and the treeline computation hasn't
  // specifically been turned off for this cell (by supplying avgJulyAirTemp
  // and setting it to -999), calculate which snowbands are above the
  // treeline, based on average July air temperature.
  if (options.COMPUTE_TREELINE) {
    if ( !(options.JULY_TAVG_SUPPLIED && avgJulyAirTemp == -999) ) {
      if ( options.SNOW_BAND ) {
        compute_treeline( atmos, dmy, avgJulyAirTemp, Tfactor, AboveTreeLine );
      }
    }
  }

#else

  // If OUTPUT_FORCE is set to TRUE in user_def.h then the full
  // forcing data array is dumped into a new set of files.
  write_forcing_file(atmos, global_param.nrecs, out_data_files, out_data);

#endif /* !OUTPUT_FORCE */

}
