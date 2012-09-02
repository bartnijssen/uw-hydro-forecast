/*      PROGRAM rout, C-version   

     Routing algorithm developed by D. Lohmann.
     Modified to allow more flexible array dimensions and
     the removal of harcoded file names.  
     Rewritten from FORTRAN to C 2003, AWW/IH.
      
     MAXROWS and MAXCOLS should be larger than the grid
     MAXYEARS should equal at least run length yrs+1   
     i: row from bottom (starts at 1)
     j: col from bottom (starts at 1)
     [][]: [row][col]
     Indexing (arrays): Starts at 1 (i.e. 0 is left unused)
*/

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <float.h>
#include <math.h>
#include <string.h>

/*************************************************************/
/* Change if needed                                          */
/*************************************************************/
#define MAXROWS 300
#define MAXCOLS 300
#define MAXYEARS 100
#define MAXSTNS 100
/*************************************************************/
/* No changes after here                                     */
/*************************************************************/
#define DAYS   MAXYEARS*366
#define KE     12              //number of steps in uh_file 
#define LE     48              //?? impulse response function. 
                               //number tken from f-version,
                               //but I haven't figured out why 
                               //it is 48.........   
#define DELTA_T 3600.0
#define UH_DAY 96              //max days to outlet 
#define TMAX   UH_DAY*24
#define MAX_CELLS_IN_BASIN 5000   
#define MAXSTRING 512
#define NODATA -9999
#define PI 4.0*atan(1.0)       //pi!
#define EPS 1e-6               //precision
#define EARTHRADIUS 6371.229;  //radius of earth in kilometers

#define MIDSTRING   100
/*************************************************************/
/* TYPE DEFINITIONS, GLOBALS, ETC.                           */
/*************************************************************/
typedef enum {double_f, int_f, float_f, long_f, short_f} FORMAT_SPECIFIER;

typedef struct {
  int id;
  int ntypes;
  int direction;
  int tocol;
  int torow;
  float fraction;
  float velocity;
  float xmask;
  float diffusion;
} ARC;

typedef struct {
  int id;
  int col;
  int row;
  float area;
  char name[20];
} LIST;

typedef struct {
  int year;
  int month;
  int day;
} TIME;
/*************************************************************/
void CalculateNumberDaysMonths(int,int,int,int,int *,int *);
void FindRowsCols(char *, int *, int *, float *, 
		   float *, float *); 
int IsLeapYear(int);
void MakeConvolution(int,int,int,int **,ARC **,
		     float *,float *, float *,float **,
		     LIST *,float,float,float,
		     char *,char *,int,TIME *,float *,int,int,int,int);
void MakeGridUH(ARC **,int **,LIST *,
		int,int,float **,float ***,float **,float **,
		float **,char *);
void MakeUH(float ***UH, ARC **, int, int);
void ReadDiffusion(char *, ARC **, int, int); 
void ReadDirection(char *, ARC **, int, int, int *); 
void ReadFraction(char *, ARC **, int, int); 
void ReadGridUH(char *, float **UH_BOX, int);
void ReadStation(char *,LIST *,char uhstring[MAXSTNS][MIDSTRING],int *);
void ReadVelocity(char *, ARC **, int, int); 
void ReadXmask(char *, ARC **, int, int); 
void SearchCatchment(ARC **,int **,
		     int,int,int,int,int *);
void WriteData(float *,char *,char *,TIME *,float,int,int,int,int,int,int);
/*************************************************************/
/* Start of ROUT                                             */
/*************************************************************/
int main (int argc, char *argv[]) {   

  FILE *fp;

  ARC **BASIN=NULL; //Grid input information is stored here,
                    //like direction,fraction,velocity of 
                    //each cell in the grid. Row(i) is row from
                    //the bottom, col(j) is column from the left.
                    //Numbering starts at 1 for both i and j.
  LIST *STATION=NULL;    //Holds information about station locations and names.
                    //Area is included in the list, although the value
                    //isn't used in the routing program.
  TIME *DATE=NULL;

  char *filename;
  char *spinuppath;
  char *inpath;
  char *outpath;
  char *dummy;
  char *name;
  char uhstring[MAXSTNS][MIDSTRING]; //name of uhfile (or "NONE")
  char none[5]="NONE";

  float xllcorner; //x-coordinate, lower left corner of grid
  float yllcorner; //y-coordinate, lower left corner of grid
  float size;      //size of grid cell, in degrees
  float value;
  float factor_sum;
  float ***UH;     //impulse response function UH[row][col][1-48]
  float **UH_BOX;  //unit hydrograph[1-number_of_cells][1-12]. 
                   //hm, why one for each cell?
  float **UH_DAILY;
  float **UH_S;
  float **FR;
  float *BASEFLOW;  
  float *RUNOFF;
  float *FLOW;


  int **CATCHMENT; //a list with row and col number for all cells upstream 
                   //station location. CATCHMENT[cellnumber][row(0)/col(1)]
                   //the order of the list is arbitrary. I should change this
                   //so that the most upstream is first?
  int *MONTH;
  int *YEAR;
  int i,j;
  int nrows,ncols;     //number of rows/columns in basin (read from direction file)
  int active_cells;    //total number of active cells in grid
  int number_of_cells; //number of cells upstream a station location
  int number_of_stations; //number of stations 
  int decimal_places;  //decimal places in VIC output 
  int spinup_start_year,spinup_start_month; //start of spinup
  int spinup_stop_year,spinup_stop_month;
  int start_year,start_month; //start of VIC simulation
  int stop_year,stop_month;
  int first_year,first_month; //start of output to be written
  int last_year,last_month;
  int ndays,spinup_days,nmonths;   //number of days and months in spinup and VIC simulations 
                       //what about skipping whatever is 
                       //before/after the period of interest?
  int mn1, mn2;        // temporally variables

  /***********************************************************/

  if(argc != 2){
   printf("USAGE:  rout <infile>\n");
   exit(0);
  }
  if((fp = fopen(argv[1], "r")) == NULL) {
   printf("Cannot open %s\n",argv[1]);
   exit(1);
  }

  /* Allocate memory for input parameters/names */
  filename = (char*)calloc(100,sizeof(char));
  spinuppath = (char*)calloc(100,sizeof(char));
  inpath = (char*)calloc(100,sizeof(char));
  outpath = (char*)calloc(100,sizeof(char));
  dummy = (char*)calloc(100,sizeof(char));
  name = (char*)calloc(100,sizeof(char));

  /* Find number of rows and cols in grid of interest */
  fgets(dummy, MAXSTRING, fp);
  fscanf(fp, "%*s %s",filename);
  FindRowsCols(filename,&nrows,&ncols,&xllcorner,&yllcorner,&size);

  /* Allocate memory for BASIN, UH, FR */
  BASIN=calloc(nrows+1,sizeof(ARC));
  for(i=0;i<=nrows;i++) 
      BASIN[i]=calloc(ncols+1,sizeof(ARC));
  UH = (float***)calloc(nrows+1,sizeof(float**));
  for(i=0;i<=nrows;i++) {
    UH[i]=(float**)calloc(ncols+1,sizeof(float*));
    for(j=0;j<=ncols;j++) 
      UH[i][j]=(float*)calloc(LE+1,sizeof(float*));      
  }  
  FR = (float**)calloc(TMAX+1,sizeof(float*));
  for(i=0;i<=TMAX;i++) 
     FR[i]=(float*)calloc(2,sizeof(float));

  /* Read direction file */
  printf("Direction file: %s\n",filename);
  ReadDirection(filename,BASIN,nrows,ncols,&active_cells);
  printf("Active cells in basin: %d\n",active_cells);

  /* Allocate memory for CATCHMENT, UH_BOX, UH_S, UH_DAILY, STATION */
  CATCHMENT = (int**)calloc(active_cells+1,sizeof(int*));
  for(i=0;i<=active_cells;i++) 
    CATCHMENT[i]=(int*)calloc(2,sizeof(int));
  UH_BOX=(float**)calloc(active_cells+1,sizeof(float*));
  for(i=0;i<=active_cells;i++) 
      UH_BOX[i]=(float*)calloc(KE+1,sizeof(float*));      
  UH_DAILY=(float**)calloc(active_cells+1,sizeof(float*));
  for(i=0;i<=active_cells;i++) 
      UH_DAILY[i]=(float*)calloc(UH_DAY+1,sizeof(float));      
  UH_S=(float**)calloc(active_cells+1,sizeof(float*));
  for(i=0;i<=active_cells;i++) 
      UH_S[i]=(float*)calloc(KE+UH_DAY+1,sizeof(float));      
  STATION=calloc(MAXSTNS,sizeof(LIST));
  DATE=calloc(DAYS,sizeof(TIME));

  /* Read velocity file if any */
  fscanf(fp, "%*s %s",filename);
  value=atof(filename);
  if(value<EPS) ReadVelocity(filename,BASIN,nrows,ncols);
  else {
    printf("Velocity: %.2f\n",value);
    for(i=1;i<=nrows;i++) 
      for(j=1;j<=ncols;j++) 
	BASIN[i][j].velocity=value;
  }

  /* Read diffusion file */
  fscanf(fp, "%*s %s",filename);
  value=atof(filename);
  if(value<EPS) ReadDiffusion(filename,BASIN,nrows,ncols);
  else {
    printf("Diffusion: %.2f\n",value);
    for(i=1;i<=nrows;i++)
      for(j=1;j<=ncols;j++) 
        BASIN[i][j].diffusion=value;
  }

  /* Read xmask file */
  fscanf(fp, "%*s %s",filename);
  value=atof(filename);
  if(value<EPS) ReadXmask(filename,BASIN,nrows,ncols);
  else {
    printf("Xmask: %.2f\n",value);
    for(i=1;i<=nrows;i++)
      for(j=1;j<=ncols;j++) 
        BASIN[i][j].xmask=value;
  }


  /* Read fraction file */
  fscanf(fp, "%*s %s ",filename);
  printf("Fraction file: %s\n",filename);
  ReadFraction(filename,BASIN,nrows,ncols);

  /* Read station file */
  fscanf(fp, "%*s %s",filename);
  printf("Station file: %s\n",filename);
  ReadStation(filename,STATION,uhstring,&number_of_stations);

  /* Read input precision of VIC filenames*/
  fscanf(fp, "%*s %d",&decimal_places);

  /* Read spinup path of VIC filenames, and start and end year/month */
  fscanf(fp, "%*s %s",spinuppath);
  if (strcmp(spinuppath,none) !=0 ) {
    fscanf(fp, "%*s %d %d %d %d",
	  &spinup_start_year,&spinup_start_month,&spinup_stop_year,&spinup_stop_month);
    CalculateNumberDaysMonths(spinup_start_year,spinup_start_month,spinup_stop_year,spinup_stop_month,
			      &spinup_days,&nmonths);
  }
  else {
    fscanf(fp, "%*s %*d %*d %*d %*d");
//    fgets(dummy, MAXSTRING, fp);
    spinup_days = 0;
  }

  /* Read input path of VIC filenames, and start and end year/month */
  fscanf(fp, "%*s %s",inpath);
  fscanf(fp, "%*s %d %d %d %d", &start_year,&start_month,&stop_year,&stop_month);

  /* Read output path, and start and end year/month */
  fscanf(fp, "%*s %s",outpath);
  fscanf(fp, "%*s %d %d %d %d", &first_year,&first_month,&last_year,&last_month);
    
  printf("Spinup path: %s\nInpath: %s\nOutpath: %s\nDecimal_places: %d\n",
	 spinuppath,inpath,outpath,decimal_places);	  

  /* Calculate number of days & months in simulation,*/
  CalculateNumberDaysMonths(start_year,start_month,stop_year,stop_month,
			    &ndays,&nmonths);
  printf("VIC Start: %d %d  End: %d %d  Ndays: %d Nmonths:%d\n",
	  start_year,start_month,stop_year,stop_month,ndays,nmonths);  
  ndays += spinup_days;
  
  /* Check spinup, input and output period */
  if (spinup_days > 0) {
    mn1 = spinup_start_year * 12 + spinup_start_month;
    mn2 = first_year * 12 + first_month;
    if (mn1 > mn2) {
      printf("\nOutput starting date must not be earlier than spinup.\n");
      printf("Spinup starts: %4d %2d,\n", spinup_start_year, spinup_start_month);
      printf("Output starts: %4d %2d.\n", first_year, first_month);
      printf("Change these dates and restart.\n\n");
      exit(-1);
    }
    mn1 = spinup_stop_year * 12 + spinup_stop_month + 1;
    mn2 = start_year * 12 + start_month;
    if (mn1 != mn2) {
      printf("\nSpinup stopping month must be exactly one month eariler than input starting.\n");
      printf("Spinup stops: %4d %2d,\n", spinup_stop_year, spinup_stop_month);
      printf("Input starts: %4d %2d.\n", start_year, start_month);
      printf("Change these dates and restart.\n\n");
      exit(-1);
    }
  }
  else {
     spinup_start_year = start_year; spinup_start_month = start_month;
     mn1 = start_year * 12 + start_month;
     mn2 = first_year * 12 + first_month;
     if (mn1 > mn2) {
       printf("\nWhen no spinup is used, output starting date must not be earlier than input.\n");
       printf("Input  starts: %4d %2d,\n", start_year, start_month);
       printf("Output starts: %4d %2d.\n", first_year, first_month);
       printf("Change these dates and restart.\n\n");
       exit(-1);
     }
  }

  mn1 = stop_year * 12 + stop_month;
  mn2 = last_year * 12 + last_month;
  if (mn1 < mn2) {
    printf("\nOutput stopping date must not be later than input.\n");
    printf("Input  stops: %4d %2d,\n", stop_year, stop_month);
    printf("Output stops: %4d %2d.\n", last_year, last_month);
    printf("Change these dates and restart.\n\n");
    exit(-1);
  }  

  /* Allocate memory for BASEFLOW, RUNOFF and FLOW */
  RUNOFF=(float*)calloc(ndays + 1,sizeof(float));
  BASEFLOW=(float*)calloc(ndays + 1,sizeof(float));
  FLOW=(float*)calloc(ndays + 1,sizeof(float));

  /* Read uh-file */
  fscanf(fp, "%*s %s",filename);
  fclose(fp);

  /* Make impulse response function (UH) */
  printf("Making impulse response function........\n");
  MakeUH(UH,BASIN,nrows,ncols);

  /* Loop over required output stations, rout fluxes and write them out */  
  for(i=1;i<=number_of_stations;i++) {
     if(STATION[i].id==1) {
        printf("\n\nSearching catchment... Location: row %d col %d\n",
               STATION[i].row,STATION[i].col);
        SearchCatchment(BASIN,CATCHMENT,STATION[i].row,STATION[i].col,
                        nrows,ncols,&number_of_cells);

        /* Read grid UH.... */
        printf("Read grid UH...\n");
        ReadGridUH(filename,UH_BOX,number_of_cells);

        /* Making grid UH if it doesn't exist*/
        printf("Make grid UH...\n");
        MakeGridUH(BASIN,CATCHMENT,STATION,number_of_cells,i,
	           UH_DAILY,UH,FR,UH_BOX,UH_S,uhstring[i]);
 
        /* Making convolution */
        printf("Make convolution...\n");
        MakeConvolution(number_of_cells,ndays,spinup_days,CATCHMENT,BASIN,
  	                BASEFLOW,RUNOFF,FLOW,
  		        UH_S,STATION,xllcorner,yllcorner,size,
		        inpath,spinuppath,decimal_places,DATE,&factor_sum,
                        start_year,start_month,spinup_start_year,spinup_start_month);

        /* Writing data */
        printf("Writing data...\n");
        strcpy(name,STATION[i].name);
        WriteData(FLOW,name,outpath,DATE,factor_sum,
                  spinup_start_year,spinup_start_month,first_year,first_month,last_year,last_month);
        printf("finish processing station: %s\n", name);
      }
   }
   
  /* Free memory */
  for(i=1;i<=nrows;i++) 
    free(BASIN[i]);
  for(i=1;i<=TMAX;i++) 
    free(FR[i]);
  free(BASEFLOW);
  free(RUNOFF);
  free(FLOW);
  free(STATION);
  free(DATE);
 
}
/**********************************************************/
/* CalculateNumberDaysMonths                              */
/**********************************************************/
void CalculateNumberDaysMonths(int start_year,
			       int start_month,
			       int stop_year,
			       int stop_month,
			       int *ndays,
			       int *nmonths)

{
  int DaysInMonth[13] = { 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
  int i,j;
  int month,year,leap_year;

  month=start_month;
  year=start_year;
  (*nmonths)=0;
  (*ndays)=0;

  for(i=start_month;i<=12*(stop_year-start_year)+stop_month;i++) {
    if(month==2)
      leap_year=IsLeapYear(year); 
    else  
      leap_year=0;
    (*ndays)+=DaysInMonth[month]+leap_year;
    (*nmonths)+=1;
    month+=1;
    if(month>12) {
      month=1;
      year+=1;
    }
  }

  if((*ndays)>DAYS) {
    printf("In rout_all.c reset DAYS to %d\n",(*ndays));
    exit(0);
  }
  
}

/**********************************************/
/* FindRowsCols - finds rows,cols,xllcorner,
   yllcorner,size                             */
/**********************************************/
void FindRowsCols(char *filename, 
		  int *nrows,
		  int *ncols,
		  float *xllcorner,
		  float *yllcorner,
		  float *size)
{
  FILE *fp;
  char dummy[25];
  int i,j,missing;

  if((fp = fopen(filename, "r")) == NULL) {
    printf("Cannot open %s\n",filename);
    exit(1);
  }

  fscanf(fp,"%s %d", dummy, &(*ncols)); 
  fscanf(fp,"%s %d", dummy, &(*nrows)); 
  fscanf(fp,"%s %f", dummy, &(*xllcorner));
  fscanf(fp,"%s %f", dummy, &(*yllcorner));
  fscanf(fp,"%s %f", dummy, &(*size)); 
  fscanf(fp,"%s %d", dummy, &missing); 

  fclose(fp);

  if((*nrows)>MAXROWS || (*ncols)>MAXCOLS){
   printf("Incorrect dimensions: Reset nrow and ncol in main to %d, %d\n",
     (*nrows), (*ncols));
   exit(0);
   }
}
/*************************************/
/* IsLeapYear                        */
/*************************************/
int IsLeapYear(int year)
{
  if ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0)
    return 1;
  return 0;
}  
/**************************************/
/* MakeConvolution                    */ 
/**************************************/
void MakeConvolution(int number_of_cells,
		     int ndays,
		     int spinup_days,
		     int **CATCHMENT,
		     ARC **BASIN,
		     float *BASEFLOW,
		     float *RUNOFF,
		     float *FLOW,
		     float **UH_S,
		     LIST *STATION,
		     float xllcorner,
		     float yllcorner,
		     float size,
		     char *inpath,
		     char *spinuppath,
		     int decimal_places,
		     TIME *DATE,
		     float *factor_sum,
		     int start_year,
		     int start_month,
		     int spinup_start_year,
		     int spinup_start_month)
{
  FILE *fp;
  int i,j,k,n,ii,jj;
  int yr,mn,delta_yr;
  double factor;
  char infile[500];
  char LATLON[50];
  char fmtstr[17];
  char leftover[MAXSTRING];
  float lat, lon;
  double area,area_sum;
  double radius;
  double storage;
  float k_const;
  float dummy;
  char none[5]="NONE";

  k_const=1.0;
  area_sum=(*factor_sum)=0.0;

  for(i=1;i<=ndays;i++) 
    FLOW[i] = 0.0;
  
  for(n=1;n<=number_of_cells;n++) { //the gridcell loop
    storage=0.0;
    for(i=1;i<=ndays;i++) {
      RUNOFF[i]=0.0;
      BASEFLOW[i]=0.0;
    }
    
    ii = CATCHMENT[n][0]; //row from bottom 
    jj = CATCHMENT[n][1]; //col from left
    lat=yllcorner + ii*size - size/2.0;
    lon=xllcorner + jj*size - size/2.0;
    
    /* Give area of box in square kilometers */
    radius = (double)EARTHRADIUS;
    area = radius*radius*fabs(size)*PI/180*            
      fabs(sin((lat-size/2.0)*PI/180)-     
	   sin((lat+size/2.0)*PI/180));
    area_sum += area;
    factor = BASIN[ii][jj].fraction*area/86.4;  //conversion factor for
                                                //mm/day to m3/s
                                                //&mult. by cell fract
    factor *= 35.315;                           // 1 m3 = 35.315 ft3
    (*factor_sum) += factor;
    

    /* Make spinup filename */
    if(spinup_days > 0) {
      strcpy(infile,spinuppath);
      sprintf(fmtstr,"%%.%if_%%.%if",decimal_places,decimal_places);
      sprintf(LATLON,fmtstr,lat,lon);
      strcat(infile,LATLON);

      if((fp = fopen(infile,"r"))==NULL) { 
        printf("Cannot open file %s \n",infile);
        exit(0);
      }
      else {
      /* Read spinup: <year> <month> <day> <p> <et> <runoff> <baseflow>*/
        do {
	  fgets(leftover,MAXSTRING,fp); 
	  sscanf(leftover,"%d %d",&yr, &mn);
        } while ((yr<spinup_start_year) || ((yr==spinup_start_year) && (mn<spinup_start_month)));
      
        sscanf(leftover,"%*d %*d %*d %*f %*f %f %f",&RUNOFF[1],&BASEFLOW[1]);
/*        sscanf(leftover,"%d %d %d %f %f %f %f ",&DATE[1].year,&DATE[1].month,&DATE[1].day,
	       &dummy,&dummy,&RUNOFF[1],&BASEFLOW[1]);*/
        for (i = 2; i <= spinup_days; i ++) {
	  fscanf(fp,"%*d %*d %*d %*f %*f %f %f",&RUNOFF[i],&BASEFLOW[i]);
/*	  fscanf(fp,"%d %d %d %f %f %f %f ",&DATE[i].year,&DATE[i].month,&DATE[i].day,
	       &dummy,&dummy,&RUNOFF[i],&BASEFLOW[i]);*/
	  fgets(leftover,MAXSTRING,fp);
        }
        fclose(fp);
      }
    }

    /* Make vic filename */
    strcpy(infile,inpath);
    sprintf(fmtstr,"%%.%if_%%.%if",decimal_places,decimal_places);
    sprintf(LATLON,fmtstr,lat,lon);
    strcat(infile,LATLON);
    printf("File %d of %d: %s\n",n,number_of_cells,infile);

    if((fp = fopen(infile,"r"))==NULL) { 
      printf("Cannot open file %s \n",infile);
      exit(0);
    }
    else {
      /* Read VIC model output: <year> <month> <day> <p> <et> <runoff> <baseflow> */
      for(i = (spinup_days + 1);i<=ndays;i++) {
	fscanf(fp,"%*d %*d %*d %*f %*f %f %f",&RUNOFF[i],&BASEFLOW[i]);
/*	fscanf(fp,"%d %d %d %f %f %f %f ",&DATE[i].year,&DATE[i].month,&DATE[i].day,
	       &dummy,&dummy,&RUNOFF[i],&BASEFLOW[i]);*/
	fgets(leftover,MAXSTRING,fp); 
      }
    }

    for(i=1;i<=ndays;i++) {
	RUNOFF[i] = RUNOFF[i]*factor;
	BASEFLOW[i] = BASEFLOW[i]*factor;
    }
     
    for(i=1;i<=ndays;i++) {
      for(j=1;j<KE+UH_DAY;j++) {
	if((i-j+1)>=1) {
	  FLOW[i] += UH_S[n][j]*(BASEFLOW[i-j+1]+RUNOFF[i-j+1]);
	}
      }
    }
    fclose(fp);
  }  
}
/************************************************************************/
/* MakeGridUH                                                           */
/************************************************************************/
void MakeGridUH(ARC **BASIN,
		int **CATCHMENT,
		LIST *STATION,
		int number_of_cells,
		int cellnumber,
		float **UH_DAILY,
		float ***UH,
		float **FR,
		float **UH_BOX,
		float **UH_S,
		char *uh_string)

{
  FILE *fp;
  float sum;
  int i,j,k,l,n,t,u,ii,jj,tt;
  char none[5]="NONE";
  char name[10];

  if(strcmp(uh_string,none) !=0) {
    printf("Reading UH_S grid from file\n");
    if((fp = fopen(uh_string, "r")) == NULL) {
      printf("Cannot open %s\n",uh_string);
      exit(1);
    }
    else printf("File opened for reading: %s\n",uh_string);
    for(n=1;n<=number_of_cells;n++) 
      for(k=1;k<KE+UH_DAY;k++) 
	fscanf(fp,"%f ",&UH_S[n][k]);
  }
  else {
    printf("Making UH_S grid.... It takes a while...\n");
    strcpy(name,STATION[cellnumber].name);
    strcat(name,".uh_s");
    if((fp = fopen(name, "w")) == NULL) {
      printf("Cannot open %s\n",name);
      exit(1);
    }
    else printf("File opened for writing: %s\n",name);

    for(n=1;n<=number_of_cells;n++) {
      printf("grid cell %d out of %d\t",n,number_of_cells);
      for(k=1;k<=UH_DAY;k++)
        UH_DAILY[n][k] = 0.0;
      i=CATCHMENT[n][0];
      j=CATCHMENT[n][1];
            printf("n=%d i=%d j=%d\n",n,i,j);
      for(t=1;t<=24;t++) {
	FR[t][0]=1.0/24.;
	FR[t][1]=0.0;
      }
      for(t=25;t<=TMAX;t++) {
	FR[t][0]=0.0;
	FR[t][1]=0.0;
      }

      while (i!=STATION[cellnumber].row || j!=STATION[cellnumber].col) { 
	for(t=1;t<=TMAX;t++) {
	  for(l=1;l<=LE;l++) {
	    if((t-l)>0) 
	      FR[t][1]=FR[t][1]+FR[t-l][0]*UH[i][j][l];
	  }
	}
	for(t=1;t<=TMAX;t++) {
	  FR[t][0]=FR[t][1];
	  FR[t][1]=0.0;
	}
	ii=BASIN[i][j].torow;
	jj=BASIN[i][j].tocol;
	i=ii;
	j=jj;
      }

      for(t=1;t<=TMAX;t++) {
	tt=(t+23)/24;
	UH_DAILY[n][tt] += FR[t][0];
      }
    }

    for(n=0;n<=number_of_cells;n++) {
      for(k=0;k<KE+UH_DAY;k++) {
	UH_S[n][k]=0.;
      }
    }

    for(n=1;n<=number_of_cells;n++) {
      for(k=1;k<=KE;k++) {
	for(u=1;u<=UH_DAY;u++) 
	  UH_S[n][k+u-1] = UH_S[n][k+u-1]+UH_BOX[n][k]*UH_DAILY[n][u];
      }	
      sum=0.0;
      for(k=1;k<KE+UH_DAY;k++)
	sum+=UH_S[n][k];
      for(k=1;k<KE+UH_DAY;k++)
	UH_S[n][k]=UH_S[n][k]/sum;
    }

    for(n=1;n<=number_of_cells;n++) {
      for(k=1;k<KE+UH_DAY;k++) {
	if(UH_S[n][k]>0) fprintf(fp,"%f ",UH_S[n][k]);
	else fprintf(fp,"%.1f ",UH_S[n][k]);
      }
      fprintf(fp,"\n");
    }
  }

}
/****************************************************
MakeUH:
 Calculate impulse response function for grid cells
 using equation (15) from Lohmann, et al. (1996)  
 Tellus article
*****************************************************/
void MakeUH(float ***UH,
	    ARC **BASIN,
	    int nrows,
	    int ncols)
{
  int i,j,k;
  float time,exponent;
  float green; // Green's function h(x,t)
  float conv_integral; // Convolution integral Q(x,t)

  for(i=1;i<=nrows;i++) {
    for(j=1;j<=ncols;j++) {
      time=0.0;
      for(k=1;k<=LE;k++) {
	time=time+DELTA_T;
	if(BASIN[i][j].velocity>0.0) {
	  exponent=((BASIN[i][j].velocity*time-BASIN[i][j].xmask)*
		    (BASIN[i][j].velocity*time-BASIN[i][j].xmask))/
	    (4.0*BASIN[i][j].diffusion*time);
	  if(exponent>69.0)  //where does this number come from???? 
	    green=0.0;
	  else 
	    green=1.0/(2.0*sqrt(PI*BASIN[i][j].diffusion)) * 
	      BASIN[i][j].xmask/pow(time,1.5) * 
	      exp(-exponent);  // eq. 15 in Tellus article
	}
	else
	  green=0.0;
	UH[i][j][k]=green;
      }
    }
  }

  for(i=1;i<=nrows;i++) {
    for(j=1;j<=ncols;j++) {
      conv_integral = 0.0;
      for(k=1;k<=LE;k++) 
	conv_integral += UH[i][j][k];
      if (conv_integral > 0.0) {
	for(k=1;k<=LE;k++) 
	  UH[i][j][k] = UH[i][j][k]/conv_integral; //why? normalizing?
      }
    }
  }
  
}
/*********************************/
/* Reads the diffusion file      */
/*********************************/
void ReadDiffusion(char *filename, 
		  ARC **BASIN,
		  int nrows,
		  int ncols)
{
  FILE *fp;
  char dummy[25];
  int i,j,nodata;

  if((fp = fopen(filename, "r")) == NULL) {
    printf("Cannot open %s\n",filename);
    exit(1);
  }
  else printf("File opened %s\n",filename);

  for(i=0;i<6;i++)
    fscanf(fp,"%s %s", dummy, dummy); 

  for(i=nrows;i>=1;i--) { //kept bounds
    for(j=1;j<=ncols;j++) { 
      fscanf(fp,"%d",&BASIN[i][j].diffusion); 
      if(BASIN[i][j].diffusion<0.) BASIN[i][j].diffusion=0.; 
    }
  }
  fclose(fp);
}
/*********************************/
/* Reads the flow direction file */
/*********************************/
void ReadDirection(char *filename, 
		   ARC **BASIN,
		   int nrows,
		   int ncols,
		   int *active_cells)
{
  FILE *fp;
  char dummy[25];
  int i,j,missing;

  if((fp = fopen(filename, "r")) == NULL) {
    printf("Cannot open %s\n",filename);
    exit(1);
  }

  for(i=0;i<5;i++)
    fscanf(fp,"%*s %*s"); 
  fscanf(fp,"%*s %d", &missing); 

  (*active_cells)=0;

  for(i=nrows;i>=1;i--) { // kept bounds 
    for(j=1;j<=ncols;j++) { 
      fscanf(fp,"%d",&BASIN[i][j].direction); 
      if(BASIN[i][j].direction>missing) 
	(*active_cells)+=1;
    }
  }

  fclose(fp);

  for(i=1;i<=nrows;i++) {
    for(j=1;j<=ncols;j++) {
      switch (BASIN[i][j].direction) {
        case 1:
          BASIN[i][j].tocol=j;
          BASIN[i][j].torow=i+1;
          break;
        case 2:
          BASIN[i][j].tocol=j+1;
          BASIN[i][j].torow=i+1;
          break;
        case 3:
          BASIN[i][j].tocol=j+1;
          BASIN[i][j].torow=i;
          break;
        case 4:
          BASIN[i][j].tocol=j+1;
          BASIN[i][j].torow=i-1;
          break;
        case 5:
          BASIN[i][j].tocol=j;
          BASIN[i][j].torow=i-1;
          break;
        case 6:
          BASIN[i][j].tocol=j-1;
          BASIN[i][j].torow=i-1;
          break;
        case 7:
          BASIN[i][j].tocol=j-1;
          BASIN[i][j].torow=i;
          break;
        case 8:
          BASIN[i][j].tocol=j-1;
          BASIN[i][j].torow=i+1;
          break;
        default:
	  BASIN[i][j].tocol=0;
	  BASIN[i][j].torow=0;
      }
    }
  }
}

/*********************************/
/* Reads the fraction file       */
/*********************************/
void ReadFraction(char *filename, 
		  ARC **BASIN,
		  int nrows,
		  int ncols)

{
  FILE *fp;
  char dummy[25];
  int i,j;
  float fvalue;
  int ivalue;

  if((fp = fopen(filename, "r")) == NULL) {
    printf("Cannot open %s\n",filename);
    exit(1);
  }

  for(i=0;i<6;i++)
  fscanf(fp,"%s %s", dummy, dummy); 

  for(i=nrows;i>=1;i--) { 
    for(j=1;j<=ncols;j++) { 
      fscanf(fp,"%f",&BASIN[i][j].fraction); 
    }
  }
  fclose(fp);
}

/*********************************/
/* Reads the grid uh             */
/*********************************/
void ReadGridUH(char *filename, 
		float **UH_BOX,
		int number_of_cells)

{
  FILE *fp;
  int i,j;

  for(i=1;i<=number_of_cells;i++) { 
    if((fp = fopen(filename, "r")) == NULL) {
      printf("Cannot open %s\n",filename);
      exit(1);
    }
    for(j=1;j<=12;j++) 
      fscanf(fp,"%*f %f",&UH_BOX[i][j]); 
    
    fclose(fp);
  }

}

/*********************************/
/* Reads the station file        */
/*********************************/
void ReadStation(char *filename, 
		 LIST *STATION,
		 char uhstring[MAXSTNS][MIDSTRING],
		 int *number_of_stations)
{
  FILE *fp;
  int i,j;

  if((fp = fopen(filename, "r")) == NULL) {
    printf("Cannot open %s\n",filename);
    exit(1);
  }

  i=1;
  while(!feof(fp)) {
    fscanf(fp,"%d %s %d %d %f ",
	   &STATION[i].id,STATION[i].name,&STATION[i].col,
	   &STATION[i].row,&STATION[i].area); 
    fscanf(fp,"%s",uhstring[i]);
    i+=1;	     
  }

  (*number_of_stations)=i-1;
  fclose(fp);
}
/*********************************/
/* Reads the velocity file       */
/*********************************/
void ReadVelocity(char *filename, 
		  ARC **BASIN,
		  int nrows,
		  int ncols)
{
  FILE *fp;
  char dummy[25];
  int i,j,nodata;

  if((fp = fopen(filename, "r")) == NULL) {
    printf("Cannot open %s\n",filename);
    exit(1);
  }
  else printf("File opened %s\n",filename);

  for(i=0;i<6;i++)
    fscanf(fp,"%s %s", dummy, dummy); 

  for(i=nrows;i>=1;i--) { //kept bounds
    for(j=1;j<=ncols;j++) { 
      fscanf(fp,"%d",&BASIN[i][j].velocity); 
      if(BASIN[i][j].velocity<0.) BASIN[i][j].velocity=0.; 
    }
  }
  fclose(fp);
}
/*********************************/
/* Reads the xmask file          */
/*********************************/
void ReadXmask(char *filename, 
	       ARC **BASIN,
	       int nrows,
	       int ncols)
{
  FILE *fp;
  char dummy[25];
  int i,j,nodata;

  if((fp = fopen(filename, "r")) == NULL) {
    printf("Cannot open %s\n",filename);
    exit(1);
  }
  else printf("File opened %s\n",filename);

  for(i=0;i<6;i++)
    fscanf(fp,"%s %s", dummy, dummy); 

  for(i=nrows;i>=1;i--) { //kept bounds
    for(j=1;j<=ncols;j++) { 
      fscanf(fp,"%f",&BASIN[i][j].xmask); 
      if(BASIN[i][j].xmask<0.) BASIN[i][j].xmask=0.; 
    }
  }
  fclose(fp);
}
/*********************************************/
/* SearchCatchment                           */
/* Purpose: Find number of cells upstream    */
/*          current gage location, and their */
/*          row and col number               */ 
/*********************************************/
void SearchCatchment(ARC **BASIN,
		     int **CATCHMENT,
		     int row,
		     int col,
		     int nrows,
		     int ncols,
		     int *number_of_cells)
{
  int i,j,ii,jj,iii,jjj;
  int count; char op;

  count = 0;
  for(i=1;i<=nrows;i++) {
    for(j=1;j<=ncols;j++) {
      if (BASIN[i][j].tocol == 0) continue;
      ii=i;
      jj=j;
      op = 0;
      do {
        if (ii==row && jj==col) { 
	  count++; op = 1;
	  CATCHMENT[count][0]=i;
	  CATCHMENT[count][1]=j;
	} 
	else if (BASIN[ii][jj].tocol!=0 && BASIN[ii][jj].torow!=0) { 
          iii = BASIN[ii][jj].torow;         
	  jjj = BASIN[ii][jj].tocol;         
	  ii  = iii;                  
	  jj  = jjj;                  
          if (ii>nrows || ii<1 || jj>ncols || jj<1) op = -1;
	}                                
        else {
          op = -1;
        }
      } while (op == 0);
    }
  }

  (*number_of_cells)=count;
  printf("Upstream grid cells from present station: %d\n", (*number_of_cells));
}
/****************************************************************/
void WriteData(float *FLOW,
	       char *name,
	       char *outpath,
	       TIME *DATE,
	       float factor_sum,
	       int spinup_start_year,
	       int spinup_start_month,
	       int first_year,
	       int first_month,
	       int last_year,
	       int last_month)
{
  FILE *fp,*fp_mm;
  char *filename_fp,*filename_fp_mm;
  float MONTHLY[MAXYEARS+1][13];  //variables for monthly means
  float YEARLY[13];
  int nyears[13];
  int i,j,k,nmonths;
  int yy,yr,mm,day,days_cur_mon,first_day,last_day;
  int DaysInMonth[13] = { 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };

  filename_fp = (char*)calloc(100,sizeof(char));
  filename_fp_mm = (char*)calloc(100,sizeof(char));
  
  sprintf(filename_fp,"%s%s.day",outpath,name);
  if((fp = fopen(filename_fp, "w")) == NULL) {
    printf("Cannot open %s\n",filename_fp);
    exit(1);
  }
  sprintf(filename_fp_mm,"%s%s.day_mm",outpath,name);
  if((fp_mm = fopen(filename_fp_mm, "w")) == NULL) {
    printf("Cannot open %s\n",filename_fp_mm);
    exit(1);
  }

  /* Initialize */
  for(i=0;i<=12;i++) {
    YEARLY[i]=0.;
    nyears[i]=0;
    for(j=0;j<=MAXYEARS;j++) {
      MONTHLY[j][i]=0.;
    }
  }

  for(i=first_month;i<=12;i++) 
    nyears[i]+=1;
  for(i=1;i<=last_month;i++) 
    nyears[i]+=1;
  for(j=first_year+1;j<last_year;j++) 
    for(i=1;i<=12;i++) 
      nyears[i]+=1;

  CalculateNumberDaysMonths(spinup_start_year,spinup_start_month,first_year,first_month - 1,
			    &first_day,&nmonths);
  CalculateNumberDaysMonths(spinup_start_year,spinup_start_month,last_year,last_month,
			    &last_day,&nmonths);
  yr = first_year; yy = 0; mm = first_month; day = 1;
  days_cur_mon = DaysInMonth[mm];
  if ((mm == 2) && (IsLeapYear(yr))) days_cur_mon ++; 
    
  /* Write daily data and store monthly values */
  for(i = first_day + 1; i <= last_day; i ++) {
      MONTHLY[yy][mm]+=FLOW[i]/days_cur_mon;
      YEARLY[mm]+=FLOW[i]/days_cur_mon;
      fprintf(fp,"%4d %2d %2d %f\n", yr, mm, day, FLOW[i]);
      fprintf(fp_mm,"%4d %2d %2d %f\n", yr, mm, day, FLOW[i]/factor_sum);
	      
      /* update year, month, day at the end of each month*/	      
      day ++; 
      if (day > days_cur_mon) {
         day = 1; mm ++;
         if (mm > 12) {mm = 1; yr ++; yy ++;}
         days_cur_mon = DaysInMonth[mm];
         if ((mm == 2) && (IsLeapYear(yr))) days_cur_mon ++;          
      }
  }
  fclose(fp);
  fclose(fp_mm);

  /* Write monthly data */
  sprintf(filename_fp,"%s%s.month",outpath,name);
  if((fp = fopen(filename_fp, "w")) == NULL) {
    printf("Cannot open %s\n",filename_fp);
    exit(1);
  }
  sprintf(filename_fp_mm,"%s%s.month_mm",outpath,name);
  if((fp_mm = fopen(filename_fp_mm, "w")) == NULL) {
    printf("Cannot open %s\n",filename_fp_mm);
    exit(1);
  }

  i = 0;
  for(j=first_month;j<=12;j++) {
    fprintf(fp,"%4d %2d %f\n",i+first_year,j,MONTHLY[i][j]);
    fprintf(fp_mm,"%4d %2d %f\n",i+first_year,j,MONTHLY[i][j]/factor_sum);
  }
  for(i=1;i<last_year-first_year;i++) {
    for(j=1;j<=12;j++) {
      fprintf(fp,"%4d %2d %f\n",i+first_year,j,MONTHLY[i][j]);
      fprintf(fp_mm,"%4d %2d %f\n",i+first_year,j,MONTHLY[i][j]/factor_sum);
    }
  }
  i = last_year - first_year;
  for(j=1;j<=last_month;j++) {
      fprintf(fp,"%4d %2d %f\n",i+first_year,j,MONTHLY[i][j]);
      fprintf(fp_mm,"%4d %2d %f\n",i+first_year,j,MONTHLY[i][j]/factor_sum);
  }
  fclose(fp);
  fclose(fp_mm);

  /* Write mean monthly data */
  sprintf(filename_fp,"%s%s.year",outpath,name);
  if((fp = fopen(filename_fp, "w")) == NULL) {
    printf("Cannot open %s\n",filename_fp);
    exit(1);
  }
  sprintf(filename_fp_mm,"%s%s.year_mm",outpath,name);
  if((fp_mm = fopen(filename_fp_mm, "w")) == NULL) {
    printf("Cannot open %s\n",filename_fp_mm);
    exit(1);
  }

  for(i=1;i<=12;i++) {
    fprintf(fp,"%2d %f\n",i,YEARLY[i]/nyears[i]);
    fprintf(fp_mm,"%2d %f\n",i,YEARLY[i]/(nyears[i]*factor_sum));
  }

  fclose(fp);
  fclose(fp_mm);
}
