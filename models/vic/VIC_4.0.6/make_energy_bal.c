#include <stdio.h>
#include <stdlib.h>
#include <vicNl.h>
 
static char vcid[] = "$Id: make_energy_bal.c,v 4.1.2.1 2005/11/10 18:59:37 vicadmin Exp $";

energy_bal_struct **make_energy_bal(int nveg)
/**********************************************************************
	make_energy_bal	Keith Cherkauer		May 26, 1996

  This routine makes an array of frozen soil data structures, one 
  for each vegetation type and bare soil.

Modifications

  2005-11-09 (Port from 4.1.0) Removed modification of Nnodes, as this was preventing
            correct reading/writing of state files for QUICK_FLUX=TRUE. GCT
**********************************************************************/
{
  extern option_struct options;

  int i, j;
  energy_bal_struct **temp;

  temp = (energy_bal_struct**) calloc(nveg, 
				      sizeof(energy_bal_struct*));

  /** Initialize all records to unfrozen conditions */
  for(i = 0; i < nveg; i++) {
    temp[i] = (energy_bal_struct*) calloc(options.SNOW_BAND, 
					  sizeof(energy_bal_struct));
    for(j = 0; j < options.SNOW_BAND; j++) {
      temp[i][j].frozen = FALSE;
    }
  }

  return temp;
}
