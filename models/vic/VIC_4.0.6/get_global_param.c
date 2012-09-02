#include <stdio.h>
#include <stdlib.h>
#include <vicNl.h>
#include <string.h>
 
static char vcid[] = "$Id: get_global_param.c,v 4.2.2.27 2008/01/20 05:44:52 vicadmin Exp $";

/********************************************************************/
/*			GLOBAL VARIABLES                            */
/********************************************************************/
int NR;		      /* array index for atmos struct that indicates
			 the model step avarage or sum */
int NF;		      /* array index loop counter limit for atmos
			 struct that indicates the SNOW_STEP values */
 
global_param_struct get_global_param(filenames_struct      *names,
                                     FILE                  *gp)
/**********************************************************************
  get_global_param	Keith Cherkauer	            March 1998

  This routine reads the VIC model global control file, getting
  values for global parameters, model options, and debugging controls.

  Modifications:
  7-19-96 Modified to read time step		        KAC
  4-5-98  Modified to read model options and debugging
          controls from a single file                   KAC
  01-20-00 modified to work with new radiation estimation routines,
           new simplified frozen soil moisture, and new new open
           format forcing file rad routines.              KAC
  06-03-03 modified to handle both ASCII and BINARY state files.  KAC
  09-02-2003 Moved COMPUTE_TREELINE flag from user_def.h to the 
             options structure.  Now when not set to FALSE, the 
             value indicates the default above treeline vegetation
             if no usable vegetation types are in the grid cell 
             (i.e. everything has a canopy).  A negative value  
             will cause the model to use bare soil.  Make sure that 
             positive index value refer to a non-canopied vegetation
             type in the vegetation library.                   KAC
  10-Oct-03 Modified to understand the ARNO_PARAMS option.	TJB
  10-May-04 Modified to display compile-time and run-time options
	    if VERBOSE is set to TRUE.				TJB
  2005-11-09 Checked for missing STATEMONTH and STATEDAY        GCT
  2005-11-09 (Port from 4.1.0) Added validation for Nnodes with QUICK_FLUX 
            option, as part of fix for QUICK_FLUX state file compatibility.GCT
  2005-11-10 Moved setting of statename from open_state_file to here. GCT
  2005-11-21 Added checks for range of STATEMONTH and STATEDAY  GCT
  2005-11-21 (Port from 4.1.0) Changed ARNO_PARAMS to NIJSSEN2001_BASEFLOW. GCT
  2005-11-23 Allow user to use NO_FLUX in addition to NOFLUX for NOFLUX in 
             global.param.file  GCT
  2006-Jan-22 Replaced NIJSSEN2001_BASEFLOW with BASEFLOW option.	TJB
  2006-Sep-01 (Port from 4.1.0) Added support for OUTPUT_FORCE option.	TJB
  2006-Sep-11 Implemented flexible output configuration; uses new
              N_OUTFILES, OUTFILE, and OUTVAR flags; removed the
              OPTIMIZE and LDAS_OUTPUT options.				TJB
  2006-Sep-18 Implemented aggregation of output variables.		TJB
  2006-Oct-26 Merged infiles and outfiles structs into filep_struct;
	      This included moving global->statename to filenames->statefile;
	      also added f_path_pfx to store forcing file path and prefix. TJB
  2007-Jan-03 Added ALMA_INPUT option.					TJB
  2007-Jan-15 Added PRT_HEADER option.					TJB
  2007-Apr-23 Added initialization of some global parameters.		TJB
  2007-Sep-14 Added initialization of names->soil_dir.			TJB
  2007-Oct-10 Added validation of dt, start date, end date, and nrecs.	TJB
  2007-Oct-31 Added validation of input/output files.			TJB
  2008-Jan-19 Removed setting of SNOW_STEP = global.dt for
	      OUTPUT_FORCE == TRUE.					TJB

**********************************************************************/
{
  extern option_struct    options;
  extern param_set_struct param_set;
#if LINK_DEBUG
  extern debug_struct     debug;
#endif
  extern int              NF, NR;

  char cmdstr[MAXSTRING];
  char optstr[MAXSTRING];
  char flgstr[MAXSTRING];
  char ErrStr[MAXSTRING];
  int  file_num;
  int  field;
  int  i;
  int  lastvalidday;    
  int  lastday[] = {
	    31,	/* JANUARY */
	    28,	/* FEBRUARY */
	    31,	/* MARCH */
	    30,	/* APRIL */
	    31,	/* MAY */
	    30,	/* JUNE */
	    31,	/* JULY */
	    31,	/* AUGUST */
	    30,	/* SEPTEMBER */
	    31,	/* OCTOBER */
	    30,	/* NOVEMBER */
	    31,	/* DECEMBER */
        } ;
  global_param_struct global;
  int outfilenum;
  int  fn;
  char varname[20];
  int outvarnum;
  int format;
  char formatstr[10];
  int type;
  char typestr[10];
  float multiplier;

  /** Initialize global parameters (that aren't part of the options struct) **/
  global.dt            = MISSING;
  global.startyear     = MISSING;
  global.startmonth    = MISSING;
  global.startday      = MISSING;
  global.starthour     = MISSING;
  global.endyear       = MISSING;
  global.endmonth      = MISSING;
  global.endday        = MISSING;
  global.nrecs         = MISSING;
  global.resolution    = MISSING;
  global.MAX_SNOW_TEMP = 0;
  global.MIN_RAIN_TEMP = 0;
  global.measure_h     = 2.0;
  global.wind_h        = 10.0;
  for(i = 0; i < 2; i++) {
    global.forceyear[i]  = MISSING;
    global.forcemonth[i] = 1;
    global.forceday[i]   = 1;
    global.forcehour[i]  = 0;
    global.forceskip[i]  = 0;
    strcpy(names->f_path_pfx[i],"MISSING");
  }
  file_num             = 0;
  global.skipyear      = 0;
  strcpy(names->init_state,   "MISSING");
  global.stateyear     = MISSING;
  global.statemonth    = MISSING;
  global.stateday      = MISSING;
  strcpy(names->statefile,    "MISSING");
  strcpy(names->soil,         "MISSING");
  strcpy(names->soil_dir,     "MISSING");
  strcpy(names->veg,          "MISSING");
  strcpy(names->veglib,       "MISSING");
  strcpy(names->snowband,     "MISSING");
  strcpy(names->result_dir,   "MISSING");
  global.out_dt        = MISSING;

  /** Read through global control file to find parameters **/

  fgets(cmdstr,MAXSTRING,gp);

  while(!feof(gp)) {
    if(cmdstr[0]!='#' && cmdstr[0]!='\n' && cmdstr[0]!='\0') {

      sscanf(cmdstr,"%s",optstr);

      /*******************************
        Get Model Global Parameters
	*****************************/
      if(strcasecmp("NLAYER",optstr)==0) {
        sscanf(cmdstr,"%*s %d",&options.Nlayer);
      }
      else if(strcasecmp("TIME_STEP",optstr)==0) {
        sscanf(cmdstr,"%*s %d",&global.dt);
      }
      else if(strcasecmp("OUT_STEP",optstr)==0) {
        sscanf(cmdstr,"%*s %d",&global.out_dt);
      }
      else if(strcasecmp("RESOLUTION",optstr)==0) {
        sscanf(cmdstr,"%*s %f",&global.resolution);
      }
      else if(strcasecmp("STARTYEAR",optstr)==0) {
        sscanf(cmdstr,"%*s %d",&global.startyear);
      }
      else if(strcasecmp("STARTMONTH",optstr)==0) {
        sscanf(cmdstr,"%*s %d",&global.startmonth);
      }
      else if(strcasecmp("STARTDAY",optstr)==0) {
        sscanf(cmdstr,"%*s %d",&global.startday);
      }
      else if(strcasecmp("STARTHOUR",optstr)==0) {
        sscanf(cmdstr,"%*s %d",&global.starthour);
      }
      else if(strcasecmp("ENDYEAR",optstr)==0) {
        sscanf(cmdstr,"%*s %d",&global.endyear);
      }
      else if(strcasecmp("ENDMONTH",optstr)==0) {
        sscanf(cmdstr,"%*s %d",&global.endmonth);
      }
      else if(strcasecmp("ENDDAY",optstr)==0) {
        sscanf(cmdstr,"%*s %d",&global.endday);
      }
      else if(strcasecmp("NRECS",optstr)==0) {
        sscanf(cmdstr,"%*s %d",&global.nrecs);
      }
      else if(strcasecmp("SKIPYEAR",optstr)==0) {
        sscanf(cmdstr,"%*s %d",&global.skipyear);
      }
      else if(strcasecmp("FORCEYEAR",optstr)==0) {
        sscanf(cmdstr,"%*s %d",&global.forceyear[file_num]);
      }
      else if(strcasecmp("FORCEMONTH",optstr)==0) {
        sscanf(cmdstr,"%*s %d",&global.forcemonth[file_num]);
      }
      else if(strcasecmp("FORCEDAY",optstr)==0) {
        sscanf(cmdstr,"%*s %d",&global.forceday[file_num]);
      }
      else if(strcasecmp("FORCEHOUR",optstr)==0) {
        sscanf(cmdstr,"%*s %d",&global.forcehour[file_num]);
      }
      else if(strcasecmp("WIND_H",optstr)==0) {
        sscanf(cmdstr,"%*s %lf",&global.wind_h);
      }
      else if(strcasecmp("MEASURE_H",optstr)==0) {
        sscanf(cmdstr,"%*s %lf",&global.measure_h);
      }
      else if(strcasecmp("NODES",optstr)==0) {
        sscanf(cmdstr,"%*s %d",&options.Nnode);
      }
      else if(strcasecmp("MIN_RAIN_TEMP",optstr)==0) {
        sscanf(cmdstr,"%*s %lf",&global.MIN_RAIN_TEMP);
      }
      else if(strcasecmp("MAX_SNOW_TEMP",optstr)==0) {
        sscanf(cmdstr,"%*s %lf",&global.MAX_SNOW_TEMP);
      }

      /********************
        Get Model Options
	******************/
      else if(strcasecmp("FULL_ENERGY",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) {
	  options.FULL_ENERGY=TRUE;
 	  options.QUICK_FLUX=TRUE;
	  options.GRND_FLUX=TRUE;
	}
	else options.FULL_ENERGY = FALSE;
      }
      else if(strcasecmp("FROZEN_SOIL",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) {
	  options.FROZEN_SOIL=TRUE;
	  options.QUICK_FLUX=FALSE;
	  options.GRND_FLUX=TRUE;
	}
        else options.FROZEN_SOIL = FALSE;
      }
      else if( (strcasecmp("NOFLUX",optstr)==0) || (strcasecmp("NO_FLUX",optstr)==0) ) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) options.NOFLUX=TRUE;
        else options.NOFLUX = FALSE;
      }
      else if(strcasecmp("DIST_PRCP",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) options.DIST_PRCP=TRUE;
        else options.DIST_PRCP = FALSE;
      }
      else if(strcasecmp("COMPRESS",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) options.COMPRESS=TRUE;
        else options.COMPRESS = FALSE;
      }
      else if(strcasecmp("CORRPREC",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) options.CORRPREC=TRUE;
        else options.CORRPREC = FALSE;
      }
      else if(strcasecmp("PRT_SNOW_BAND",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) options.PRT_SNOW_BAND=TRUE;
        else options.PRT_SNOW_BAND = FALSE;
      }
      else if(strcasecmp("GRID_DECIMAL",optstr)==0) {
        sscanf(cmdstr,"%*s %d",&options.GRID_DECIMAL);
      }
      else if(strcasecmp("SNOW_BAND",optstr)==0) {
	sscanf(cmdstr,"%*s %d %s",&options.SNOW_BAND,names->snowband);
      }
      else if(strcasecmp("BINARY_OUTPUT",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) options.BINARY_OUTPUT=TRUE;
        else options.BINARY_OUTPUT = FALSE;
      }
      else if(strcasecmp("ALMA_OUTPUT",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) options.ALMA_OUTPUT=TRUE;
        else options.ALMA_OUTPUT = FALSE;
      }
      else if(strcasecmp("PRT_HEADER",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) options.PRT_HEADER=TRUE;
        else options.PRT_HEADER = FALSE;
      }
      else if(strcasecmp("ARC_SOIL",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) options.ARC_SOIL=TRUE;
        else options.ARC_SOIL = FALSE;
      }
      else if(strcasecmp("SNOW_STEP",optstr)==0) {
	sscanf(cmdstr,"%*s %d",&options.SNOW_STEP);
      }
      else if(strcasecmp("ROOT_ZONES",optstr)==0) {
	sscanf(cmdstr,"%*s %d",&options.ROOT_ZONES);
      }
      else if(strcasecmp("PREC_EXPT",optstr)==0) {
	sscanf(cmdstr,"%*s %f",&options.PREC_EXPT);
      }
      else if(strcasecmp("MIN_WIND_SPEED",optstr)==0) {
	sscanf(cmdstr,"%*s %f",&options.MIN_WIND_SPEED);
      }
      else if(strcasecmp("GRND_FLUX",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) options.GRND_FLUX=TRUE;
        else options.GRND_FLUX = FALSE;
      }
      else if(strcasecmp("QUICK_FLUX",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) options.QUICK_FLUX=TRUE;
        else options.QUICK_FLUX = FALSE;
      }
      else if(strcasecmp("MOISTFRACT",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) options.MOISTFRACT=TRUE;
        else options.MOISTFRACT = FALSE;
      }
      else if (strcasecmp("ARNO_PARAMS", optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) {
          nrerror("Please change \"ARNO_PARAMS  TRUE\" to \"BASEFLOW  NIJSSEN2001\" in your global parameter file.");
        }
        else {
          nrerror("Please change \"ARNO_PARAMS  FALSE\" to \"BASEFLOW  ARNO\" in your global parameter file.");
        }
      }
      else if (strcasecmp("NIJSSEN2001_BASEFLOW", optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) {
          nrerror("Please change \"NIJSSEN2001_BASEFLOW  TRUE\" to \"BASEFLOW  NIJSSEN2001\" in your global parameter file.");
        }
        else {
          nrerror("Please change \"NIJSSEN2001_BASEFLOW  FALSE\" to \"BASEFLOW  ARNO\" in your global parameter file.");
        }
      }
      else if (strcasecmp("BASEFLOW", optstr)==0) {
        sscanf(cmdstr, "%*s %s", flgstr);
        if(strcasecmp("NIJSSEN2001",flgstr)==0) options.BASEFLOW=NIJSSEN2001;
        else options.BASEFLOW = ARNO;
      }
      else if(strcasecmp("INIT_STATE",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("FALSE",flgstr)==0) options.INIT_STATE=FALSE;
        else {
	  options.INIT_STATE = TRUE;
	  strcpy(names->init_state,flgstr);
	}
      }
      else if(strcasecmp("BINARY_STATE_FILE",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("FALSE",flgstr)==0) options.BINARY_STATE_FILE=FALSE;
	else options.BINARY_STATE_FILE=TRUE;
      }
      else if(strcasecmp("STATENAME",optstr)==0) {
        sscanf(cmdstr,"%*s %s",names->statefile);
        options.SAVE_STATE = TRUE;
      }
      else if(strcasecmp("STATEYEAR",optstr)==0) {
        sscanf(cmdstr,"%*s %d",&global.stateyear);
      }
      else if(strcasecmp("STATEMONTH",optstr)==0) {
        sscanf(cmdstr,"%*s %d",&global.statemonth);
      }
      else if(strcasecmp("STATEDAY",optstr)==0) {
        sscanf(cmdstr,"%*s %d",&global.stateday);
      }
      else if(strcasecmp("COMPUTE_TREELINE",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("FALSE",flgstr)==0) options.COMPUTE_TREELINE=FALSE;
        else {
	  options.COMPUTE_TREELINE = TRUE;
	  options.AboveTreelineVeg = atoi( flgstr );
	}
      }

      /************************************
        Get Forcing Data File Information
	**********************************/
      else if(strcasecmp("FORCING1",optstr)==0) {
        sscanf(cmdstr,"%*s %s",names->f_path_pfx[0]);
	file_num = 0;
	field=0;
      }
      else if(strcasecmp("FORCING2",optstr)==0) {
        sscanf(cmdstr,"%*s %s",names->f_path_pfx[1]);
	file_num = 1;
	field=0;
      }
      else if(strcasecmp("N_TYPES",optstr)==0) {
        sscanf(cmdstr,"%*s %d",&param_set.N_TYPES[file_num]);
      }
      else if(strcasecmp("FORCE_TYPE",optstr)==0) {
	get_force_type(cmdstr,file_num,&field);
      }
      else if(strcasecmp("FORCE_DT",optstr)==0) {
	sscanf(cmdstr,"%*s %d ", &param_set.FORCE_DT[file_num]);
      }
      else if (strcasecmp("FORCE_ENDIAN",optstr)==0) {
	sscanf(cmdstr, "%*s %s", flgstr);
	if (strcasecmp(flgstr, "LITTLE") == 0)
	  param_set.FORCE_ENDIAN[file_num] = LITTLE;
	else if (strcasecmp(flgstr, "BIG") == 0)
	  param_set.FORCE_ENDIAN[file_num] = BIG;
	else
	  nrerror("FORCE_ENDIAN must be either BIG or LITTLE.");
      }
      else if (strcasecmp("FORCE_FORMAT",optstr)==0) {
	sscanf(cmdstr, "%*s %s", flgstr);
	if (strcasecmp(flgstr, "BINARY") == 0)
	  param_set.FORCE_FORMAT[file_num] = BINARY;
	else if (strcasecmp(flgstr, "ASCII") == 0)
	  param_set.FORCE_FORMAT[file_num] = ASCII;
	else
	  nrerror("FORCE_FORMAT must be either ASCII or BINARY.");
      }
      else if(strcasecmp("ALMA_INPUT",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) options.ALMA_INPUT=TRUE;
        else options.ALMA_INPUT = FALSE;
      }

      /************************************
	Get Information for Parameter Files 
	************************************/
      
      else if(strcasecmp("SOIL",optstr)==0) {
        sscanf(cmdstr,"%*s %s",names->soil);
      }
      else if(strcasecmp("SOIL_DIR",optstr)==0) {
        sscanf(cmdstr,"%*s %s",names->soil_dir);
      }
      else if(strcasecmp("VEGPARAM",optstr)==0) {
        sscanf(cmdstr,"%*s %s",names->veg);
      }
      else if(strcasecmp("VEGLIB",optstr)==0) {
        sscanf(cmdstr,"%*s %s",names->veglib);
      }
      else if(strcasecmp("GLOBAL_LAI",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) options.GLOBAL_LAI=TRUE;
        else options.GLOBAL_LAI = FALSE;
      }
      else if(strcasecmp("RESULT_DIR",optstr)==0) {
        sscanf(cmdstr,"%*s %s",names->result_dir);
      }

      /************************************
        Get Output File Information
	**********************************/
      else if(strcasecmp("N_OUTFILES",optstr)==0) {
        ; // do nothing
      }
      else if(strcasecmp("OUTFILE",optstr)==0) {
        ; // do nothing
      }
      else if(strcasecmp("OUTVAR",optstr)==0) {
        ; // do nothing
      }

      /******************************
        Get Model Debugging Options
	****************************/

#if LINK_DEBUG
      else if(strcasecmp("PRT_FLUX",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) debug.PRT_FLUX=TRUE;
        else debug.PRT_FLUX = FALSE;
      }
      else if(strcasecmp("PRT_BALANCE",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) debug.PRT_BALANCE=TRUE;
        else debug.PRT_BALANCE = FALSE;
      }
      else if(strcasecmp("PRT_SOIL",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) debug.PRT_SOIL=TRUE;
        else debug.PRT_SOIL = FALSE;
      }
      else if(strcasecmp("PRT_VEGE",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) debug.PRT_VEGE=TRUE;
        else debug.PRT_VEGE = FALSE;
      }
      else if(strcasecmp("PRT_GLOBAL",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) debug.PRT_GLOBAL=TRUE;
        else debug.PRT_GLOBAL = FALSE;
      }
      else if(strcasecmp("PRT_ATMOS",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) debug.PRT_ATMOS=TRUE;
        else debug.PRT_ATMOS = FALSE;
      }
      else if(strcasecmp("PRT_SNOW",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) debug.PRT_SNOW=TRUE;
        else debug.PRT_SNOW = FALSE;
      }
      else if(strcasecmp("PRT_MOIST",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) debug.PRT_MOIST=TRUE;
        else debug.PRT_MOIST = FALSE;
      }
      else if(strcasecmp("PRT_TEMP",optstr)==0) {
        sscanf(cmdstr,"%*s %s",flgstr);
        if(strcasecmp("TRUE",flgstr)==0) debug.PRT_TEMP=TRUE;
        else debug.PRT_TEMP = FALSE;
      }
      else if(strcasecmp("DEBUG_DIR",optstr)==0) {
        sscanf(cmdstr,"%*s %s",debug.debug_dir);
      }
#endif

      /***********************************
        Unrecognized Global Parameter Flag
        ***********************************/
      else {
	fprintf(stderr,"WARNING: Unrecognized option in the global parameter file:\n\t%s is unknown - check your spelling\n", optstr);
      }
    }
    fgets(cmdstr,MAXSTRING,gp);
  }
  fclose(gp);

  /******************************************
    Check for undefined required parameters
  ******************************************/

  // Validate model time step
  if (global.dt == MISSING)
    nrerror("Model time step has not been defined.  Make sure that the global file defines TIME_STEP.");
  else if (global.dt < 1) {
    sprintf(ErrStr,"The specified model time step (%d) < 1 hour.  Make sure that the global file defines a positive number of hours for TIME_STEP.",global.dt);
    nrerror(ErrStr);
  }

  // Validate the output step
  if (global.out_dt == 0 || global.out_dt == MISSING) {
    global.out_dt = global.dt;
  }
  else if (global.out_dt < global.dt || global.out_dt > 24 || (float)global.out_dt/(float)global.dt != (float)(global.out_dt/global.dt)) {
    nrerror("Invalid output step specified.  Output step must be an integer multiple of the model time step; >= model time step and <= 24");
  }

  // Validate SNOW_STEP and set NR and NF
  if (global.dt < 24 && global.dt != options.SNOW_STEP)
    nrerror("If the model step is smaller than daily, the snow model should run\nat the same time step as the rest of the model.");
  if (global.dt % options.SNOW_STEP != 0 || options.SNOW_STEP > global.dt)
    nrerror("SNOW_STEP should be <= TIME_STEP and divide TIME_STEP evenly ");
  NF = global.dt/options.SNOW_STEP;
  if (NF == 1)
    NR = 0;
  else
    NR = NF;

  // Validate simulation start date
  if (global.startyear == MISSING)
    nrerror("Simulation start year has not been defined.  Make sure that the global file defines STARTYEAR.");
  else if (global.startyear < 0) {
    sprintf(ErrStr,"The specified simulation start year (%d) < 0.  Make sure that the global file defines a positive integer for STARTYEAR.",global.startyear);
    nrerror(ErrStr);
  }
  if (global.startmonth == MISSING)
    nrerror("Simulation start month has not been defined.  Make sure that the global file defines STARTMONTH.");
  else if (global.startmonth < 0) {
    sprintf(ErrStr,"The specified simulation start month (%d) < 0.  Make sure that the global file defines a positive integer for STARTMONTH.",global.startmonth);
    nrerror(ErrStr);
  }
  if (global.startday == MISSING)
    nrerror("Simulation start day has not been defined.  Make sure that the global file defines STARTDAY.");
  else if (global.startday < 0) {
    sprintf(ErrStr,"The specified simulation start day (%d) < 0.  Make sure that the global file defines a positive integer for STARTDAY.",global.startday);
    nrerror(ErrStr);
  }
  if (global.starthour == MISSING) {
    if (global.dt == 24)
      global.starthour = 0;
    else
      nrerror("Simulation start hour has not been defined, yet model time step is less than 24 hours.  Make sure that the global file defines STARTHOUR.");
  }
  else if (global.starthour < 0) {
    sprintf(ErrStr,"The specified simulation start hour (%d) < 0.  Make sure that the global file defines a positive integer for STARTHOUR.",global.starthour);
    nrerror(ErrStr);
  }

  // Validate simulation end date and/or number of timesteps
  if (global.nrecs == MISSING && global.endyear == MISSING && global.endmonth == MISSING && global.endday == MISSING)
    nrerror("The model global file MUST define EITHER the number of records to simulate (NRECS), or the year (ENDYEAR), month (ENDMONTH), and day (ENDDAY) of the last full simulation day");
  else if (global.nrecs == MISSING) {
    if (global.endyear == MISSING)
      nrerror("Simulation end year has not been defined.  Make sure that the global file defines ENDYEAR.");
    else if (global.endyear < 0) {
      sprintf(ErrStr,"The specified simulation end year (%d) < 0.  Make sure that the global file defines a positive integer for ENDYEAR.",global.endyear);
      nrerror(ErrStr);
    }
    if (global.endmonth == MISSING)
      nrerror("Simulation end month has not been defined.  Make sure that the global file defines ENDMONTH.");
    else if (global.endmonth < 0) {
      sprintf(ErrStr,"The specified simulation end month (%d) < 0.  Make sure that the global file defines a positive integer for ENDMONTH.",global.endmonth);
      nrerror(ErrStr);
    }
    if (global.endday == MISSING)
      nrerror("Simulation end day has not been defined.  Make sure that the global file defines ENDDAY.");
    else if (global.endday < 0) {
      sprintf(ErrStr,"The specified simulation end day (%d) < 0.  Make sure that the global file defines a positive integer for ENDDAY.",global.endday);
      nrerror(ErrStr);
    }
  }
  else if (global.nrecs < 1) {
    sprintf(ErrStr,"The specified duration of simulation (%d) < 1 time step.  Make sure that the global file defines a positive integer for NRECS.",global.nrecs);
    nrerror(ErrStr);
  }

  // Validate forcing files and variables
  if ( strcmp ( names->f_path_pfx[0], "MISSING" ) == 0 )
    nrerror("No forcing file has been defined.  Make sure that the global file defines FORCING1.");
  for(i=0;i<2;i++) {
    if ( i == 0 || (i == 1 && param_set.N_TYPES[i] != MISSING) ) {
      if (param_set.N_TYPES[i] == MISSING) {
	sprintf(ErrStr,"Need to specify the number forcing variables types in forcing file %d.", i);
	nrerror(ErrStr);
      }
      if (param_set.FORCE_FORMAT[i] == MISSING) {
	sprintf(ErrStr,"Need to specify the INPUT_FORMAT (ASCII or BINARY) for forcing file %d.",i);
	nrerror(ErrStr);
      }
      if (param_set.FORCE_INDEX[i][param_set.N_TYPES[i]-1] == MISSING) {
	sprintf(ErrStr,"Did not define enough forcing variables in forcing file %d.",i);
	nrerror(ErrStr);
      }
      if(param_set.FORCE_DT[i] == MISSING ) {
	sprintf(ErrStr,"Must define time steps (FORCE_DT <dt>) in control file for focing file %d.",file_num);
	nrerror(ErrStr);
      }
    }
  }
  if(param_set.N_TYPES[1] != MISSING && global.forceyear[1] == MISSING) {
    global.forceyear[1] = global.forceyear[0];
    global.forcemonth[1] = global.forcemonth[0];
    global.forceday[1] = global.forceday[0];
    global.forcehour[1] = global.forcehour[0];
    global.forceskip[1] = 0;
  }

  // Validate result directory
  if ( strcmp ( names->result_dir, "MISSING" ) == 0 )
    nrerror("No results directory has been defined.  Make sure that the global file defines the result directory on the line that begins with \"RESULT_DIR\".");

  // Validate soil parameter file information
  if ( strcmp ( names->soil, "MISSING" ) == 0 )
    nrerror("No soil parameter file has been defined.  Make sure that the global file defines the soil parameter file on the line that begins with \"SOIL\".");
  if (options.ARC_SOIL && strcmp ( names->soil_dir, "MISSING" ) == 0)
    nrerror("\"ARC_SOIL\" was specified as TRUE, but no soil parameter directory (\"SOIL_DIR\") has been defined.  Make sure that the global file defines the soil parameter directory on the line that begins with \"SOIL_DIR\".");

  /*******************************************************************************
    Validate parameters required for normal simulations but NOT for OUTPUT_FORCE
  *******************************************************************************/

#if !OUTPUT_FORCE

  // Validate veg parameter information
  if ( strcmp ( names->veg, "MISSING" ) == 0 )
    nrerror("No vegetation parameter file has been defined.  Make sure that the global file defines the vegetation parameter file on the line that begins with \"VEGPARAM\".");
  if ( strcmp ( names->veglib, "MISSING" ) == 0 )
    nrerror("No vegetation library file has been defined.  Make sure that the global file defines the vegetation library file on the line that begins with \"VEGLIB\".");
  if(options.ROOT_ZONES<0)
    nrerror("ROOT_ZONES must be defined to a positive integer greater than 0, in the global control file.");

  // Validate the elevation band file information
  if(options.SNOW_BAND > 1) {
    if ( strcmp ( names->snowband, "MISSING" ) == 0 ) {
      sprintf(ErrStr, "\"SNOW_BAND\" was specified with %d elevation bands, but no elevation band file has been defined.  Make sure that the global file defines the elevation band file on the line that begins with \"SNOW_BAND\" (after the number of bands).", options.SNOW_BAND);
      nrerror(ErrStr);
    }
    if(options.SNOW_BAND > MAX_BANDS) {
      sprintf(ErrStr,"Global file wants more snow bands (%d) than are defined by MAX_BANDS (%d).  Edit user_def.h and recompile.",options.SNOW_BAND,MAX_BANDS);
      nrerror(ErrStr);
    }
  }
  else if (options.SNOW_BAND <= 0) {
    sprintf(ErrStr,"Invalid number of elevation bands specified in global file (%d).  Number of bands must be >= 1.",options.SNOW_BAND);
    nrerror(ErrStr);
  }

  // Validate the input state file information
  if( options.INIT_STATE ) {
    if ( strcmp ( names->init_state, "MISSING" ) == 0 )
      nrerror("\"INIT_STATE\" was specified, but no input state file has been defined.  Make sure that the global file defines the input state file on the line that begins with \"INIT_STATE\".");
  }

  // Validate the output state file information
  if( options.SAVE_STATE ) {
    if ( strcmp ( names->statefile, "MISSING" ) == 0)
      nrerror("\"SAVE_STATE\" was specified, but no output state file has been defined.  Make sure that the global file defines the output state file on the line that begins with \"SAVE_STATE\".");
    if ( global.stateyear == MISSING || global.statemonth == MISSING || global.stateday == MISSING )  {
      sprintf(ErrStr,"Incomplete specification of the date to save state for state file (%s).\nSpecified date (yyyy-mm-dd): %04d-%02d-%02d\nMake sure STATEYEAR, STATEMONTH, and STATEDAY are set correctly in your global parameter file.\n", names->statefile, global.stateyear, global.statemonth, global.stateday);
      nrerror(ErrStr);
    }
    // Check for month, day in range
    lastvalidday = lastday[global.statemonth - 1];
    if ( global.statemonth == 2 ) {
      if ( (global.stateyear % 4) == 0 && ( (global.stateyear % 100) != 0 || (global.stateyear % 400) == 0 ) ){
        lastvalidday = 29;
      } 
    }
    if ( global.stateday > lastvalidday || global.statemonth > 12 || global.statemonth < 1 || global.stateday > 31 || global.stateday < 1 ){
      sprintf(ErrStr,"Unusual specification of the date to save state for state file (%s).\nSpecified date (yyyy-mm-dd): %04d-%02d-%02d\nMake sure STATEYEAR, STATEMONTH, and STATEDAY are set correctly in your global parameter file.\n", names->statefile, global.stateyear, global.statemonth, global.stateday);
      nrerror(ErrStr);
    }
  }
  // Set the statename here to be able to compare with INIT_STATE name
  if( options.SAVE_STATE ) {
    sprintf(names->statefile,"%s_%04i%02i%02i", names->statefile, 
	  global.stateyear, global.statemonth, global.stateday);
  }
  if( options.INIT_STATE && options.SAVE_STATE && (strcmp( names->init_state, names->statefile ) == 0))  {
      sprintf(ErrStr,"The save state file (%s) has the same name as the initialize state file (%s).  The initialize state file will be destroyed when the save state file is opened.", names->statefile, names->init_state);
      nrerror(ErrStr);
  }

  // Validate soil parameter/simulation mode combinations
  if(options.Nlayer > MAX_LAYERS) {
    sprintf(ErrStr,"Global file wants more soil moisture layers (%d) than are defined by MAX_LAYERS (%d).  Edit user_def.h and recompile.",options.Nlayer,MAX_LAYERS);
    nrerror(ErrStr);
  }
  if(options.Nnode > MAX_NODES) {
    sprintf(ErrStr,"Global file wants more soil thermal nodes (%d) than are defined by MAX_NODES (%d).  Edit user_def.h and recompile.",options.Nnode,MAX_NODES);
    nrerror(ErrStr);
  }
  if(options.QUICK_FLUX) {
    if((options.FULL_ENERGY || options.FROZEN_SOIL) && options.Nnode != 3) {
      sprintf(ErrStr,"To run the model in FULL_ENERGY or FROZEN_SOIL modes with QUICK_FLUX=TRUE, you must define exactly 3 soil thermal nodes.  Currently Nnodes is set to  %d.",options.Nnode);
      nrerror(ErrStr);
    }
    else if (!options.FULL_ENERGY && !options.FROZEN_SOIL && options.Nnode != 1) {
      sprintf(ErrStr,"To run the model with FULL_ENERGY=FALSE, FROZEN_SOIL=FALSE, and QUICK_FLUX=TRUE, you must define exactly 1 soil thermal node.  Currently Nnodes is set to  %d.",options.Nnode);
      nrerror(ErrStr);
    }
  }
  else {
    if(options.Nnode < 4) {
      sprintf(ErrStr,"To run the model with QUICK_FLUX=FALSE, you must define at least 4 soil thermal nodes.  Currently Nnodes is set to%d.",options.Nnode);
      nrerror(ErrStr);
    }
  }
  if((options.FULL_ENERGY || options.FROZEN_SOIL) && options.Nlayer<3) {
    sprintf(ErrStr,"You must define at least 3 soil moisture layers to run the model in FULL_ENERGY or FROZEN_SOIL modes.  Currently Nlayers is set to  %d.",options.Nlayer);
    nrerror(ErrStr);
  }
  if((options.FULL_ENERGY || options.FROZEN_SOIL) && options.Nlayer<3) {
    sprintf(ErrStr,"You must define at least 3 soil moisture layers to run the model in FULL_ENERGY or FROZEN_SOIL modes.  Currently Nlaeyrs is set to  %d.",options.Nlayer);
    nrerror(ErrStr);
  }

  /*********************************
    Output major options to stderr
  *********************************/
#if VERBOSE
  display_current_settings(DISP_ALL,names,&global);
#else
  display_current_settings(DISP_VERSION,names,&global);
#endif

#if VERBOSE
  fprintf(stderr,"Time Step = %i hour(s)\n",global.dt);
  fprintf(stderr,"Simulation start date = %02i/%02i/%04i\n",
	  global.startday, global.startmonth, global.startyear);
  if ( global.nrecs > 0 )
    fprintf(stderr,"Number of Records = %i\n\n",global.nrecs);
  else 
    fprintf(stderr,"Simulation end date = %02i/%02i/%04i\n\n",
	    global.endday, global.endmonth, global.endyear);
  fprintf(stderr,"Full Energy...................(%i)\n",options.FULL_ENERGY);
  fprintf(stderr,"Use Distributed Precipitation.(%i)\n",options.DIST_PRCP);
  if(options.DIST_PRCP)
    fprintf(stderr,"..Using Precipitation Exponent of %f\n",options.PREC_EXPT);
  if ( options.GRND_FLUX ) {
    fprintf(stderr,"Ground heat flux will be estimated ");
    if ( options.QUICK_FLUX ) 
      fprintf(stderr,"using Liang, Wood and Lettenmaier (1999).\n");
    else 
      fprintf(stderr,"using Cherkauer and Lettenmaier (1999).\n");
  }
  else
    fprintf(stderr,"Ground heat flux not computed (no energy balance).\n");
  fprintf(stderr,"Use Frozen Soil Model.........(%i)\n",options.FROZEN_SOIL);
  if ( QUICK_FS )
    fprintf(stderr,".... Using linearized UFWC curve with %i temperatures.\n",
	    QUICK_FS_TEMPS);
  fprintf(stderr,"Run Snow Model Using a Time Step of %i hours\n", 
	  options.SNOW_STEP);
  fprintf(stderr,"Compress Output Files.........(%i)\n",options.COMPRESS);
  fprintf(stderr,"Correct Precipitation.........(%i)\n",options.CORRPREC);
  fprintf(stderr,"\n");
  fprintf(stderr,"Using %i Snow Bands\n",options.SNOW_BAND);
  fprintf(stderr,"Using %i Root Zones\n",options.ROOT_ZONES);
  if ( options.SAVE_STATE )
    fprintf(stderr,"Model state will be saved on = %02i/%02i/%04i\n\n",
	    global.stateday, global.statemonth, global.stateyear);
  if ( options.BINARY_OUTPUT ) 
    fprintf(stderr,"Model output is in standard BINARY format.\n");
  else 
    fprintf(stderr,"Model output is in standard ASCII format.\n");
  if ( LINK_DEBUG ) 
    fprintf(stderr,"Debugging code has been included in the executable.\n");
  else 
    fprintf(stderr,"Debugging code has not been compiled.\n");
#endif // VERBOSE

#endif // !OUTPUT_FORCE

  return global;
  
}
