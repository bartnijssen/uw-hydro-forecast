/**************************************************************************
*
*  This program is a filter that takes as input a file of monthly
*  precipitation data in the Global Historic Climate format and  
*  outputs monthly precipitation in SPI format.
*
*
*   Input format:
*        Data- stanumyyyy jan_prec feb_prec ... dec_prec
*
*        Where:
*            stanum - Station ID
*            yyyy - year
*
*            prec - precipitation (in 0.1s mm)
*                Special codes:
*                    -9999 = missing
*
*   Output format:
*        Header
*        Data- yyyy mm prec
*
*        Where:
*            yyyy - year; 
*            mm   - month [1-12]
*            prec - precipitation (in 0.01's)
*
*        Special codes:
*            -9900 = Missing
*
************************************************************************/

#include <stdio.h>
#include <ctype.h>
#include <string.h>
#define MISSING -9900

main ()
{
  char line[100];
  int n, iy, im;
  int prc[12];

  /* Copy header line */
  fgets(line, 90, stdin);
  line[strlen(line)-1] = '\0';
  puts(line);

  while (scanf("%10d%4d%5d%5d%5d%5d%5d%5d%5d%5d%5d%5d%5d%5d", &n, &iy, 
	       &prc[0], &prc[1], &prc[2], &prc[3], &prc[4], &prc[5], 
	       &prc[6], &prc[7], &prc[8], &prc[9], &prc[10], &prc[11]) == 14)
    {
      for(im=0; im<12; im++)
	{
	  if(prc[im] == -9999) prc[im] = MISSING;
	  printf("%4d %2d %6d\n", iy, im+1, prc[im]);
	}
    }
}











