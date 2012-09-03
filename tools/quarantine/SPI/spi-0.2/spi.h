#include <stdlib.h>
#include <stdio.h>
#include <math.h>


/***********************************************************************
*
*  We use a fixed length arrays of record for precip and SPI
*  storage.  The length of these arrays is controlled by BEGYR
*  and ENDYR.  Adjust them if the period of record is longer or
*  shorter or if memory is in short supply.
*
*************************************************************************/
#define BEGYR  1915
#define ENDYR  2007
#define NYRS (ENDYR - BEGYR + 1)

/*******************************************************************
*
*  Define USE_EMPIRIC if you want to use actual data CDF rather than gamma
*  fit.
*
********************************************************************/

/*#define USE_EMPIRIC*/

#define MISSING -99.0

#define SQR(a) ((a)*(a))

/* Prototypes */

int     rd_prec ();
void spi_gamma (int nrun, double *pp, double *beta, double *gamm, 
		double *pzero, double *index);






