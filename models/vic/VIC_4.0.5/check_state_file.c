#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <vicNl.h>

static char vcid[] = "$Id: check_state_file.c,v 4.2.2.3 2004/07/14 23:03:11 tbohn Exp $";

FILE *check_state_file(char                *init_state,
		       dmy_struct          *dmy,
		       global_param_struct *global,
		       int                  Nlayer,
		       int                  Nnodes,
		       int                 *startrec) 
/*********************************************************************
  check_state_file      Keith Cherkauer           April 17, 2000

  This subroutine opens a model state file and verifys that the 
  starting date, number of layers and number of thermal nodes in the 
  file agrees with what was defined in the model global control file.

  Modifications:
  04-10-03 modified to open and read from a binary state file.    KAC
  04-10-03 modified to compute record where state file starts,
           this allows VIC to read in the full array of atmospheric
           forcing data but start the simulation at the same time
           step as the state file.  This should eliminate the 
           problems associated with restarting the model with an 
           incomplete record of forcing data, which can lead to 
           differences in the interpolated sub-daily forcings.    KAC
  06-03-03 modified to handle both ASCII and BINARY state files.  KAC
  14-Jul-04 Removed adjustment of startrec.  The starting record will
	    always be the beginning of the interval specified in the
	    global file, rather than the date of the state file. This
	    means that now you can start your simulation at a date
	    other than the date when the state file was saved.	TJB

*********************************************************************/
{
  extern option_struct options;

  FILE   *statefile;
  char    filename[MAXSTRING];
  char    ErrStr[MAXSTRING];
  double  Nsum;
  int     tmp_Nlayer;
  int     tmp_Nnodes;
  int     startday, startmonth, startyear;

  /* open state file */
  if ( options.BINARY_STATE_FILE )
    statefile = open_file(init_state,"rb");
  else 
    statefile = open_file(init_state,"r");

  /* Initialize startrec */
  *startrec = 0;

  /* Check state date information */
  if ( options.BINARY_STATE_FILE ) {
    fread( &startyear, 1, sizeof(int), statefile );
    fread( &startmonth, 1, sizeof(int), statefile );
    fread( &startday, 1, sizeof(int), statefile );
  }
  else {
    fscanf(statefile,"%i %i %i\n", &startyear, &startmonth, &startday );
  }

  /* Check simulation options */
  if ( options.BINARY_STATE_FILE ) {
    fread( &tmp_Nlayer, 1, sizeof(int), statefile );
    fread( &tmp_Nnodes, 1, sizeof(int), statefile );
  }
  else {
    fscanf(statefile,"%i %i\n", &tmp_Nlayer, &tmp_Nnodes);
  }
  if ( tmp_Nlayer != Nlayer ) {
    sprintf(ErrStr,"The number of soil moisture layers in the model state file (%i) does not equal that defined in the global control file (%i).  Check your input files.", tmp_Nlayer, Nlayer);
    nrerror(ErrStr);
  }
  if ( tmp_Nnodes != Nnodes ) {
    sprintf(ErrStr,"The number of soil thermal nodes in the model state file (%i) does not equal that defined in the global control file (%i).  Check your input files.", tmp_Nnodes, Nnodes);
    nrerror(ErrStr);
  }

  return(statefile);

}
