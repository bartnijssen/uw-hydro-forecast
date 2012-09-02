#include <stdio.h>
#include <stdlib.h>
#include <vicNl.h>
#include <math.h>

static char vcid[] = "$Id: full_energy.c,v 4.2.2.5 2007/10/23 01:07:46 vicadmin Exp $";

void full_energy(int                  rec,
                 atmos_data_struct   *atmos,
                 soil_con_struct     *soil_con,
                 veg_con_struct      *veg_con,
                 dist_prcp_struct    *prcp,
                 dmy_struct          *dmy,
                 global_param_struct *gp,
                 int                  gridcell,
                 char                 NEWCELL)
/**********************************************************************
	full_energy	Keith Cherkauer		January 8, 1997

  This subroutine controls the model core, it solves both the energy
  and water balance models, as well as frozen soils.  

  modifications:
  07-98 restructured to fix problems with distributed precipitation, 
        and to add the ability to solve the snow model at different 
	elevation bands within a single grid cell.                 KAC
  01-19-00 modified to work with the new atmosphere data structure 
           implemented when the radiation forcing routines were 
	   updated.  Also modified to use the new simplified 
	   soil moisture storage for the frozen soil algorithm.    KAC
  28-Sep-04 Added aero_resist_used to store the aerodynamic resistance
	    actually used in flux calculations.				TJB
  2006-Sep-14 Added computation of soil wetness and root zone soil
	      moisture, as part of ALMA-compliant input/output.		TJB
  2007-Oct-22 Changed ice0 from a scalar to an array.  Previously,
	      when options.SNOW_BAND > 1, the value of ice0 computed
	      for earlier bands was always overwritten by the value
	      of ice0 computed for the final band (even if the final
	      band had 0 area).						JS via TJB

**********************************************************************/
{
  extern veg_lib_struct *veg_lib;
  extern option_struct   options;
#if LINK_DEBUG
  extern debug_struct    debug;
#endif

  char                   overstory;
  char                   SOLVE_SURF_ENERGY;
  int                    i, j, k;
  int                    lidx;
  int                    Ndist;
  int                    dist;
  int                    iveg;
  int                    Nveg;
  int                    veg_class;
  int                    band;
  int                    Nbands;
  int                    hour;
  double                 out_prec[2*MAX_BANDS];
  double                 out_rain[2*MAX_BANDS];
  double                 out_snow[2*MAX_BANDS];
  double                 tmp_surf_temp;
  double                 last_T1;
  double                 out_short=0;
  double                 inshort;
  double                 inlong;
  double                 dp;
  double                 ice0[MAX_BANDS];
  double                 moist;
  double                 surf_atten;
  double                 Tsurf;
  double                 Tgrnd;
  double                 Tend_surf;
  double                 Tend_grnd;
  double                 rainfall[2]; 
  double                 wind_h;
  double                 height;
  double                 displacement;
  double                 roughness;
  double                 ref_height;
  double                 Cv;
  double                 Le;
  double                 Ls;
  double                 Evap;
  double                 Melt[2*MAX_BANDS];
  double                 bare_albedo;
  double                 snow_inflow[MAX_BANDS];
  double                 step_rad;
  double                 step_net_short;
  double                 tmp_aero_resist;
  double                 tmp_throughfall[2][MAX_BANDS];
  double                 tmp_wind[3];
  double                 tmp_melt[MAX_BANDS*2];
  double                 tmp_vapor_flux[MAX_BANDS];
  double                 tmp_canopy_vapor_flux[MAX_BANDS];
  double                 tmp_canopyevap[2][MAX_BANDS];
  double                 tmp_snow_energy;
  double                 tmp_Wdew[2];
  double                 tmp_mu;
  double                 tmp_layerevap[2][MAX_BANDS][MAX_LAYERS];
  double                 tmp_Tmin;
  double                 tmp_total_moist_wet;
  double                 tmp_total_moist_dry;
  double                 gauge_correction[2];
  layer_data_struct     *tmp_layer[2];
  veg_var_struct         tmp_veg_var[2];
  cell_data_struct    ***cell;
  veg_var_struct      ***veg_var;
  energy_bal_struct    **energy;
  energy_bal_struct     *ptr_energy;
  snow_data_struct     **snow;
  snow_data_struct      *tmp_snow;
  veg_var_struct        *tmp_veg[2];
  veg_var_struct        *wet_veg_var;
  veg_var_struct        *dry_veg_var;
  veg_var_struct         empty_veg_var;

  /* set local pointers */
  cell    = prcp->cell;
  veg_var = prcp->veg_var;
  snow    = prcp->snow;
  energy  = prcp->energy;

  /* set variables for distributed precipitation */
  if(options.DIST_PRCP) 
    Ndist = 2;
  else 
    Ndist = 1;
  Nbands = options.SNOW_BAND;

  /* Set number of vegetation types */
  Nveg      = veg_con[0].vegetat_type_num;

  /** Set Damping Depth **/
  dp        = soil_con->dp;

  /* allocate memory for temporary storage structures */
  if(options.FULL_ENERGY || options.FROZEN_SOIL) {
    for(i=0; i<2; i++) {
      tmp_layer[i] = (layer_data_struct *)calloc((options.Nlayer),
						 sizeof(layer_data_struct));
    }
  }
      
  /* Compute gauge undercatch correction factors 
     - this assumes that the gauge is free of vegetation effects, so gauge
     correction is constant for the entire grid cell */
  if( options.CORRPREC && atmos->prec[NR] > 0 ) 
    correct_precip(gauge_correction, atmos->wind[NR], gp->wind_h, 
		   soil_con->rough, soil_con->snow_rough);
  else {
    gauge_correction[0] = 1;
    gauge_correction[1] = 1;
  }
  atmos->out_prec = 0;
  atmos->out_rain = 0;
  atmos->out_snow = 0;

  /**************************************************
    Solve Energy and/or Water Balance for Each
    Vegetation Type
  **************************************************/
  for(iveg = 0; iveg <= Nveg; iveg++){

    /** Solve Veg Type only if Coverage Greater than 0% **/
    if ((iveg <  Nveg && veg_con[iveg].Cv  > 0.) || 
	(iveg == Nveg && veg_con[0].Cv_sum < 1.)) {

      if ( iveg < Nveg ) Cv = veg_con[iveg].Cv;
      else Cv = 1. - veg_con[0].Cv_sum;

      /**************************************************
        Initialize Model Parameters
      **************************************************/

      /* Initialize energy balance variables */
      for(band = 0; band < Nbands; band++) {
	if(soil_con->AreaFract[band] > 0) {
	  energy[iveg][band].shortwave = 0;
	  energy[iveg][band].longwave  = 0.;
	}
      }

      /* Initialize snow variables */
      for(band=0; band<Nbands; band++) {
	if(soil_con->AreaFract[band] > 0) {
	  snow[iveg][band].vapor_flux        = 0.;
	  snow[iveg][band].canopy_vapor_flux = 0.;
	  snow_inflow[band]                  = 0.;
	  Melt[band*2]                       = 0.;
	}
      }

      /* Initialize precipitation storage */
      for ( j = 0; j < 2*MAX_BANDS; j++ ) {
        out_prec[j] = 0;
        out_rain[j] = 0;
        out_snow[j] = 0;
      }
    
      /** Define vegetation class number **/
      if (iveg < Nveg) 
	veg_class = veg_con[iveg].veg_class;
      else 
	veg_class = 0;
      if ( iveg < Nveg ) wind_h = veg_lib[veg_class].wind_h;
      else wind_h = gp->wind_h;

      /** Compute Surface Attenuation due to Vegetation Coverage **/
      if(iveg < Nveg)
	surf_atten = exp(-veg_lib[veg_class].rad_atten 
			 * veg_lib[veg_class].LAI[dmy[rec].month-1]);
      else 
	surf_atten = 1.;
        
      /* Initialize soil thermal properties for the top two layers */
      if(options.FULL_ENERGY || options.FROZEN_SOIL) {
	prepare_full_energy(iveg, Nveg, options.Nnode, prcp, 
			    soil_con, &moist, ice0);
      }

      /** Compute Bare Soil (free of snow) Albedo **/
      if(iveg != Nveg) 
	bare_albedo = veg_lib[veg_class].albedo[dmy[rec].month-1];
      else 
	bare_albedo = BARE_SOIL_ALBEDO;
      
      /*************************************
	Compute the aerodynamic resistance 
      *************************************/

      /* Set surface descriptive variables */
      overstory = FALSE;
      if(iveg < Nveg) {
        displacement = veg_lib[veg_class].displacement[dmy[rec].month-1];
        roughness = veg_lib[veg_class].roughness[dmy[rec].month-1];
        overstory = veg_lib[veg_class].overstory;
      }
      if(iveg == Nveg || roughness == 0) {
        displacement = 0.;
        roughness = soil_con->rough;
        overstory = FALSE;
      }

      /* Initialize wind speeds */
      tmp_wind[0] = atmos->wind[NR];
      tmp_wind[1] = -999.;
      tmp_wind[2] = -999.;
 
      /* Estimate vegetation height */
      height = calc_veg_height(displacement);

      /* Estimate reference height */
      if(displacement < wind_h) 
	ref_height = wind_h;
      else 
	ref_height = displacement + wind_h + roughness;

      /* Compute aerodynamic resistance over various surface types */
      CalcAerodynamic(overstory, iveg, Nveg, veg_lib[veg_class].wind_atten,
                      height, soil_con->rough, soil_con->snow_rough,
                      &displacement, &roughness, &ref_height,
		      veg_lib[veg_class].trunk_ratio,
                      tmp_wind, cell[WET][iveg][0].aero_resist);
  
      /**************************************************
        Store Water Balance Terms for Debugging
      **************************************************/

#if LINK_DEBUG
      if(debug.DEBUG || debug.PRT_MOIST || debug.PRT_BALANCE) {
        /** Compute current total moisture for water balance check **/
	store_moisture_for_debug(iveg, Nveg, prcp->mu, cell,
				 veg_var, snow, soil_con);
	if(debug.PRT_BALANCE) {
	  for(j=0; j<Ndist; j++) {
	    for(band=0; band<Nbands; band++) {
	      if(soil_con->AreaFract[band] > 0) {
		for(i=0; i<options.Nlayer+3; i++) {
		  debug.inflow[j][band][i]  = 0;
		  debug.outflow[j][band][i] = 0;
		}
	      }
	    }
	  }
	}
      }
#endif

      /******************************
        Solve ground surface fluxes 
      ******************************/
  
      for ( band = 0; band < Nbands; band++ ) {
	if( soil_con->AreaFract[band] > 0 ) {

	  if ( iveg < Nveg ) {
	    wet_veg_var = &(veg_var[WET][iveg][band]);
	    dry_veg_var = &(veg_var[DRY][iveg][band]);
	  }
	  else {
	    wet_veg_var = &(empty_veg_var);
	    dry_veg_var = &(empty_veg_var);
	  }

	  surface_fluxes(overstory, rec, band, veg_class, iveg, Nveg, Ndist, 
			 Nbands, options.Nlayer, dp, prcp->mu[iveg], ice0[band], 
			 moist, surf_atten, height, displacement, roughness, 
			 ref_height, bare_albedo, 
			 cell[WET][iveg][0].aero_resist, &(cell[WET][iveg][0].aero_resist_used),
			 &(cell[WET][iveg][band].baseflow), 
			 &(cell[DRY][iveg][band].baseflow), 
			 &(cell[WET][iveg][band].runoff), 
			 &(cell[DRY][iveg][band].runoff), &out_prec[band*2], 
			 &out_rain[band*2], &out_snow[band*2],
			 tmp_wind, &Le, &Ls, &(Melt[band*2]), 
			 &(cell[WET][iveg][band].inflow), 
			 &(cell[DRY][iveg][band].inflow), 
			 &snow_inflow[band], gauge_correction,
			 veg_con[iveg].root, atmos, soil_con, dmy, gp, 
			 &(energy[iveg][band]), &(snow[iveg][band]),
			 cell[WET][iveg][band].layer, 
			 cell[DRY][iveg][band].layer, 
			 wet_veg_var, dry_veg_var);
	  
	  atmos->out_prec += out_prec[band*2] * Cv * soil_con->AreaFract[band];
	  atmos->out_rain += out_rain[band*2] * Cv * soil_con->AreaFract[band];
	  atmos->out_snow += out_snow[band*2] * Cv * soil_con->AreaFract[band];

          /********************************************************
            Compute soil wetness and root zone soil moisture
          ********************************************************/
          cell[WET][iveg][band].rootmoist = 0;
          cell[DRY][iveg][band].rootmoist = 0;
          cell[WET][iveg][band].wetness = 0;
          cell[DRY][iveg][band].wetness = 0;
          for(lidx=0;lidx<options.Nlayer;lidx++) {
            tmp_total_moist_wet = cell[WET][iveg][band].layer[lidx].moist + cell[WET][iveg][band].layer[lidx].ice;
            tmp_total_moist_dry = cell[DRY][iveg][band].layer[lidx].moist + cell[DRY][iveg][band].layer[lidx].ice;
            if (veg_con->root[lidx] > 0) {
              cell[WET][iveg][band].rootmoist += tmp_total_moist_wet;
              cell[DRY][iveg][band].rootmoist += tmp_total_moist_dry;
            } 
            cell[WET][iveg][band].wetness += (tmp_total_moist_wet - soil_con->Wpwp[lidx])/(soil_con->porosity[lidx]*soil_con->depth[lidx]*1000 - soil_con->Wpwp[lidx]);
            cell[DRY][iveg][band].wetness += (tmp_total_moist_dry - soil_con->Wpwp[lidx])/(soil_con->porosity[lidx]*soil_con->depth[lidx]*1000 - soil_con->Wpwp[lidx]);
          }
          cell[WET][iveg][band].wetness /= options.Nlayer;
          cell[DRY][iveg][band].wetness /= options.Nlayer;


	} /** End Loop Through Elevation Bands **/
      } /** End Full Energy Balance Model **/
  
      /****************************
	Controls Debugging Output
      ****************************/

#if LINK_DEBUG
      for(j = 0; j < Ndist; j++) {
	if(iveg < Nveg) 
	  tmp_veg[j] = veg_var[j][iveg];
	else 
	  tmp_veg[j] = NULL;
      }
      ptr_energy = energy[iveg];
      tmp_snow   = snow[iveg];
      for(j = 0; j < Ndist; j++) {
	if(j == 0) 
	  tmp_mu = prcp->mu[iveg]; 
	else 
	  tmp_mu = 1. - prcp->mu[iveg]; 
	/** for debugging water balance: [0] = vegetation, 
	    [1] = ground snow, [2..Nlayer+1] = soil layers **/
	if(debug.PRT_BALANCE) {
	  for(band = 0; band < Nbands; band++) {
	    if(soil_con->AreaFract[band] > 0) {
	      debug.inflow[j][band][options.Nlayer+2] 
		+= out_prec[j+band*2] * soil_con->Pfactor[band];
	      debug.inflow[j][band][0]  = 0.;
	      debug.inflow[j][band][1]  = 0.;
	      debug.outflow[j][band][0] = 0.;
	      debug.outflow[j][band][1] = 0.;
	      if(iveg < Nveg) {
		/** Vegetation Present **/
		debug.inflow[j][band][0] += out_prec[j+band*2] * soil_con->Pfactor[band]; 
		debug.outflow[j][band][0] 
		  += veg_var[j][iveg][band].throughfall;
	      }
	      if(j == 0)
		debug.inflow[j][band][1] += snow_inflow[band];
	      debug.outflow[j][band][1] += Melt[band*2+j];
	    }
	  }  /** End loop through elevation bands **/
	}
         
	if(iveg != Nveg) {
	  write_debug(atmos, soil_con, cell[j][iveg], ptr_energy, 
		      tmp_snow, tmp_veg[j], &(dmy[rec]), gp, out_short, 
		      tmp_mu, Nveg, iveg, rec, gridcell, j, NEWCELL); 
	}
	else {
	  write_debug(atmos, soil_con, cell[j][iveg], ptr_energy, tmp_snow, 
		      tmp_veg[j], &(dmy[rec]), gp, out_short, tmp_mu, Nveg, 
		      iveg, rec, gridcell, j, NEWCELL); 
	}
      }
#endif

    } /** end current vegetation type **/
  } /** end of vegetation loop **/

  /** END Temperature and Moisture Profile Debugging Output **/
  if(options.FULL_ENERGY || options.FROZEN_SOIL) {
    for(j = 0; j < 2; j++) {
      free ((char *)tmp_layer[j]);
    }
  }

}

