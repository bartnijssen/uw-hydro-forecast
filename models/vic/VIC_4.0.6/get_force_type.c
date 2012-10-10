#include <stdio.h>
#include <stdlib.h>
#include <vicNl.h>
#include <string.h>

static char vcid[] = "$Id: get_force_type.c,v 4.2.2.6 2007/09/18 16:19:20 vicadmin Exp $";

void get_force_type(char   *cmdstr, 
		    int     file_num,
		    int    *field) {
/*************************************************************
  get_force_type.c      Keith Cherkauer     January 20, 2000

  This routine determines the current forcing file data type
  and stores its location in the description of the current 
  forcing file.

  2006-Sep-14 (Port from 4.1.0) Added support for ALMA input variables. TJB
  2006-Dec-29 Added REL_HUMID to list of supported met input variables. TJB
  2007-Jan-02 Added CSNOWF and LSSNOWF to list of supported met input variables. TJB
  2007-Jan-02 Added ALMA_INPUT option; removed TAIR and PSURF from list
	      of supported met input variables.				TJB
  2007-Jan-05 Bugfix: replaced if(BINARY) with
	      if(param_set.FORCE_FORMAT[file_num]==BINARY).		TJB
  2007-Feb-25 Removed all of the if statements
	        if(param_set.FORCE_FORMAT[file_num]==BINARY)
	      since this ended up requiring that the FORCE_FORMAT BINARY line
	      appear in the global parameter file before the list of forcing
	      variables in order to work.  Since the sscanf() performs
	      proper parsing regardless of ASCII (which doesn't have SIGNED
	      or MULTIPLIER fields) vs. BINARY, I removed the if() statements
	      altogether.						TJB
  2007-Sep-14 Initialize flgstr to "NULL".				TJB

*************************************************************/

  extern param_set_struct param_set;

  char optstr[50];
  char flgstr[10];
  char ErrStr[MAXSTRING];
  int  type;

  /** Initialize flgstr **/
  strcpy(flgstr,"NULL");

  if((*field) >= param_set.N_TYPES[file_num]) {
    sprintf(ErrStr,"Too many variables defined for forcing file %i.",file_num);
    nrerror(ErrStr);
  }

  sscanf(cmdstr,"%*s %s",optstr);

  /***************************************
    Get meteorological data forcing info
  ***************************************/

  /* type 0: air temperature [C] (ALMA_INPUT: [K]) */
  if(strcasecmp("AIR_TEMP",optstr)==0){
    type = AIR_TEMP;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    sscanf(cmdstr,"%*s %*s %s %lf",flgstr,
	   &param_set.TYPE[type].multiplier);
    if(strcasecmp("SIGNED",flgstr)==0) param_set.TYPE[type].SIGNED=TRUE;
    else param_set.TYPE[type].SIGNED=FALSE;
  }

  /* type 1: albedo [fraction] */
  else if(strcasecmp("ALBEDO",optstr)==0){
    type = ALBEDO;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    sscanf(cmdstr,"%*s %*s %s %lf",flgstr,
	   &param_set.TYPE[type].multiplier);
    if(strcasecmp("SIGNED",flgstr)==0) param_set.TYPE[type].SIGNED=TRUE;
    else param_set.TYPE[type].SIGNED=FALSE;
  }

  /* type 2: convective rainfall [mm] (ALMA_INPUT: [mm/s]) */
  else if(strcasecmp("CRAINF",optstr)==0){
    type = CRAINF;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    sscanf(cmdstr,"%*s %*s %s %lf",flgstr,
	   &param_set.TYPE[type].multiplier);
    if(strcasecmp("SIGNED",flgstr)==0) param_set.TYPE[type].SIGNED=TRUE;
    else param_set.TYPE[type].SIGNED=FALSE;
  }

  /* type 3: convective snowfall [mm] (ALMA_INPUT: [mm/s]) */
  else if(strcasecmp("CSNOWF",optstr)==0){
    type = CSNOWF;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    sscanf(cmdstr,"%*s %*s %s %lf",flgstr,
	   &param_set.TYPE[type].multiplier);
    if(strcasecmp("SIGNED",flgstr)==0) param_set.TYPE[type].SIGNED=TRUE;
    else param_set.TYPE[type].SIGNED=FALSE;
  }

  /* type 4: air density [kg/m3] */
  else if(strcasecmp("DENSITY",optstr)==0){
    type = DENSITY;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    sscanf(cmdstr,"%*s %*s %s %lf",flgstr,
	   &param_set.TYPE[type].multiplier);
    if(strcasecmp("SIGNED",flgstr)==0) param_set.TYPE[type].SIGNED=TRUE;
    else param_set.TYPE[type].SIGNED=FALSE;
  }

  /* type 5: incoming longwave radiation [W/m2] */
  else if(strcasecmp("LONGWAVE",optstr)==0){
    type = LONGWAVE;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    sscanf(cmdstr,"%*s %*s %s %lf",flgstr,
	   &param_set.TYPE[type].multiplier);
    if(strcasecmp("SIGNED",flgstr)==0) param_set.TYPE[type].SIGNED=TRUE;
    else param_set.TYPE[type].SIGNED=FALSE;
  }

  /* type 6: large-scale rainfall [mm] (ALMA_INPUT: [mm/s]) */
  else if(strcasecmp("LSRAINF",optstr)==0){
    type = LSRAINF;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    sscanf(cmdstr,"%*s %*s %s %lf",flgstr,
	   &param_set.TYPE[type].multiplier);
    if(strcasecmp("SIGNED",flgstr)==0) param_set.TYPE[type].SIGNED=TRUE;
    else param_set.TYPE[type].SIGNED=FALSE;
  }

  /* type 7: large-scale snowfall [mm] (ALMA_INPUT: [mm/s]) */
  else if(strcasecmp("LSSNOWF",optstr)==0){
    type = LSSNOWF;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    sscanf(cmdstr,"%*s %*s %s %lf",flgstr,
	   &param_set.TYPE[type].multiplier);
    if(strcasecmp("SIGNED",flgstr)==0) param_set.TYPE[type].SIGNED=TRUE;
    else param_set.TYPE[type].SIGNED=FALSE;
  }

  /* type 8: precipitation [mm] (ALMA_INPUT: [mm/s]) */
  else if(strcasecmp("PREC",optstr)==0){
    type = PREC;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    sscanf(cmdstr,"%*s %*s %s %lf",flgstr,
	   &param_set.TYPE[type].multiplier);
    if(strcasecmp("SIGNED",flgstr)==0) param_set.TYPE[type].SIGNED=TRUE;
    else param_set.TYPE[type].SIGNED=FALSE;
  }

  /* type 9: air pressure [kPa] (ALMA_INPUT: [Pa]) */
  else if(strcasecmp("PRESSURE",optstr)==0){
    type = PRESSURE;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    sscanf(cmdstr,"%*s %*s %s %lf",flgstr,
	   &param_set.TYPE[type].multiplier);
    if(strcasecmp("SIGNED",flgstr)==0) param_set.TYPE[type].SIGNED=TRUE;
    else param_set.TYPE[type].SIGNED=FALSE;
  }

  /* type 10: specific humidity [kg/kg] */
  else if(strcasecmp("QAIR",optstr)==0){
    type = QAIR;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    sscanf(cmdstr,"%*s %*s %s %lf",flgstr,
	   &param_set.TYPE[type].multiplier);
    if(strcasecmp("SIGNED",flgstr)==0) param_set.TYPE[type].SIGNED=TRUE;
    else param_set.TYPE[type].SIGNED=FALSE;
  }

  /* type 11: rainfall [mm] (ALMA_INPUT: [mm/s]) */
  else if(strcasecmp("RAINF",optstr)==0){
    type = RAINF;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    sscanf(cmdstr,"%*s %*s %s %lf",flgstr,
	   &param_set.TYPE[type].multiplier);
    if(strcasecmp("SIGNED",flgstr)==0) param_set.TYPE[type].SIGNED=TRUE;
    else param_set.TYPE[type].SIGNED=FALSE;
  }

  /* type 12: relative humidity [fraction] */
  else if(strcasecmp("REL_HUMID",optstr)==0){
    type = REL_HUMID;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    sscanf(cmdstr,"%*s %*s %s %lf",flgstr,
           &param_set.TYPE[type].multiplier);
    if(strcasecmp("SIGNED",flgstr)==0) param_set.TYPE[type].SIGNED=TRUE;
    else param_set.TYPE[type].SIGNED=FALSE;
  }

  /* type 13: shortwave radiation [W/m2] */
  else if(strcasecmp("SHORTWAVE",optstr)==0){
    type = SHORTWAVE;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    sscanf(cmdstr,"%*s %*s %s %lf",flgstr,
	   &param_set.TYPE[type].multiplier);
    if(strcasecmp("SIGNED",flgstr)==0) param_set.TYPE[type].SIGNED=TRUE;
    else param_set.TYPE[type].SIGNED=FALSE;
  }

  /* type 14: snowfall rate [mm] (ALMA_INPUT: [mm/s]) */
  else if(strcasecmp("SNOWF",optstr)==0){
    type = SNOWF;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    sscanf(cmdstr,"%*s %*s %s %lf",flgstr,
	   &param_set.TYPE[type].multiplier);
    if(strcasecmp("SIGNED",flgstr)==0) param_set.TYPE[type].SIGNED=TRUE;
    else param_set.TYPE[type].SIGNED=FALSE;
  }

  /* type 15: maximum daily temperature [C] (ALMA_INPUT: [K]) */
  else if(strcasecmp("TMAX",optstr)==0){
    type = TMAX;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    sscanf(cmdstr,"%*s %*s %s %lf",flgstr,
	   &param_set.TYPE[type].multiplier);
    if(strcasecmp("SIGNED",flgstr)==0) param_set.TYPE[type].SIGNED=TRUE;
    else param_set.TYPE[type].SIGNED=FALSE;
  }

  /* type 16: minimum daily temperature [C] (ALMA_INPUT: [K]) */
  else if(strcasecmp("TMIN",optstr)==0){
    type = TMIN;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    sscanf(cmdstr,"%*s %*s %s %lf",flgstr,
	   &param_set.TYPE[type].multiplier);
    if(strcasecmp("SIGNED",flgstr)==0) param_set.TYPE[type].SIGNED=TRUE;
    else param_set.TYPE[type].SIGNED=FALSE;
  }

  /* type 17: sky cover */
  else if(strcasecmp("TSKC",optstr)==0){
    type = TSKC;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    sscanf(cmdstr,"%*s %*s %s %lf",flgstr,
	   &param_set.TYPE[type].multiplier);
    if(strcasecmp("SIGNED",flgstr)==0) param_set.TYPE[type].SIGNED=TRUE;
    else param_set.TYPE[type].SIGNED=FALSE;
  }

  /* type 18: vapor pressure [kPa] (ALMA_INPUT: [Pa]) */
  else if(strcasecmp("VP",optstr)==0){
    type = VP;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    sscanf(cmdstr,"%*s %*s %s %lf",flgstr,
	   &param_set.TYPE[type].multiplier);
    if(strcasecmp("SIGNED",flgstr)==0) param_set.TYPE[type].SIGNED=TRUE;
    else param_set.TYPE[type].SIGNED=FALSE;
  }

  /* type 19: wind speed [m/s] */
  else if(strcasecmp("WIND",optstr)==0){
    type = WIND;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    sscanf(cmdstr,"%*s %*s %s %lf",flgstr,
	   &param_set.TYPE[type].multiplier);
    if(strcasecmp("SIGNED",flgstr)==0) param_set.TYPE[type].SIGNED=TRUE;
    else param_set.TYPE[type].SIGNED=FALSE;
  }

  /* type 20: zonal wind speed [m/s] */
  else if(strcasecmp("WIND_E",optstr)==0){
    type = WIND_E;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    sscanf(cmdstr,"%*s %*s %s %lf",flgstr,
	   &param_set.TYPE[type].multiplier);
    if(strcasecmp("SIGNED",flgstr)==0) param_set.TYPE[type].SIGNED=TRUE;
    else param_set.TYPE[type].SIGNED=FALSE;
  }

  /* type 21: meridional wind speed [m/s] */
  else if(strcasecmp("WIND_N",optstr)==0){
    type = WIND_N;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    sscanf(cmdstr,"%*s %*s %s %lf",flgstr,
	   &param_set.TYPE[type].multiplier);
    if(strcasecmp("SIGNED",flgstr)==0) param_set.TYPE[type].SIGNED=TRUE;
    else param_set.TYPE[type].SIGNED=FALSE;
  }

  /* type 22: unused (blank) data */
  else if(strcasecmp("SKIP",optstr)==0){
    type = SKIP;
    param_set.TYPE[type].SUPPLIED=file_num+1;
    param_set.FORCE_INDEX[file_num][(*field)] = type;
    param_set.TYPE[type].multiplier = 1;
    param_set.TYPE[type].SIGNED=FALSE;
  }

  /** Undefined variable type **/
  else {
    sprintf(ErrStr,"Undefined forcing variable type %s in file %i.",
	    optstr, file_num);
    nrerror(ErrStr);
  }

  (*field)++;

}
