/* convert daily file to monthly */
/* tailored to read VIC ensemble 9 ASCII output fields (afer date) --*/
/* input:
FLUXFILE FORMAT:  (this code)
year, month, day, prec, evap, runoff, baseflow, air_temp, 
                  moist[1], moist[2], moist[3], swe(mm)

// Shrad Edited this script on 20110518, to read a flux file with 14 columns
//2 additional columns represent flux variables Net radiation and relative humidity
outputs: total p, et, ro, bf; average t air, moist1-3, swe 

Author: A.Wood */

#include <stdio.h>
#include <stdlib.h>

#define MAXRECS 50000
#define LEAPYR(y) (!((y)%400)) || (!((y%4) && ((y)%100)))

int main(int argc, char *argv[]) 
{
 int syear, smo, sday, mo,year,lines,day;
 //float dly[MAXRECS][9], year_mo,dec_mo;
 float dly[MAXRECS][11], year_mo,dec_mo; // Array size for dly flux variables has been extended to 11; we don't care about the last 2 variables Shrad 20110518
 float monthly[(int)(MAXRECS/30)+12][9]; //9 is for output fields
 int DaysInMonth[] = {0,31,28,31,30,31,30,31,31,30,31,30,31};
 int cnt, n, offset, pstartmon, pendmon, cmo, i, y;
 FILE *fpinp, *fpout;

 if(argc!=6) {
   printf("\tThis routine reformats special VIC daily output into month summary files\n");
   printf("Usage: %s <dly infile> <mon outfile> <pstartmon> <pendmon> <lines>\n",argv[0]);
   printf("\tpstartmon, pendmon:  define period to print monthly summaries\n");
   printf("\tmonthly summaries have p, et, ro, bf, tavg, moist1-3, swe\n");
   exit(0);
 }
 if((fpinp=fopen(argv[1],"r"))==NULL) {
   printf("ERROR: Unable to open %s\n",argv[1]);
   exit(0);    }

 if((fpout=fopen(argv[2],"w"))==NULL) {
   printf("ERROR: Unable to open %s\n",argv[2]);
   exit(0);    }
 pstartmon = atoi(argv[3]);
 pendmon = atoi(argv[4]);
 lines = atoi(argv[5]);

 // initialize
 for(n=0;n<(int)(MAXRECS/30)+12;n++)   
   for(i=0;i<9;i++) 
     monthly[n][i] = 0;

 for(n=0;n<lines;n++)   {
   //get new data
   fscanf(fpinp,
     "%d %d %d %f %f %f %f %f %f %f %f %f %f %f",
     &year, &mo, &day, 
     &dly[n][0],&dly[n][1],&dly[n][2],&dly[n][3],
     &dly[n][4],&dly[n][5],&dly[n][6],&dly[n][7],&dly[n][8],&dly[n][9], &dly[n][10]);

   if(n==0) {
     offset = cnt = day-1;
     syear=year;
     smo=mo;
     cmo=mo;
   }
   if(LEAPYR(year))
     DaysInMonth[2]=29;
   else
     DaysInMonth[2]=28;
   cnt++;

   for(i=0;i<9;i++) 
     monthly[cmo][i] += dly[n][i];   /* add the new flow */

   if(mo == 12 && day == 31)  {       // if the end of the year ... 
     //     printf("done with year %d\n",year);
     for(i=4;i<9;i++) 
       monthly[cmo][i] = monthly[cmo][i]/(cnt-offset);   //avg monthly
     offset = 0;
     cnt = 0;
     cmo++;

   } else if (day == DaysInMonth[mo])  {  // if the end of the month 
     for(i=4;i<9;i++) 
       monthly[cmo][i] = monthly[cmo][i]/(cnt-offset);  // avg monthly
     cnt = 0;
     offset = 0;
     cmo++;
   }

 }   /* end of aggregating loop */

 if (cnt > 0)  {       /* last value maybe not averaged yet */
   for(i=4;i<9;i++) 
     monthly[cmo][i] = monthly[cmo][i]/(cnt-offset);    //  month averages
   cmo++;
 }

/* now write out monthly file */

 for(y=syear;y<year+1;y++) {
   fprintf(fpout, "%d\t",y);
   for(mo=1;mo<13;mo++) 
     if(mo >= pstartmon && mo <= pendmon) { //print output
       cmo = (y-syear)*12+mo;
       fprintf(fpout,"%7.3f ",monthly[cmo][0]); 
       for(i=1;i<5;i++) 
         fprintf(fpout,"%6.3f ",monthly[cmo][i]); 
       for(i=5;i<9;i++) 
         fprintf(fpout,"%6.1f ",monthly[cmo][i]); 
       fprintf(fpout, "\t");
     }
   fprintf(fpout, "\n");
 }

 fclose(fpout);
 fclose(fpinp);
}

