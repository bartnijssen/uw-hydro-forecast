/**************************************************************************
*
*  Read monthly prec data.  
*
**************************************************************************/

#include <ctype.h>
#include <string.h>
#include "spi.h"

/************************************************************************
*
*   Format:
*        Header
*        Data- yyyy mm prec
*
*        Where:
*            yyyy - year; values > ENDYR and < BEGYR will be skipped.
*            mm   - month [1-12]
*            prec - precipitation (in 0.01's)
*
*        Special codes:
*            -9900 = Missing
*
************************************************************************/

int     rd_prec(char *header, double prec[NYRS][12], FILE *in_prec)
{
  int     n, iy, im, prc;

  /* Set prec array to MISSING */
  for(iy=0; iy<NYRS; iy++)
    for(im=0; im<12; im++)
      prec[iy][im] = MISSING;
  
  fgets(header, 90, in_prec); /* read header line */
  header[strlen(header)-1] = '\0';

  for (n=0; scanf("%d %d %d", &iy, &im, &prc) == 3; )
    {
      iy -= BEGYR;
      im--;
      if(iy < 0) continue;  /* Skip if before beginning year. */
      if(iy > NYRS-1) break;  /* Quit if we've gone past ENDYR */
      prec[iy][im] = prc/100.0;
      n++;
    }
  return (n);
}


