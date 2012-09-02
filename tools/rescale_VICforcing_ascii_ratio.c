#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#define SCALE 2 // scaling ratio as defines by the difference in the runoff/precip ratios
#define LEAPYR(y) (!((y)%400) || (!((y)%4) && ((y)%100)))

/************************************************************
Author: Nathalie Voisin
rescale VIC forcing - precip during winter time
************************************************************/
int main(int argc, char** argv)
{
int v,k,cell, cell2;
char    outputdir[100], outputfile[150], latlongfile[150], inputdir[150], inputfile[150],junk[5], maskfile[150];
FILE    *outfile, *llfile, *infile, *ratiof;
char    latchar[10], lonchar[10];
float   lat, lon, *ratio, *ltratio, *lnratio, val;
float   precip, tmin, tmax, wind, nwprecip;
int	cellnum;
int NCELLDOWN,NCELL2, STYR, NDYR, MAXNRECSDAY;

int dpm[13] = { 0,31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
int yr,mo,da;

/************* CHECK CMD LINE *****************************/
if(argc != 9)
  {
  printf("Usage: rewriteVICinputfile <inputdir> <outputdir> <Start year> <End year> <Number of days> <lat long file><NCELLDOWN><ratiofile> \n");
  exit (0);
  }
sscanf(argv[1]," %s",inputdir);
sscanf(argv[2]," %s", outputdir);
sscanf(argv[3]," %d",&STYR);
sscanf(argv[4]," %d",&NDYR);
sscanf(argv[5]," %d",&MAXNRECSDAY);
sscanf(argv[6]," %s",latlongfile);
sscanf(argv[7]," %d",&NCELLDOWN);
sscanf(argv[8]," %s",maskfile);

ratio = (float*)calloc(NCELLDOWN,sizeof(float));
ltratio = (float*)calloc(NCELLDOWN,sizeof(float));
lnratio = (float*)calloc(NCELLDOWN,sizeof(float));

  if ( (ratiof = fopen(maskfile,"r")) == NULL ) {
    fprintf(stderr,"Could not open %s , exit\n", maskfile);
    exit(-1);
  }
  cell=-1;
  while (!feof(ratiof)){
    if ( fscanf(ratiof,"%f %f %f \n", &lon, &lat , &val )==3){
      cell++;
      if ( cell < NCELLDOWN) {
        ratio[cell]=val;
        ltratio[cell] = lat;
        lnratio[cell] = lon;
      }
    }
  }
  fclose(ratiof);
   NCELL2 = cell++;
  fprintf(stderr,"Read %d cell in the ratio files\n",NCELL2);
  


/******************************************/
  if ( (llfile = fopen(latlongfile,"r")) == NULL){
    fprintf(stderr,"Could not open %s , exit\n", latlongfile);
    exit(-1);
  }

  sprintf(junk, "%%.%if", 4);
  for (cell=0;cell<NCELLDOWN;cell++){
    if ( cell%1000 == 0) fprintf(stdout,"writing down temporary files cell %d out if %d\n",cell,NCELLDOWN);
    //.. read the lat long of the cell
    if ( fscanf(llfile,"%f %f\n", &lat, &lon )==2){
      sprintf(latchar, junk, lat);
      sprintf(lonchar, junk, lon);
      //.. create file name
      strcpy(outputfile, outputdir);
      strcat(outputfile, "/data_");
      strcat(outputfile, latchar);
      strcat(outputfile, "_");
      strcat(outputfile, lonchar);
      //.. input file nme
      strcpy(inputfile, inputdir);
      strcat(inputfile, "/data_");
      strcat(inputfile, latchar);
      strcat(inputfile, "_");
      strcat(inputfile, lonchar);

      if ( (outfile= fopen(outputfile, "w")) == NULL){
        fprintf(stderr,"Could not open %s , exit\n", outputfile);
        exit(-1);
      }
      if ( (infile= fopen(inputfile, "r")) == NULL){
        fprintf(stderr,"Could not open %s , exit\n", inputfile);
        exit(-1);
      }

      val=1;
      for ( cell2=0;cell2<NCELL2;cell2++){
        if ( ltratio[cell2] == lat && lnratio[cell2]== lon ) {
          val = 1/ratio[cell2]; // ratios are Maurer/PRISM
          fprintf(stderr,"found match %f %f %d %f\n",lat, lon,cell, val);
        }
      }
      for (k=0;k<MAXNRECSDAY;k++){
      //k=0;
      //for (yr=STYR;yr<=NDYR;yr++){
      //if ( LEAPYR(yr)) dpm[2]=29;
      //else dpm[2]=28;
      //for (mo=1;mo<13;mo++){
      //for ( da=1;da<=dpm[mo];da++){
        //fprintf(stderr,"Day is %d\n",k);
	//k++;
        
        //.. read in the inputfile
        if ( fscanf(infile,"%f %f %f %f \n",&precip,&tmax, &tmin, &wind) != 4 ) {
          fprintf(stderr,"Error reading infile\n");
          exit(-1);
        }

        nwprecip = precip*val;
        fprintf(outfile,"%.2f %.2f %.2f %.2f\n",nwprecip, tmax, tmin, wind);
        }}} // end of time loop
        if ( k != MAXNRECSDAY ) {
          fprintf(stderr,"read %d rec out of %d\n",k,MAXNRECSDAY);
          exit(-1);
        }
      } //.. end of if
    fclose(outfile);
    fclose(infile);
    outfile=NULL;
    infile=NULL;
    } //.. end of cell
fclose(llfile);
llfile=NULL;
free(ratio);
free(ltratio);
free(lnratio);


}
