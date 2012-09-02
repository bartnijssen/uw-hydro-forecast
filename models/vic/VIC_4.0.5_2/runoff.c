#include <stdio.h>
#include <stdlib.h>
#include <vicNl.h>
#include <math.h>

static char vcid[] = "$Id: runoff.c,v 4.1.2.6 2004/07/07 01:41:34 tbohn Exp $";

void runoff(layer_data_struct *layer_wet,
	    layer_data_struct *layer_dry,
            energy_bal_struct *energy,
            soil_con_struct   *soil_con,
            double            *runoff_wet, 
	    double            *runoff_dry, 
	    double            *baseflow_wet,
	    double            *baseflow_dry,
	    double            *ppt, 
	    double             mu,
	    int                dt,
            int                Nnodes,
	    int                band,
	    int                rec,
	    int                iveg)
/**********************************************************************
	runoff.c	Keith Cherkauer		May 18, 1996

  This subroutine calculates infiltration and runoff from the surface,
  gravity driven drainage between all soil layers, and generates 
  baseflow from the bottom layer..
  
  sublayer indecies are always [layer number][sublayer number]
  [layer number] is the current VIC model moisture layer
  [sublayer number] is the current sublayer number where: 
         0 = thawed sublayer, 1 = frozen sublayer, and 2 = unfrozen sublayer.
	 when the model is run withoputfrozen soils, the sublayer number
	 is always = 2 (unfrozen).

  UNITS:	Ksat (mm/day)
		Q12  (mm/time step)
		moist (mm)
		inflow (mm)
                runoff (mm)

  Variables:
	ppt	incoming precipitation and snow melt
	mu	fraction of area that receives precipitation
	inflow	incoming water corrected for fractional area of precip (mu)

  MODIFICATIONS:
    5/22/96	Routine modified to account for spatially varying
		precipitation, and it's effects on runoff.	KAC
    11/96		Code modified to account for extra model layers
  		needed for frozen soils modeling.		KAC
    1/9/97	Infiltration and other rate parameters modified
		for time scales of less than 1 day.		KAC
    4-1-98 Soil moisture transport is now done on an hourly time
           step, irregardless to the model time step, to prevent
           numerical stabilities in the solution	Dag and KAC
    01-24-00    simplified handling of soil moisture for the
                frozen soil algorithm.  all option selection
		now use the same soil moisture transport method   KAC
    06-Sep-03   Changed calculation of dt_baseflow to go to zero when
                soil liquid moisture <= residual moisture.  Changed
                block that handles case of total soil moisture < residual
                moisture to not allow dt_baseflow to go negative.  TJB
    17-May-04	Changed block that handles baseflow when soil moisture
		drops below residual moisture.  Now, the block is only
		entered if baseflow > 0 and soil moisture < residual,
		and the amount of water taken out of baseflow and given
		to the soil cannot exceed baseflow.  In addition, error
		messages are no longer printed, since it isn't an error
		to be in that block.				TJB

**********************************************************************/
{  
  extern option_struct options;
#if LINK_DEBUG
  extern debug_struct  debug;
#endif

  char               ErrStr[MAXSTRING];
  int                firstlayer, lindex, sub;
  int                i;
  int                last_layer[MAX_LAYERS*3];
  int                last_sub[MAX_LAYERS*3];
  int                froz_solid[MAX_LAYERS*3];
  int                last_index;
  int                last_cnt;
  int                tmp_index;
  int                time_step;
  int                Ndist;
  int                dist;
  int                storesub;
  int                tmpsub;
  int                tmplayer;
  double             ex, A, i_0, basis, frac;
  double             inflow;
  double             last_moist;
  double             resid_moist[MAX_LAYERS];
  double             moist[MAX_LAYERS];
  double             ice[MAX_LAYERS];
  double             max_moist[MAX_LAYERS];
  double             max_infil;
  double             Ksat[MAX_LAYERS];
  double             Q12[MAX_LAYERS-1];
  double            *kappa;
  double            *Cs;
  double            *M;
  double             Dsmax;
  double             top_moist;
  double             top_max_moist;
  double             tmp_inflow;
  double             tmp_moist;
  double             dt_inflow, dt_outflow;
  double             dt_runoff;
  double            *runoff;
  double            *baseflow;
  double             tmp_mu;
  double             dt_baseflow;
#if LOW_RES_MOIST
  double             b[MAX_LAYERS];
  double             matric[MAX_LAYERS];
  double             avg_matric;
#endif
  layer_data_struct *layer;
  layer_data_struct  tmp_layer;

  /** Set Residual Moisture **/
  if(soil_con->resid_moist[0] > SMALL) 
    for(i=0;i<options.Nlayer;i++) resid_moist[i] = soil_con->resid_moist[i] 
				    * soil_con->depth[i] * 1000.;
  else for(i=0;i<options.Nlayer;i++) resid_moist[i] = 0.;

  /** Initialize Other Parameters **/
  if(options.DIST_PRCP) Ndist = 2;
  else Ndist = 1;
  tmp_mu = mu;
  
  /** Allocate and Set Values for Soil Sublayers **/
  for(dist=0;dist<Ndist;dist++) {

    if(dist>0) {
      layer    = layer_dry;
      runoff   = runoff_dry;
      baseflow = baseflow_dry;
      mu       = (1. - mu);
    }
    else {
      layer    = layer_wet;
      runoff   = runoff_wet;
      baseflow = baseflow_wet;
    }
    *baseflow = 0;

    if(mu>0.) {
      
      /** ppt = amount of liquid water coming to the surface **/
      inflow = ppt[dist];
      
      /**************************************************
	Initialize Variables
      **************************************************/
      for(lindex=0;lindex<options.Nlayer;lindex++) {
	Ksat[lindex]         = soil_con->Ksat[lindex] / 24.;
#if LOW_RES_MOIST
	b[lindex]            = (soil_con->expt[lindex] - 3.) / 2.;
#endif

	/** Set Layer Unfrozen Moisture Content **/
	moist[lindex] = layer[lindex].moist - layer[lindex].ice;
	if(moist[lindex]<0) {
	  if(fabs(moist[lindex]) < 1e-6)
	    moist[lindex] = 0;
	  else if (layer[lindex].moist < layer[lindex].ice)
	    moist[lindex] = 0;
	  else {
	    sprintf(ErrStr,
		    "Layer %i has negative soil moisture, %f", 
		    lindex, moist[lindex]);
	    vicerror(ErrStr);
	  }
	}

	/** Set Layer Ice Content **/
	ice[lindex]       = layer[lindex].ice;

	/** Set Layer Maximum Moisture Content **/
	max_moist[lindex] = soil_con->max_moist[lindex];
	
      }
      
      /******************************************************
        Runoff Based on Soil Moisture Level of Upper Layers
      ******************************************************/

      top_moist = 0.;
      top_max_moist=0.;
      for(lindex=0;lindex<options.Nlayer-1;lindex++) {
	top_moist += (moist[lindex] + ice[lindex]);
	top_max_moist += max_moist[lindex];
      }
      if(top_moist>top_max_moist) top_moist = top_max_moist;
      
      /**************************************************
        Calculate Runoff from Surface
      **************************************************/
      
      /** Runoff Calculations for Top Layer Only **/
      /** A and i_0 as in Wood et al. in JGR 97, D3, 1992 equation (1) **/
      
      max_infil = (1.0+soil_con->b_infilt) * top_max_moist;
      
      ex        = soil_con->b_infilt / (1.0 + soil_con->b_infilt);
      A         = 1.0 - pow((1.0 - top_moist / top_max_moist),ex);
      i_0       = max_infil * (1.0 - pow((1.0 - A),(1.0 
						    / soil_con->b_infilt))); 
      /* Maximum Inflow */
      
      /** equation (3a) Wood et al. **/
      
      if (inflow == 0.0) *runoff = 0.0;
      else if (max_infil == 0.0) *runoff = inflow;
      else if ((i_0 + inflow) > max_infil) 
	*runoff = inflow - top_max_moist + top_moist;
      
      /** equation (3b) Wood et al. (wrong in paper) **/
      else {
	basis = 1.0 - (i_0 + inflow) / max_infil;
	*runoff = (inflow - top_max_moist + top_moist + top_max_moist
		   * pow(basis,1.0*(1.0+soil_con->b_infilt)));
      }
      if(*runoff<0.) *runoff=0.;
      
      /**************************************************
        Compute Flow Between Soil Layers (using an hourly time step)
      **************************************************/
      
      dt_inflow  =  inflow / (double) dt;
      dt_outflow =  0.0;
      
      for (time_step = 0; time_step < dt; time_step++) {
	inflow   = dt_inflow;
	last_cnt = 0;
	
#if LOW_RES_MOIST
	for( lindex = 0; lindex < options.Nlayer; lindex++ ) {
	  if( (tmp_moist = moist[lindex] - layer[lindex].evap / (double)dt) 
	     < resid_moist[lindex] )
	    tmp_moist = resid_moist[lindex];
	  if(tmp_moist > resid_moist[lindex])
	    matric[lindex] = soil_con->bubble[lindex] 
	      * pow( (tmp_moist - resid_moist[lindex]) 
		     / (soil_con->max_moist[lindex] - resid_moist[lindex]), 
		     -b[lindex]);
	  else
	    matric[lindex] = HUGE_RESIST;
	}
#endif

	/*************************************
          Compute Drainage between Sublayers 
        *************************************/
	
	for( lindex = 0; lindex < options.Nlayer-1; lindex++ ) {
	      
	  /** Brooks & Corey relation for hydraulic conductivity **/

	  if((tmp_moist = moist[lindex] - layer[lindex].evap / (double)dt) 
	     < resid_moist[lindex])
	    tmp_moist = resid_moist[lindex];
	  
	  if(moist[lindex] > resid_moist[lindex]) {
#if LOW_RES_MOIST
	    avg_matric = pow( 10, (soil_con->depth[lindex+1] 
				     * log10(fabs(matric[lindex]))
				     + soil_con->depth[lindex]
				     * log10(fabs(matric[lindex+1])))
				    / (soil_con->depth[lindex] 
				       + soil_con->depth[lindex+1]) );
	    tmp_moist = resid_moist[lindex]
	      + ( soil_con->max_moist[lindex] - resid_moist[lindex] )
	      * pow( ( avg_matric / soil_con->bubble[lindex] ), -1/b[lindex] );
#endif
	    Q12[lindex] 
	      = Ksat[lindex] * pow(((tmp_moist - resid_moist[lindex]) 
				    / (soil_con->max_moist[lindex] 
				       - resid_moist[lindex])),
				   soil_con->expt[lindex]); 
	  }
	  else Q12[lindex] = 0.;
	  last_layer[last_cnt] = lindex;
	}

	/**************************************************
          Solve for Current Soil Layer Moisture, and
          Check Versus Maximum and Minimum Moisture
          Contents.  
	**************************************************/
	
	firstlayer = TRUE;
	last_index = 0;
	for(lindex=0;lindex<options.Nlayer-1;lindex++) {

	  if(lindex==0) dt_runoff = *runoff / (double) dt;
	  else dt_runoff = 0;

	  /* Store moistures for water balance debugging */
#if LINK_DEBUG
	  if(debug.PRT_BALANCE) {
	    if(time_step==0) {
	      if(firstlayer)
		debug.inflow[dist][band][lindex+2] = inflow - dt_runoff;
	      else {
		debug.inflow[dist][band][lindex+2] = inflow;
		debug.outflow[dist][band][lindex+1] = inflow;
	      }
	    }
	    else {
	      if(firstlayer)
		debug.inflow[dist][band][lindex+2]  += inflow - dt_runoff;
	      else {
		debug.inflow[dist][band][lindex+2]  += inflow;
		debug.outflow[dist][band][lindex+1] += inflow;
	      }
	    }
	  }
#endif

	  /* transport moisture for all sublayers **/
#if LINK_DEBUG
	  if(debug.DEBUG || debug.PRT_BALANCE) 
	    last_moist = moist[lindex];
#endif
	      
	  tmp_inflow = 0.;

	  /** Update soil layer moisture content **/
	  moist[lindex] = moist[lindex] + (inflow - dt_runoff) 
	    - (Q12[lindex] + layer[lindex].evap/(double)dt);

	  /** Verify that soil layer moisture is less than maximum **/
	  if((moist[lindex]+ice[lindex]) > max_moist[lindex]) {
	    tmp_inflow = (moist[lindex]+ice[lindex]) - max_moist[lindex];
	    moist[lindex] = max_moist[lindex] - ice[lindex];

	    if(lindex==0) {
	      Q12[lindex] += tmp_inflow;
	      tmp_inflow = 0;
	    }
	    else {
	      tmplayer = lindex;
	      while(tmp_inflow > 0) {
		tmplayer--;
#if LINK_DEBUG
		if(debug.PRT_BALANCE) {
		  /** Update debugging storage terms **/
		  debug.inflow[dist][band][lindex+2]  -= tmp_inflow;
		  debug.outflow[dist][band][lindex+1] -= tmp_inflow;
		}
#endif
		if(tmplayer<0) {
		  /** If top layer saturated, add to top layer **/
		  *runoff += tmp_inflow;
		  tmp_inflow = 0;
		}
		else {
		  /** else add excess soil moisture to next higher layer **/
		  moist[tmplayer] += tmp_inflow;
		  if((moist[tmplayer]+ice[tmplayer]) > max_moist[tmplayer]) {
		    tmp_inflow = ((moist[tmplayer] + ice[tmplayer])
				  - max_moist[tmplayer]);
		    moist[tmplayer] = max_moist[tmplayer] - ice[tmplayer];
		  }
		  else tmp_inflow=0;
		}
	      }
	    } /** end trapped excess moisture **/
	  } /** end check if excess moisture in top layer **/
	      
	  firstlayer=FALSE;
	  
	  /** verify that current layer moisture is greater than minimum **/
	  if ((moist[lindex]+ice[lindex]) < resid_moist[lindex]) {
	    /** moisture cannot fall below residual moisture content **/
	    Q12[lindex] += moist[lindex] - resid_moist[lindex];
	    moist[lindex] = resid_moist[lindex];
	  }
	      
	  inflow = (Q12[lindex]+tmp_inflow);
	  Q12[lindex] += tmp_inflow;
	      
	  last_index++;
	      
	} /* end loop through soil layers */
	  
	/**************************************************
	   Compute Baseflow
        **************************************************/
      
	/** ARNO model for the bottom soil layer (based on bottom
	 soil layer moisture from previous time step) **/
      
	lindex = options.Nlayer-1;
	Dsmax = soil_con->Dsmax / 24.;

#if LINK_DEBUG
	if(debug.DEBUG || debug.PRT_BALANCE) {
	  last_moist = moist[lindex];
	  /** Update debugging storage terms **/
	  debug.outflow[dist][band][lindex+1] += Q12[lindex-1];
	  debug.inflow[dist][band][lindex+2]  += Q12[lindex-1];
	}
#endif
      
	frac = soil_con->Ds * Dsmax 
	  / (soil_con->Ws * soil_con->max_moist[lindex]);
	dt_baseflow = frac * ( moist[lindex] - resid_moist[lindex] );
	if (moist[lindex] > soil_con->Ws * soil_con->max_moist[lindex]) {
	  frac = (moist[lindex] - soil_con->Ws * soil_con->max_moist[lindex]) 
	    / (soil_con->max_moist[lindex] - soil_con->Ws 
	       * soil_con->max_moist[lindex]);
	  dt_baseflow += (Dsmax - soil_con->Ds * Dsmax / soil_con->Ws) 
	    * pow(frac,soil_con->c);
	}

        /** Make sure baseflow isn't negative **/
	if(dt_baseflow < 0) dt_baseflow = 0;

	/** Extract baseflow from the bottom soil layer **/ 
	
	moist[lindex] += Q12[lindex-1] - (layer[lindex].evap/(double)dt 
					  + dt_baseflow);
      
	/** Check Lower Sub-Layer Moistures **/
	tmp_moist = 0;
	
        /* If baseflow > 0 and soil moisture has gone below residual,
         * take water out of baseflow and add back to soil to make up the difference
         * Note: if baseflow is small, soil moisture may still be < residual after this */
	if(dt_baseflow > 0 && (moist[lindex]+ice[lindex]) < resid_moist[lindex]) {
          if ( dt_baseflow > resid_moist[lindex] - (moist[lindex]+ice[lindex]) ) {
            dt_baseflow -= resid_moist[lindex] - (moist[lindex]+ice[lindex]);
            moist[lindex] += resid_moist[lindex] - (moist[lindex]+ice[lindex]);
	  }
          else {
            moist[lindex] += dt_baseflow;
            dt_baseflow = 0.0;
          }
	}

	if((moist[lindex]+ice[lindex]) > max_moist[lindex]) {
	  /* soil moisture above maximum */
	  tmp_moist = ((moist[lindex]+ice[lindex]) - max_moist[lindex]);
	  moist[lindex] = max_moist[lindex] - ice[lindex];
	  tmplayer = lindex;
	  while(tmp_moist > 0) {
	    tmplayer--;
#if LINK_DEBUG
	    if(debug.PRT_BALANCE) {
	      /** Update debugging storage terms **/
	      debug.inflow[dist][band][lindex+2]  -= tmp_moist;
	      debug.outflow[dist][band][lindex+1] -= tmp_moist;
	    }
#endif
	    if(tmplayer<0) {
	      /** If top layer saturated, add to top layer **/
	      *runoff += tmp_moist;
	      tmp_moist = 0;
	    }
	    else {
	      /** else if sublayer exists, add excess soil moisture **/
	      moist[tmplayer] += tmp_moist ;
	      if((moist[tmplayer]+ice[tmplayer]) > max_moist[tmplayer]) {
		tmp_moist = ((moist[tmplayer] + ice[tmplayer])
				 - max_moist[tmplayer]);
		moist[tmplayer] = max_moist[tmplayer] - ice[tmplayer];
	      }
	      else tmp_moist=0;
	    }
	  }
	}

	for(lindex=0;lindex<options.Nlayer;lindex++) 
	  layer[lindex].moist      = moist[lindex] + ice[lindex];      
	*baseflow += dt_baseflow;

      } /* end of hourly time step loop */
      
#if LINK_DEBUG
      if(debug.PRT_BALANCE) {
	debug.outflow[dist][band][options.Nlayer+2] = (*runoff + *baseflow);
	debug.outflow[dist][band][options.Nlayer+1] = *baseflow;
      }
#endif
    }
  } /** Loop over wet and dry fractions **/

  /** Recompute Thermal Parameters Based on New Moisture Distribution **/
  if(options.FULL_ENERGY || options.FROZEN_SOIL) {

    for(lindex=0;lindex<options.Nlayer;lindex++) {
      tmp_layer = find_average_layer(&(layer_wet[lindex]), 
				     &(layer_dry[lindex]), 
				     soil_con->depth[lindex], tmp_mu);
      moist[lindex] = tmp_layer.moist;
    }

    distribute_node_moisture_properties(energy->moist, energy->ice,
					energy->kappa_node, energy->Cs_node,
					soil_con->dz_node, energy->T,
					soil_con->max_moist_node,
#if QUICK_FS
					soil_con->ufwc_table_node,
#else
					soil_con->expt_node,
					soil_con->bubble_node, 
#endif
					moist, soil_con->depth, 
					soil_con->soil_density,
					soil_con->bulk_density,
					soil_con->quartz, Nnodes, 
					options.Nlayer, soil_con->FS_ACTIVE);

  }

}
