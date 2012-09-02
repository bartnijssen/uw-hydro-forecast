#include <stdio.h>
#include <stdlib.h>
#include <vicNl.h>

static char vcid[] = "$Id: write_forcing_file.c,v 1.2.2.6 2007/01/11 02:01:06 vicadmin Exp $";

#if OUTPUT_FORCE
void write_forcing_file(atmos_data_struct *atmos,
			int                nrecs,
			out_data_file_struct *out_data_files, 
			out_data_struct   *out_data)
/**********************************************************************
  write_forcing_file          Keith Cherkauer           July 19, 2000

  This routine writes the complete forcing data files for use in 
  future simulations.
  2006-08-23 Changed order of fread/fwrite statements from ...1, sizeof...
             to ...sizeof, 1,...				GCT
  2006-Sep-11 Implemented flexible output configuration; uses the new
              out_data and out_data_files structures.		TJB
  2006-Sep-14 Implemented ALMA-compliant input and output.	TJB
  2006-Sep-23 Fixed bugs in computation of QAIR and REL_HUMID;
	      updated aggdata[] arrays to make it compatible with
	      aggregation.					TJB
  2007-Jan-03 Bugfix: Declared index i.				TJB

**********************************************************************/
{
  extern global_param_struct global_param;
  extern option_struct options;

  int                 rec, i, j, v;
  short int          *tmp_siptr;
  unsigned short int *tmp_usiptr;
  dmy_struct         *dummy_dmy;
  int                 dummy_dt;
  int                 dt_sec;

  dt_sec = global_param.dt*SECPHOUR;

  for ( rec = 0; rec < nrecs; rec++ ) {
    for ( j = 0; j < NF; j++ ) {

      out_data[OUT_AIR_TEMP].data[0]  = atmos[rec].air_temp[j];
      out_data[OUT_DENSITY].data[0]   = atmos[rec].density[j];
      out_data[OUT_LONGWAVE].data[0]  = atmos[rec].longwave[j];
      out_data[OUT_PREC].data[0]      = atmos[rec].prec[j];
      out_data[OUT_PRESSURE].data[0]  = atmos[rec].pressure[j];
      out_data[OUT_QAIR].data[0]      = EPS * atmos[rec].vp[j]/atmos->pressure[j];
      out_data[OUT_REL_HUMID].data[0] = 100.*atmos[rec].vp[j]/(atmos->vp[j]+atmos->vpd[j]);
      out_data[OUT_SHORTWAVE].data[0] = atmos[rec].shortwave[j];
      out_data[OUT_VP].data[0]        = atmos[rec].vp[j];
      out_data[OUT_WIND].data[0]      = atmos[rec].wind[j];
      if (out_data[OUT_AIR_TEMP].data[0] >= global_param.MAX_SNOW_TEMP) {
        out_data[OUT_RAINF].data[0] = out_data[OUT_PREC].data[0];
        out_data[OUT_SNOWF].data[0] = 0;
      }
      else if (out_data[OUT_AIR_TEMP].data[0] <= global_param.MIN_RAIN_TEMP) {
        out_data[OUT_RAINF].data[0] = 0;
        out_data[OUT_SNOWF].data[0] = out_data[OUT_PREC].data[0];
      }
      else {
        out_data[OUT_RAINF].data[0] = ((out_data[OUT_AIR_TEMP].data[0]-global_param.MIN_RAIN_TEMP)/(global_param.MAX_SNOW_TEMP-global_param.MIN_RAIN_TEMP))*out_data[OUT_PREC].data[0];
        out_data[OUT_SNOWF].data[0] = out_data[OUT_PREC].data[0]-out_data[OUT_RAINF].data[0];
      }

      for (v=0; v<N_OUTVAR_TYPES; v++) {
        for (i=0; i<out_data[v].nelem; i++) {
          out_data[v].aggdata[i] = out_data[v].data[i];
        }
      }

      if (options.ALMA_OUTPUT) {
        out_data[OUT_PREC].aggdata[0] /= dt_sec;
        out_data[OUT_RAINF].aggdata[0] /= dt_sec;
        out_data[OUT_SNOWF].aggdata[0] /= dt_sec;
        out_data[OUT_AIR_TEMP].aggdata[0] += KELVIN;
        out_data[OUT_PRESSURE].aggdata[0] *= 1000;
        out_data[OUT_VP].aggdata[0] *= 1000;
      }

      if (options.BINARY_OUTPUT) {
        for (v=0; v<N_OUTVAR_TYPES; v++) {
          for (i=0; i<out_data[v].nelem; i++) {
            out_data[v].aggdata[i] *= out_data[v].mult;
          }
        }
      }
      write_data(out_data_files, out_data, dummy_dmy, dummy_dt);
    }
  }

}
#endif /* OUTPUT_FORCE */
