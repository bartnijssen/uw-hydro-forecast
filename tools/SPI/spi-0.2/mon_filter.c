/**************************************************************************
*
*  This program is a filter that takes as input a file of monthly
*  precipitation and temperature data in the '.mon' format and  
*  outputs monthly precipitation in SPI format.
*
*
*   Input format:
*        Header
*        Data- yyyymm temp prec
*
*        Where:
*            yyyy - year
*            mm   - month
*            temp - temperature
*                Special codes:
*                   19999 = more than 9 days missing
*                   10000 + value = 1-9 days missing
*                   99999 = missing value
*
*            prec - precipitation (in 0.01's)
*                Special codes:
*                    99999 = missing
*                    99998 = trace
*                            99997 = accumulated period
*                   199998 = estimated trace
*                   100000 + value = estimated value
*                   200000 + value = interpolated value
*                   399998 = accumulated trace
*                   300000 + value = accumulated value
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
  int  iy, im;
  int temp, prc;

  /* Copy header line */
  fgets(line, 90, stdin);
  line[strlen(line)-1] = '\0';
  puts(line);

  while (scanf("%d %d %d", &iy, &temp, &prc) == 3)
    {
      im = (iy%100);
      iy /= 100;

      /* Throw away all codes except missings */
      prc %= 10000; 
      if(prc == 9998) prc = 0;
      if(prc == 9997) prc = MISSING;
      if(prc == 9999) prc = MISSING;

      printf("%4d %2d %6d\n", iy, im, prc);
    }
}











