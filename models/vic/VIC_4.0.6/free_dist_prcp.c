#include <stdio.h>
#include <stdlib.h>
#include <vicNl.h>
 
static char vcid[] = "$Id: free_dist_prcp.c,v 4.1.2.1 2007/04/24 19:38:20 vicadmin Exp $";

void free_dist_prcp(dist_prcp_struct *prcp, 
		    int               Nveg)
/**********************************************************************
	free_dist_prcp	Keith Cherkauer		March 1998

  This routine frees all memory allocated down the distributed 
  precipitation data structure.  This include all grid cell specific
  variables (soil, vegetation, energy, snow).

  modifications:
  06-24-98 modified to account for redesign of distributed precipitation
           data structures                                          KAC
  2007-Apr-23 Added freeing of mu.					TJB

**********************************************************************/
{
  extern option_struct options;

  int Ndist;
  int i, j;

  Ndist = 2;

  for(i=0;i<Ndist;i++) {
    for(j=0;j<=Nveg;j++) {
      free((char *)prcp[0].cell[i][j]);
    }
    free((char *)prcp[0].cell[i]);
    for(j=0;j<Nveg;j++) 
      free((char *)prcp[0].veg_var[i][j]);
    free((char *)prcp[0].veg_var[i]);
  }
  for(j=0;j<=Nveg;j++) {
    free((char *)prcp[0].energy[j]);
  }
  free((char *)prcp[0].energy);
  for(i=0;i<=Nveg;i++)
    free((char *)prcp[0].snow[i]);
  free((char *)prcp[0].snow);
  free((char *)prcp[0].mu);

}
