/*      PROGRAM rout, C-version   

     Routing algorithm developed by D. Lohmann.
     Modified to allow more flexible array dimensions and
     the removal of hardcoded file names.  
     Rewritten from FORTRAN to C 2003, AWW/IH.

     New features, 2003 (IH):
      Upstream routed areas are not rerouted
      Dams/reservoirs included (based on power or streamflow demand)

     MAXROWS and MAXCOLS should be larger than the grid
     MAXYEARS should equal at least run length yrs+1   
     i: row from bottom (starts at 1)
     j: col from left (starts at 1)
     [][]: [row][col]
     Indexing (arrays): Starts at 1 (i.e. 0 is left unused)

gcc -lm ~/models/rout/rout_c/rout_new.c

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
#define MAXYEARS 31
/*************************************************************/
/* No changes after here                                     */
/*************************************************************/
#define DAYS   MAXYEARS*366
#define KE     12              //number of steps in uh_file 
#define LE     48              //impulse response function. why 48?   
#define DELTA_T 3600.0
#define UH_DAY 96              //max days to outlet 
#define TMAX   UH_DAY*24
#define MAX_CELLS_IN_BASIN 5000   
#define MAXSTRING 512
#define NODATA -9999
#define PI 4.0*atan(1.0)       //pi!
#define EPS 1e-6               //precision
#define EARTHRADIUS 6371.229;  //radius of earth in kilometers
#define SORT 0
#define min(a,b) (a < b) ? a : b
#define max(a,b) (a > b) ? a : b
#define GE 9.81               //acceleration due to gravity, m/s2
#define EFF 0.85              //efficiency of power generating system
/*************************************************************/
/* TYPE DEFINITIONS, GLOBALS, ETC.                           */
/*************************************************************/
typedef enum {double_f, int_f, float_f, long_f, short_f} FORMAT_SPECIFIER;

typedef struct {
  int flag;
  int routflag; //already routed cell: routflag=1
  int ntypes;
  int direction;
  int routed;  //1:routed,2:flow exist
  int resloc; //0:no reservoir,1:reservoir
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
  int type; /* 1: Regular, 2: Dam, 3: Irrigated part of cell */
  float area;
  float demand;
  char name[5];
} LIST;

typedef struct {
  int year;
  int month;
  int day;
} TIME;
/*************************************************************/
void CalculateNumberDaysMonths(int,int,int,int,
			       int,int,int*,int *,int *);
void FindRowsCols(char *,int *,int *, float *, 
		   float *,float *,int *); 
int IsLeapYear(int);
void MakeConvolution(int,int,int,int **,ARC **,
		     float *,float *,float *,float **,
		     LIST *,int,float,float,float,
		     char *,char *,char *,int,TIME *,float *,
		     int,int,int,int);
void MakeDirectionFile(ARC **,int **,int,int,int,float,
		       float,float,int);
void MakeRoutedFile(ARC **,int **,int,int,int);
void MakeGridUH_S(ARC **,int **,LIST *,
		  int,int,float **,float ***,float **,float **,
		  float **,char *);
void MakeUH(float ***UH,ARC **,int,int);
void ReadDiffusion(char *,ARC **,int,int); 
void ReadDirection(char *,ARC **,int,int,int *,int); 
void ReadFraction(char *,ARC **,int,int); 
void ReadGridUH(char *,float **UH_BOX,int,int **);
void ReadReservoirLocations(char *,ARC **,int,int);
void ReadRouted(char *, ARC **, int,int); 
void ReadStation(char *,ARC **,LIST *,int,int,
		 char uhstring[20][20],int *);
void ReadVelocity(char *, ARC **,int,int); 
void ReadXmask(char *, ARC **,int,int); 
void ReservoirRouting(char *,float *,float *,int,TIME *,int,int);
void SearchCatchment(ARC **,int **,int,
		     int,int,int,int,int *,int *);
void SearchRouted(ARC **,int,int,int,int);
void WriteData(float *,float *,char *,char *,int,int,TIME *,
	       float,int,int,int,int,int,float,float,int,int);
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
  LIST *STATION=NULL;  //Information about station locations and names.
                    //Area is included in the list, although the value
                    //isn't used in the routing program.
  TIME *DATE=NULL;

  char *filename;
  char *filename_reservoirs;
  char *inpath;
  char *outpath;
  char *workpath;
  char *dummy;
  char *name;
  char uhstring[20][20]; //name of uhfile (or "NONE")

  float xllcorner; //x-coordinate, lower left corner of grid
  float yllcorner; //y-coordinate, lower left corner of grid
  float size;      //size of grid cell, in degrees
  float lat;
  float lon;
  float value;
  float factor_sum;
  float ***UH;     /* Impulse response function UH[row][col][48] */
                   /* Based on Lohmann's Tellus article          */
		   /* Depends on velocity, diffusion and size    */  
  float **UH_BOX;  /* Unit hydrograph[number_of_cells][12]       */
                   /* Normally the 12 numbers are equal to       */
                   /* the ones in the unit hydrograph file       */ 
  float **UH_DAILY; /* UH_DAILY[number_of_cells][uh_day]         */
  float **UH_S;    /* .uh_s grid, UH_S[numberofcells][ke+uh_day] */
  float **FR;
  float *BASEFLOW;  
  float *RUNOFF;
  float *FLOW;
  float *R_FLOW;

  int **CATCHMENT; /*A list with row and col number for all cells upstream 
                     station location (includes station location). 
                     CATCHMENT[cellnumber][row(0)/col(1)/routed(2)]
                     The order of the list is arbitrary. 
                     CATCHMENT[cellnumber][2]=0 means routing as normal
                     CATCHMENT[cellnumber][2]=1 means this cell is routed before, in current routing
                     CATCHMENT[cellnumber][2]=2 means flow already exist for that
                     cell (routed some time previously). */
  int *MONTH;
  int *YEAR;
  int i,j;
  int nr;
  int nrows,ncols;     //number of rows/columns in basin 
                       //(read from direction file)
  int active_cells;    //total number of active cells in grid
  int number_of_cells; //number of cells upstream a station location
  int upstream_cells;			   
  int number_of_stations; //number of stations 
  int decimal_places;  //decimal places in VIC output 
  int start_year,start_month; //start of VIC simulation
  int stop_year,stop_month;
  int first_year,first_month; //start of output to be written
  int last_year,last_month;
  int ndays,nmonths;   //number of days and months to be routed 
  int skip;            //number of days to skip in VIC simulations
  int irr_rout;        //irrigation type routing (ingjerd)	   
  int irow,icol;			   
  int missing;
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
  filename_reservoirs = (char*)calloc(100,sizeof(char));
  inpath = (char*)calloc(100,sizeof(char));
  outpath = (char*)calloc(100,sizeof(char));
  workpath = (char*)calloc(100,sizeof(char));
  dummy = (char*)calloc(100,sizeof(char));
  name = (char*)calloc(100,sizeof(char));

  /* Find number of rows and cols in grid of interest */
  fgets(dummy, MAXSTRING, fp);
  fscanf(fp, "%*s %s",filename);
  FindRowsCols(filename,&nrows,&ncols,&xllcorner,
               &yllcorner,&size,&missing);

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
  ReadDirection(filename,BASIN,nrows,ncols,&active_cells,missing);
  printf("Active cells in basin: %d\n",active_cells);

  /* Allocate memory for CATCHMENT, UH_BOX, UH_S, 
                         UH_DAILY, STATION */
  CATCHMENT = (int**)calloc(active_cells+1,sizeof(int*));
  for(i=0;i<=active_cells;i++) 
    CATCHMENT[i]=(int*)calloc(4,sizeof(int));
  UH_BOX=(float**)calloc(active_cells+1,sizeof(float*));
  for(i=0;i<=active_cells;i++) 
      UH_BOX[i]=(float*)calloc(KE+1,sizeof(float*));      
  UH_DAILY=(float**)calloc(active_cells+1,sizeof(float*));
  for(i=0;i<=active_cells;i++) 
      UH_DAILY[i]=(float*)calloc(UH_DAY+1,sizeof(float));      
  UH_S=(float**)calloc(active_cells+1,sizeof(float*));
  for(i=0;i<=active_cells;i++) 
      UH_S[i]=(float*)calloc(KE+UH_DAY+1,sizeof(float));      
  STATION=calloc(20,sizeof(LIST));
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
  value= atof(filename);
  if(value<EPS) ReadFraction(filename,BASIN,nrows,ncols);
  else {
    printf("Fraction: %.2f\n",value);
    for(i=1;i<=nrows;i++)
      for(j=1;j<=ncols;j++) 
        BASIN[i][j].fraction=value;
  }

  /* Read routing information 
     irr_rout=1: Nonirrigated part of cell, or entire cell
     irr_rout=0: Irrigated part of cell */
  fscanf(fp, "%*s %d",&irr_rout); 
  fscanf(fp, "%*s %s",filename);
  value=atof(filename);
  if(value<EPS) {
    ReadRouted(filename,BASIN,nrows,ncols);
  }
  else {
    for(i=1;i<=nrows;i++)
      for(j=1;j<=ncols;j++) 
        BASIN[i][j].routflag=0;
    printf("Routed cells: %s not found, setting values to zero\n",
	   filename);    
  }

  /* Read reservoir file name */
  fscanf(fp, "%*s %s",filename_reservoirs);
  printf("Reservoir file: %s\n",filename_reservoirs);

  /* Read reservoir location file name */
  fscanf(fp, "%*s %s",filename);
  value=atof(filename);
  if(value<EPS) ReadReservoirLocations(filename,BASIN,nrows,ncols);
  else {
    printf("Reservoir locations: %.2f\n",value);
    for(i=1;i<=nrows;i++)
      for(j=1;j<=ncols;j++) 
        BASIN[i][j].resloc=0;
  }

  /* Read station file */
  fscanf(fp, "%*s %s",filename);
  printf("Station file: %s\n",filename);
  ReadStation(filename,BASIN,STATION,nrows,ncols,
	      uhstring,&number_of_stations);

  /* Read input path and precision of VIC filenames, and output path */
  fscanf(fp, "%*s %s",inpath);
  fscanf(fp, "%*s %d",&decimal_places);
  fscanf(fp, "%*s %s",outpath);
  fscanf(fp, "%*s %s",workpath);

  printf("Input file path: %s\n",inpath);
  printf("Decimal places: %d\n",decimal_places);
  printf("Output file path: %s\n",outpath);
  printf("Working files path: %s\n",workpath);

  /* Read start and end year/month from VIC simulation */
  fscanf(fp, "%*s %d %d %d %d",
	 &start_year,&start_month,&stop_year,&stop_month);

  /* Read start and end year/month for writing output */
  fscanf(fp, "%*s %d %d %d %d",
	 &first_year,&first_month,&last_year,&last_month);

  printf("Start input: %d %d  Start output: %d %d  \n",
	 start_year,start_month,first_year,first_month);  

  /* Calculate number of days & months to be routed, 
     and number of days to skip when reading VIC simulation 
     results */
  CalculateNumberDaysMonths(start_year,start_month,
                            first_year,first_month,
                            last_year,last_month, 
                            &skip,&ndays,&nmonths);
  printf("Output Start: %d %d  End: %d %d  Skip: %d Ndays: %d Nmonths:%d\n",
	 first_year,first_month,last_year,last_month,skip,ndays,nmonths);  

  /* Allocate memory for BASEFLOW, RUNOFF and FLOW */
  RUNOFF=(float*)calloc(ndays+1,sizeof(float));
  BASEFLOW=(float*)calloc(ndays+1,sizeof(float));
  FLOW=(float*)calloc(ndays+1,sizeof(float));
  R_FLOW=(float*)calloc(ndays+1,sizeof(float));

  /* Read name of uh-file */
  fscanf(fp, "%*s %s",filename);
  fclose(fp);

  /* Make impulse response function (UH). */
  /* Based on Lohmann's Tellus article    */
  printf("Making impulse response function.....UH[row][col][48]\n");
  MakeUH(UH,BASIN,nrows,ncols);

  /* Loop over required output stations, 
     rout fluxes and write them out */  
  for(nr=1;nr<=number_of_stations;nr++) {
    for(j=1;j<=ndays;j++) R_FLOW[j]=0.;
    if(STATION[nr].id==1) {
        printf("\n\nSearching catchment... \
               Location: row %d col %d\n",
               STATION[nr].row,STATION[nr].col);
        SearchCatchment(BASIN,CATCHMENT,STATION[nr].row,
                        STATION[nr].col,nrows,ncols,
                        STATION[nr].type,&number_of_cells,
			&upstream_cells);

        /* Read grid UH, UH_BOX[number_of_cells][12] */
        printf("Read grid UH_BOX...%s\n",filename);
        ReadGridUH(filename,UH_BOX,number_of_cells,
                   CATCHMENT);

        /* Make .uh_s-file if it doesn't exist, 
			     UH_S[numberofcells][ke+uh_day] */
        printf("Make grid UH_S...\n");
        MakeGridUH_S(BASIN,CATCHMENT,STATION,number_of_cells,nr,
	           UH_DAILY,UH,FR,UH_BOX,UH_S,uhstring[nr]);
 
        /* Make convolution */
        printf("Make convolution...\n");
        MakeConvolution(number_of_cells,skip,ndays,CATCHMENT,
                        BASIN,BASEFLOW,RUNOFF,FLOW,
  		        UH_S,STATION,nr,
			xllcorner,yllcorner,size,
		        inpath,outpath,workpath,decimal_places,DATE,
			&factor_sum,first_year,first_month,irr_rout,
			missing);

	/* Reservoir routing if needed */
	if(STATION[nr].type==2) {
	  printf("Reservoir routing.....\n");
	  ReservoirRouting(filename_reservoirs,FLOW,R_FLOW,ndays,DATE,
			   STATION[nr].row,STATION[nr].col);
	}

        /* Write data */
	printf("Writing data...\n");
        lat=yllcorner + STATION[nr].row*size - size/2.0;
        lon=xllcorner + STATION[nr].col*size - size/2.0;
        strcpy(name,STATION[nr].name);
        WriteData(FLOW,R_FLOW,name,outpath,ndays,nmonths,DATE,factor_sum,
                  first_year,first_month,last_year,
		  last_month,start_year,lat,lon,STATION[nr].type,
		  decimal_places);

	if(irr_rout==0) {
	  for(i=3;i<=upstream_cells;i++) {
	    irow=CATCHMENT[i][0];
	    icol=CATCHMENT[i][1];
	    BASIN[irow][icol].routed=1;	
	  }
	}
     }
  }

  /* Make new 'routed' file */
  MakeRoutedFile(BASIN,CATCHMENT,nrows,ncols,number_of_cells); 
 
  /* Make new direction file */
  MakeDirectionFile(BASIN,CATCHMENT,nrows,ncols,number_of_cells,
		    xllcorner,yllcorner,size,missing); 

  /* Free memory */
  for(i=0;i<=nrows+1;i++) {
    free(BASIN[i]);
    free(UH[i]);
  }
  free(BASIN);
  free(UH);

  for(i=0;i<=active_cells+1;i++) 
    free(CATCHMENT[i]);
  free(CATCHMENT);

  free(DATE);
  free(STATION);
  free(RUNOFF);
  free(BASEFLOW); 
  free(FLOW);
  free(R_FLOW);
}
/**********************************************************/
/* CalculateNumberDaysMonths                              */
/**********************************************************/
void CalculateNumberDaysMonths(int start_year,
			       int start_month,
                               int first_year,
			       int first_month,
			       int last_year,
			       int last_month,
                               int *skip,  
			       int *ndays,
			       int *nmonths)

{
  int DaysInMonth[13] = { 0,31,28,31,30,31,30,31,31,30,31,30,31 };
  int i,j;
  int month,year,leap_year;

  month=start_month;
  year=start_year;
  (*skip)=0;

  if(start_year<=first_year) { 
    for(i=start_month;i<12*(first_year-start_year)+first_month;i++) {
      if(month==2)
         leap_year=IsLeapYear(year); 
      else  
        leap_year=0;
      (*skip)+=DaysInMonth[month]+leap_year;
      month+=1;
      if(month>12) {
        month=1;
        year+=1;
      }
    }
  }
  else {
    printf("First day of INPUT_DATES (%d) must previous, or equal to, \
            of first day of OUTPUT_DATES (%d)\n",start_year,first_year);
    exit(0);
  }

  month=first_month;
  year=first_year;
  (*nmonths)=0;
  (*ndays)=0;

  for(i=first_month;i<=12*(last_year-first_year)+last_month;i++) {
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
		  float *size,
		  int *missing)
{
  FILE *fp;
  char dummy[25];
  int i,j;

  if((fp = fopen(filename, "r")) == NULL) {
    printf("Cannot open %s\n",filename);
    exit(1);
  }

  fscanf(fp,"%s %d", dummy, &(*ncols)); 
  fscanf(fp,"%s %d", dummy, &(*nrows)); 
  fscanf(fp,"%s %f", dummy, &(*xllcorner));
  fscanf(fp,"%s %f", dummy, &(*yllcorner));
  fscanf(fp,"%s %f", dummy, &(*size)); 
  fscanf(fp,"%s %d", dummy, &(*missing)); 

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
                     int skip,
		     int ndays,
		     int **CATCHMENT,
		     ARC **BASIN,
		     float *BASEFLOW,
		     float *RUNOFF,
		     float *FLOW,
		     float **UH_S,
		     LIST *STATION,
		     int nr,
		     float xllcorner,
		     float yllcorner,
		     float size,
		     char *inpath,
		     char *outpath,
		     char *workpath,
		     int decimal_places,
		     TIME *DATE,
		     float *factor_sum,
		     int first_year,
		     int first_month,
		     int irr_rout,
		     int missing)
{
  FILE *fp;
  int i,j,k,n,ii,jj;
  int row,col;
  double factor;
  char infile[500];
  char LATLON[50];
  char fmtstr[17];
  char leftover[MAXSTRING];
  double area,area_sum;
  double radius;
  float k_const;
  float dummy;
  float lat,lon;

  k_const=1.0;
  area_sum=(*factor_sum)=0.0;

  for(i=1;i<=ndays;i++) 
    FLOW[i] = 0.0;
  
  for(n=1;n<=number_of_cells;n++) { //the gridcell loop
    for(i=1;i<=ndays;i++) {
      RUNOFF[i]=0.0;
      BASEFLOW[i]=0.0;
    }
    
    ii = CATCHMENT[n][0];  //row from bottom 
    jj = CATCHMENT[n][1]; //col from left
    lat=yllcorner + ii*size - size/2.0;
    lon=xllcorner + jj*size - size/2.0;
    //printf("Makeconv cellnumber%d row%d col%d %f %f\n",n,ii,jj,lat,lon);
    
    /* Give area of box in square kilometers */
    radius = (double)EARTHRADIUS;
    area = radius*radius*fabs(size)*PI/180*            
      fabs(sin((lat-size/2.0)*PI/180)-     
	   sin((lat+size/2.0)*PI/180));
    if(CATCHMENT[n][2]!=2) area_sum += area;
    printf("area_sum=%f routed %d\n",area_sum,BASIN[ii][jj].routed);

    /* Find conversion factor for mm/day to m3/s
       and multiply by cell fraction */
    factor = BASIN[ii][jj].fraction*area/86.4;  
    (*factor_sum) += factor;

    if(BASIN[ii][jj].routed==0 || 
       (irr_rout==0 && CATCHMENT[n][2]==0)) {
      /* Make vic filename */
      //printf("HEISAN! routed %d catchment %d count %d\n",BASIN[ii][jj].routed,CATCHMENT[n][2],n);

      strcpy(infile,inpath);
      sprintf(fmtstr,"%%.%if_%%.%if",
	      decimal_places,decimal_places);
      sprintf(LATLON,fmtstr,lat,lon);
      strcat(infile,LATLON);
      printf("File %d of %d: %s\n",n,number_of_cells,infile);

      if((fp = fopen(infile,"r"))==NULL) { 
	/*printf("Cannot open file, inserting zeroes...%s \n",infile);
	for(i=1;i<=ndays;i++) {
	  DATE[i].year=0;
	  DATE[i].month=0;
	  DATE[i].day=0;
	  RUNOFF[i]=0.;
	  BASEFLOW[i]=0.;
	}*/
	printf("Cannot open file, exiting...%s \n",infile);
	exit(0);
      }
      else {
	/* Read VIC model output: 
	   <year> <month> <day> <p> <et> <runoff> <baseflow>*/
	for(i=1;i<=skip;i++) 
	  fgets(leftover,MAXSTRING,fp); 
	for(i=1;i<=ndays;i++) {
	  fscanf(fp,"%d %d %d %f %f %f %f ",
		 &DATE[i].year,&DATE[i].month,&DATE[i].day,
		 &dummy,&dummy,&RUNOFF[i],&BASEFLOW[i]);
	  //fgets(leftover,MAXSTRING,fp); 
	  //if(i==1) printf("makeconv test1 %d %d %d %f %f\n",
	//	 DATE[i].year,DATE[i].month,DATE[i].day,
	//	 RUNOFF[i],BASEFLOW[i]);
	  /* Check to be sure dates in VIC file start at same time 
	     specified in input file */
	  if(i == 1) {
	    if(DATE[i].year!=first_year || DATE[i].month!=first_month) {
	      printf("VIC output file does not match specified\n");
	      printf("period in input file.\n");
	      exit(2);
	    }
	  }
	}
	fclose(fp);
      }
    }
    else {
      if(BASIN[ii][jj].routed==2) {
	/* Flow already routed at this location, read from file */
        printf("HALLO!!! area_sum=%f routed %d\n",area_sum,BASIN[ii][jj].routed);
	strcpy(infile,workpath);
	sprintf(fmtstr,"fluxes_%%.%if_%%.%if_routed",
		decimal_places,decimal_places);
	sprintf(LATLON,fmtstr,lat,lon);
	strcat(infile,LATLON);
	printf("File %d of %d: %s\n",n,number_of_cells,infile);
	
	if((fp = fopen(infile,"r"))==NULL) { 
	  printf("Cannot open file %s \n",infile);
	  exit(0);
	}
	else {
	  /* Read routed output (m3/s): 
	     <year> <month> <day> <total runoff> */
	  for(i=1;i<=ndays;i++) {
	    fscanf(fp,"%d %d %d %f ",
		   &DATE[i].year,&DATE[i].month,&DATE[i].day,
		   &RUNOFF[i]);
	    BASEFLOW[i]=0;
	    /* Check to be sure dates in routed file start at same time 
	       as specified */
	    if(i == 1) {
	      if(DATE[i].year!=first_year || DATE[i].month!=first_month) {
		printf("Routed output file does not match specified\n");
		printf("period.\n");
		exit(2);
	      }
	    }
	  }
	  fclose(fp);
	}	 
      }
    }

    /*printf("makeconv test2 %d %d %d %f %f\n",
		 DATE[1].year,DATE[1].month,DATE[1].day,
		 RUNOFF[1],BASEFLOW[1]);*/

    if(BASIN[ii][jj].routed!=1) {
      if(BASIN[ii][jj].routed==0 || CATCHMENT[n][2]==0) {
	for(i=1;i<=ndays;i++) {
	  //if(i<10) printf("%f %f\t",RUNOFF[i],BASEFLOW[i]);
	  RUNOFF[i] = RUNOFF[i]*factor;
	  BASEFLOW[i] = BASEFLOW[i]*factor;
	  //if(i<10) printf("%f %f %f\n",RUNOFF[i],BASEFLOW[i],factor);
	}
      }
      for(i=1;i<=ndays;i++) {
	for(j=1;j<KE+UH_DAY;j++) {
	  if((i-j+1)>=1) {
	    FLOW[i] += UH_S[n][j]*(BASEFLOW[i-j+1]+RUNOFF[i-j+1]);
	  }
	 // if(i==1) printf("makeconv %f %f %f %f\n",
	//		  FLOW[i],UH_S[n][j],BASEFLOW[i-j+1],RUNOFF[i-j+1]);
	}
      }
    }

    row=CATCHMENT[n][0];
    col=CATCHMENT[n][1];
    if(row==STATION[nr].row && col==STATION[nr].col) 
       BASIN[row][col].routed=2;
    else {
      BASIN[row][col].direction=missing;
      BASIN[row][col].routed=1;
    }

    /*    printf("makeconv test3 %d %d %d %f %f %f\n",
		 DATE[1].year,DATE[1].month,DATE[1].day,
		 RUNOFF[1],BASEFLOW[1],FLOW[1]);*/


  } /* End gridcell loop */
}
/***********************************************************/
/* MakeGridUH_S                                            */
/***********************************************************/
void MakeGridUH_S(ARC **BASIN,
		  int **CATCHMENT,
		  LIST *STATION,
		  int number_of_cells,
		  int cellnumber,
		  float **UH_DAILY,
		  float ***UH,
		  float **FR,
		  float **UH_BOX,  //[number_of_cells][12]
		  float **UH_S,    //[number_of_cells][108]
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
      printf("grid cell %d out of %d, row %d col %d\n",
	     n,number_of_cells,CATCHMENT[n][0],CATCHMENT[n][1],CATCHMENT[n][2]);
      for(k=1;k<=UH_DAY;k++)
        UH_DAILY[n][k] = 0.0;
        i=CATCHMENT[n][0]; //row
        j=CATCHMENT[n][1]; //col
      for(t=1;t<=24;t++) {
	FR[t][0]=1.0/24.;
	FR[t][1]=0.0;
      }
      for(t=25;t<=TMAX;t++) {
	FR[t][0]=0.0;
	FR[t][1]=0.0;
      }

    loop:
      if((i!=STATION[cellnumber].row || j!=STATION[cellnumber].col) ||
	 (STATION[cellnumber].type==3 && CATCHMENT[cellnumber][2]==2)) { 
	for(t=1;t<=TMAX;t++) {
	  for(l=1;l<=LE;l++) {
	    if((t-l)>0) 
	      FR[t][1]=FR[t][1]+FR[t-l][0]*UH[i][j][l];
	  }
	}
	ii=BASIN[i][j].torow;
	jj=BASIN[i][j].tocol;
	i=ii;
	j=jj;
	for(t=1;t<=TMAX;t++) {
	  FR[t][0]=FR[t][1];
	  FR[t][1]=0.0;
	}
      }
      //printf("i %d row%d j %d col%d type%d\n",
      //     i,STATION[cellnumber].row,j,STATION[cellnumber].col,STATION[cellnumber].type);

      if((i!=STATION[cellnumber].row || j!=STATION[cellnumber].col) &&
	 STATION[cellnumber].type!=3) {
	goto loop;
      }

      for(t=1;t<=TMAX;t++) {
	tt=(t+23)/24;
	UH_DAILY[n][tt] += FR[t][0];
      }
      //printf("Cellnr %d row%d col%d rout %d, UH_DAILY1: %f UH_DAILY2:%f FR%f\n",
      //    n,CATCHMENT[n][0],CATCHMENT[n][1],CATCHMENT[n][2],
      //    UH_DAILY[n][1],UH_DAILY[n][2],FR[1][0]);
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
      //for(k=1;k<=KE;k++) 
      //printf("UH_S %d %d %f\n",n,k,UH_S[n][k]);
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
/*********************************/
/* MakeRoutedFile                */
/*********************************/
void MakeDirectionFile(ARC **BASIN,
		       int **CATCHMENT,
		       int nrows,
		       int ncols,
		       int number_of_cells,
		       float xllcorner,
		       float yllcorner,
		       float size,
		       int missing)
{
  FILE *fp;
  char dummy[25];
  int i,j,k;

  if((fp = fopen("dirtest.txt", "w")) == NULL) {
    printf("Cannot open dirtest.txt\n");
    exit(1);
  }
  else printf("File opened:dirtest.txt\n");

  fprintf(fp,"ncols\t %d\n",ncols);
  fprintf(fp,"nrows\t %d\n",nrows);
  fprintf(fp,"xllcorner\t %.2f\n",xllcorner);
  fprintf(fp,"yllcorner\t %.2f\n",yllcorner);
  fprintf(fp,"cellsize\t %.2f\n",size);
  fprintf(fp,"NODATA_value\t %d\n",missing);

  for(i=nrows;i>=1;i--) { //kept bounds
    for(j=1;j<=ncols;j++) { 
      fprintf(fp,"%d ",BASIN[i][j].direction); 
    }
   fprintf(fp,"\n"); 
  }
  fclose(fp);
}
/*********************************/
/* MakeRoutedFile                */
/*********************************/
void MakeRoutedFile(ARC **BASIN,
		    int **CATCHMENT,
		    int nrows,
		    int ncols,
		    int number_of_cells)
{
  FILE *fp;
  char dummy[25];
  int i,j,k;

  if((fp = fopen("test.txt", "w")) == NULL) {
    printf("Cannot open test.txt\n");
    exit(1);
  }
  else printf("File opened:test.txt\n");

  for(i=0;i<6;i++)
    fprintf(fp,"dummy 1\n"); 

  for(i=nrows;i>=1;i--) { //kept bounds
    for(j=1;j<=ncols;j++) { 
      fprintf(fp,"%d ",BASIN[i][j].routed); 
    }
   fprintf(fp,"\n"); 
  }
  fclose(fp);
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
  float green_normal; // Normalizing

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
      green_normal = 0.0;
      for(k=1;k<=LE;k++) 
	green_normal += UH[i][j][k];
      if (green_normal > 0.0) {
	for(k=1;k<=LE;k++) 
	  UH[i][j][k] = UH[i][j][k]/green_normal; //normalizing?
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
		   int *active_cells,
                   int missing)
{
  FILE *fp;
  char dummy[25];
  int i,j;

  if((fp = fopen(filename, "r")) == NULL) {
    printf("Cannot open %s\n",filename);
    exit(1);
  }

  for(i=0;i<6;i++)
    fscanf(fp,"%*s %*s"); 

  (*active_cells)=0;

  for(i=nrows;i>=1;i--) { // kept bounds 
    for(j=1;j<=ncols;j++) { 
      fscanf(fp,"%d",&BASIN[i][j].direction);
      BASIN[i][j].flag=0;
      if(BASIN[i][j].direction>missing) 
	(*active_cells)+=1;
    }
  }

  fclose(fp);

  for(i=1;i<=nrows;i++) {
    for(j=1;j<=ncols;j++) {
      if(BASIN[i][j].direction==0 || BASIN[i][j].direction==missing ) {
	BASIN[i][j].tocol=0;
	BASIN[i][j].torow=0;
      } 
      else if(BASIN[i][j].direction==1) {
         BASIN[i][j].tocol=j;
         BASIN[i][j].torow=i+1;
      } 
      else if(BASIN[i][j].direction==2) {
         BASIN[i][j].tocol=j+1;
         BASIN[i][j].torow=i+1;
      } 
      else if(BASIN[i][j].direction==3) {
         BASIN[i][j].tocol=j+1;
         BASIN[i][j].torow=i;
      } 
      else if(BASIN[i][j].direction==4) {
         BASIN[i][j].tocol=j+1;
         BASIN[i][j].torow=i-1;
      } 
      else if(BASIN[i][j].direction==5) {
         BASIN[i][j].tocol=j;
         BASIN[i][j].torow=i-1;
      } 
      else if(BASIN[i][j].direction==6) {
         BASIN[i][j].tocol=j-1;
         BASIN[i][j].torow=i-1;
      } 
      else if(BASIN[i][j].direction==7) {
         BASIN[i][j].tocol=j-1;
         BASIN[i][j].torow=i;
      } 
      else if(BASIN[i][j].direction==8) {
         BASIN[i][j].tocol=j-1;
         BASIN[i][j].torow=i+1;
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
  float fdummy;
  int i,j;
  float fvalue;
  int ivalue;

  if((fp = fopen(filename, "r")) == NULL) {
    printf("Cannot open %s\n",filename);
    exit(1);
  }
  else printf("Fraction file opened %s\n",filename); 

  for(i=0;i<6;i++)
  fscanf(fp,"%s %f", dummy, &fdummy); 

  for(i=nrows;i>=1;i--) { 
    for(j=1;j<=ncols;j++) { 
      fscanf(fp,"%f",&BASIN[i][j].fraction); 
      if(BASIN[i][j].fraction<fdummy+EPS)
	BASIN[i][j].fraction=0.;
      //if(i==15 && j==2) printf("Fraction %f\n",BASIN[i][j].fraction);
    }
  }
  fclose(fp);
}
/*********************************/
/* Reads the grid uh             */
/*********************************/
void ReadGridUH(char *filename, 
		float **UH_BOX,
		int number_of_cells,
		int **CATCHMENT)
{
  FILE *fp;
  int i,j;

  for(i=1;i<=number_of_cells;i++) { 
    if(CATCHMENT[i][2]==2) { //i.e. routed flow exist 
      UH_BOX[i][1]=1.;
      for(j=2;j<=12;j++) 
	UH_BOX[i][j]=0.;
    }
    else {
      if((fp = fopen(filename, "r")) == NULL) {
	printf("Cannot open %s\n",filename);
	exit(1);
      }
      for(j=1;j<=12;j++) 
	fscanf(fp,"%*f %f",&UH_BOX[i][j]); 
      fclose(fp);
    }
//    for(j=1;j<=12;j++) 
//      printf("%d %f\n",i,UH_BOX[i][j]); 
  }

}
/*********************************/
/* Reads reservoir locations     */
/*********************************/
void ReadReservoirLocations(char *filename, 
			    ARC **BASIN,
			    int nrows,
			    int ncols)

{
  FILE *fp;
  char dummy[25];
  float fdummy;
  int i,j;
  float fvalue;
  int ivalue;

  if((fp = fopen(filename, "r")) == NULL) {
    printf("Cannot open %s, setting values to 0\n",filename);
   for(i=1;i<=nrows;i++)  
      for(j=1;j<=ncols;j++)  
	BASIN[i][j].resloc=0;
  }

  else {
    printf("Reservoir location information file opened %s\n",filename);
    for(i=0;i<6;i++)
      fscanf(fp,"%s %f", dummy, &fdummy); 
    for(i=nrows;i>=1;i--) { 
      for(j=1;j<=ncols;j++) { 
	fscanf(fp,"%d",&ivalue); 
	if(ivalue<EPS)
	  BASIN[i][j].resloc=0;
	else BASIN[i][j].resloc=ivalue;
      }
    }
    fclose(fp);
  }
}
/*********************************/
/* Reads the routed cells     */
/*********************************/
void ReadRouted(char *filename, 
		ARC **BASIN,
		int nrows,
		int ncols)

{
  FILE *fp;
  char dummy[25];
  float fdummy;
  int i,j;
  float fvalue;
  int ivalue;

  if((fp = fopen(filename, "r")) == NULL) {
    printf("Cannot open %s, setting values to zero\n",filename);
   for(i=1;i<=nrows;i++)  
      for(j=1;j<=ncols;j++)  
	BASIN[i][j].routflag=0;
  }

  else {
    printf("Routing information file opened %s\n",filename);
    for(i=0;i<6;i++)
      fscanf(fp,"%s %f", dummy, &fdummy); 
    for(i=nrows;i>=1;i--) { 
      for(j=1;j<=ncols;j++) { 
	fscanf(fp,"%d",&ivalue); 
	if(ivalue<EPS)
	  BASIN[i][j].routflag=0;
	else BASIN[i][j].routflag=ivalue;
      }
    }
    fclose(fp);
  }
}
/*********************************/
/* Reads the station file        */
/*********************************/
void ReadStation(char *filename,
		 ARC **BASIN,
		 LIST *STATION,
		 int nrows,
		 int ncols,
		 char uhstring[20][20],
		 int *number_of_stations)
{
  FILE *fp;
  int i,j,irow,icol;
  int already_routed;

  if((fp = fopen(filename, "r")) == NULL) {
    printf("Cannot open %s\n",filename);
    exit(1);
  }

  for(i=1;i<=nrows;i++) 
    for(j=1;j<=ncols;j++)    
      BASIN[i][j].routed=BASIN[i][j].routflag;

  i=1;
  while(!feof(fp)) {
    fscanf(fp,"%d %d %s %d %d %f %d",
	   &STATION[i].id,&already_routed,
           STATION[i].name,&STATION[i].col,
	   &STATION[i].row,&STATION[i].area,&STATION[i].type); 
    fscanf(fp,"%s",uhstring[i]);
    printf("Station name: %s rout now:%d routed before:%d row:%d col:%d type:%d\n",
	   STATION[i].name,STATION[i].id,already_routed,STATION[i].row,
	   STATION[i].col,STATION[i].type);
    if(STATION[i].id==1 && already_routed==1) 
      STATION[i].id=0;
    if(already_routed==1) {
        printf("Station already routed: %s %d %d\n",
                STATION[i].name,STATION[i].row,STATION[i].col);
	SearchRouted(BASIN,STATION[i].row,STATION[i].col,nrows,ncols);
    }
    irow=STATION[i].row;
    icol=STATION[i].col;
    if(BASIN[irow][icol].resloc==1 && STATION[i].type==1) {
      STATION[i].type=2;
    printf("Station name, type 2: %s rout now:%d row:%d col:%d type:%d resloc:%d\n",
	   STATION[i].name,STATION[i].id,STATION[i].row,
	   STATION[i].col,STATION[i].type,BASIN[irow][icol]);
    }
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
  else printf("Xmask file opened %s\n",filename);

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
/***********************************/
/* Reservoir                       */
/***********************************/
void ReservoirRouting(char *filename,
		      float *FLOW,
		      float *R_FLOW,
		      int ndays,
		      TIME *DATE,
		      int row,
		      int col)
{
  FILE *fp;
  int i,mm;
  double storage,outflow,inflow,demand,oldstorage,oldflow;
  double temp_storage;
  double pow_rel,surplus_storage,spill;
  float dummy;
  float max_storage;
  float min_storage;
  float min_storage_use[13];
  float max_head;
  float min_head;
  float max_prod;
  float power_demand[13];  /* Input demand must be given in MW */
  float water_demand[13]; /* Input demand must be given in MCM/day */
  float RHO = 1000;
  float CONV_M3S_MCM = 0.0864; /* Conversion from m3/s to MCM/day */
  float power_prod;
  double possible_flow;
  float head;
  float outmcm;
  int irow,icol,type;
	
  if((fp = fopen(filename, "r")) == NULL) {
    printf("Cannot open %s\n",filename);
    exit(1);
  }
  else printf("File opened, reservoir routing information: %s\n",filename);

  for(i=0;i<12;i++) 
    fscanf(fp,"%*s ");

  while(fscanf(fp,"%d %d %*s %d %f %f %f %f %f ",
	       &icol,&irow,&type,&max_storage,&min_storage,
	       &max_head,&min_head,&max_prod)!=EOF) {
    printf("irow%d row%d icol%d col%d type%d max_prod%f\n",
	   irow,row,icol,col,type,max_prod);
    for(i=1;i<=12;i++) 
      fscanf(fp,"%f ",&power_demand[i]);
    for(i=1;i<=12;i++) 
      fscanf(fp,"%f ",&water_demand[i]);
    for(i=1;i<=12;i++) 
      fscanf(fp,"%f ",&min_storage_use[i]);

    if(irow==row && icol==col) {
      storage=1.0*max_storage; 
      printf("Storage at first time step: %f\n",storage);

      for(i=1;i<=ndays;i++) {
	mm=DATE[i].month;
	oldstorage=storage;
	inflow=(double)FLOW[i]*0.0864; //from m3/s to MCM, daily input data
					 
        temp_storage=oldstorage+inflow; 
	storage=min(max_storage,temp_storage);

	if(storage>=(min_storage_use[mm]/100)*max_storage) 
	  pow_rel=storage-((min_storage_use[mm]/100)*max_storage);
	if(storage<(min_storage_use[mm]/100)*max_storage) 
	  pow_rel=0;
    
	head=min_head+max_head*storage/max_storage; 

	if(type==1) { /* Water demand given in MCM/day */
	  if(water_demand[mm]<pow_rel) 
	    pow_rel=water_demand[mm];
	}

	if(type==2) { /* Hydropower, demand given in MW */
	   power_prod=(pow_rel/0.0864)*EFF*GE*head/1000; //in MW
	   if(power_prod>=power_demand[mm]) {
	     power_prod=power_demand[mm];
	     outflow=power_demand[mm]*1000/(GE*EFF*head/0.0864);
	     pow_rel=outflow;
	   }
	} /* end if(type==2) */
      
	if(type==3) { /* Combination type, water demand in dry season, 
			 hydropower in wet season. I.e. only one 
			 demand type at a time */
	  if(water_demand[mm]>0) {
	    if(water_demand[mm]<pow_rel) 
	      pow_rel=water_demand[mm];
	  }
	  else {  
	    power_prod=(pow_rel/0.0864)*EFF*GE*head/1000; /*in MW*/
	    if(power_prod>=power_demand[mm]) {
	      power_prod=power_demand[mm];
	      outflow=power_demand[mm]*1000/(GE*EFF*head/0.0864);
	      pow_rel=outflow;
	    }
	  }
	} /* end if(type==3) */
      

	surplus_storage=0.;
    
	if(inflow>(max_storage-oldstorage+pow_rel)) 
	  surplus_storage=inflow-(max_storage-oldstorage) - pow_rel;
      
	temp_storage=oldstorage+inflow-pow_rel;
	storage=min(max_storage,temp_storage);
    
	spill=surplus_storage;
	
	outflow=spill+pow_rel; //MCM
        outmcm=outflow;				 
	outflow/=0.0864;
	R_FLOW[i]=outflow;

	/*      if(i<100 || i>7000) printf("i%d inflow(m):%.2f outflow(m):%.2f inflow(M):%.2f outflow(M):%.2f storage:%.2f spill:%.2f power:%.2f pow_rel:%.2f head:%.1f\n",
	         i,FLOW[i],R_FLOW[i],inflow,outmcm,storage,spill,power_prod,pow_rel,head);*/
      }
      printf("Storage at last time step: %f\n",storage);
    }
  }

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
		     int type,
		     int *number_of_cells,
		     int *upstream_cells)
{
  int i,j,k,l;
  int ii,jj,iii,jjj;
  int count;
  int missing=-9;
  int rank;
  int irow,icol;
 
  count = 0;
  (*upstream_cells)=0;

  for(i=1;i<=nrows;i++) {
    for(j=1;j<=ncols;j++) {
      ii=i;
      jj=j;
    loop:
      if(ii>nrows || ii<1 || jj>ncols || jj<1) {
	printf("Outside basin %d %d %d %d\t",ii,jj,nrows,ncols);
      }
      else {
	  if(ii==row && jj==col) { 
	    count+=1;
	    CATCHMENT[count][0]=i;
	    CATCHMENT[count][1]=j;
	    if(BASIN[i][j].routed==2) 
	      CATCHMENT[count][2]=2;
	    //printf("Hoppsan %d %d %d %d %d\n",i,j,BASIN[i][j].routed,count,CATCHMENT[count][2]);
	  }
	  else { 
	    /*check if the current ii,jj cell routes down
	      to the subbasin outlet point, following the
	      flow direction from each cell;
	      if you get here no_of_cells increment and you 
	      try another cell*/ 
	    if(BASIN[ii][jj].tocol!=0 &&    
	       BASIN[ii][jj].torow!=0) { 
	      iii = BASIN[ii][jj].torow;         
	      jjj = BASIN[ii][jj].tocol;         
	      ii  = iii;                  
	      jj  = jjj;                  
	      //printf("SearchCatchment %d %d\n",ii,jj);
	      goto loop;
	    }
	  }
      }
    }
  }

  (*number_of_cells)=count;
  printf("Upstream grid cells from present station: %d\n", 
	 (*number_of_cells));

  if(type==3) { /* Irrigated part of cell */
    /*for(i=3;i<=(*number_of_cells);i++) {
      irow=CATCHMENT[i][0];
      icol=CATCHMENT[i][1];
      BASIN[irow][icol].routed=1;
    }*/
    (*upstream_cells)=(*number_of_cells);
    (*number_of_cells)=2;
    CATCHMENT[1][0]=row;
    CATCHMENT[1][1]=col;
    CATCHMENT[1][2]=0;  
    CATCHMENT[2][0]=row;
    CATCHMENT[2][1]=col;
    CATCHMENT[2][2]=2;    
    printf("Irrigated part of cell\n");    
  }

  if(SORT) { /*Sort Catchment*/
    printf("Sorting Catchment......\n");
    count=0;
    do {
      for(i=1;i<=nrows;i++) {
	for(j=1;j<=ncols;j++) {
	  for(k=1;k<=(*number_of_cells);k++) {
	    if(CATCHMENT[k][0]==i && CATCHMENT[k][1]==j) {
	      if(BASIN[i][j].flag!=missing) {
		if(BASIN[i-1][j].direction==1) BASIN[i][j].flag=1;
		if(BASIN[i-1][j+1].direction==8) BASIN[i][j].flag=1;
		if(BASIN[i][j+1].direction==7) BASIN[i][j].flag=1;
		if(BASIN[i+1][j+1].direction==6) BASIN[i][j].flag=1;
		if(BASIN[i+1][j].direction==5) BASIN[i][j].flag=1;
		if(BASIN[i+1][j-1].direction==4) BASIN[i][j].flag=1;
		if(BASIN[i][j-1].direction==3) BASIN[i][j].flag=1;
		if(BASIN[i-1][j-1].direction==2) BASIN[i][j].flag=1;
		if(BASIN[i][j].flag==0) {
		  count++;
		  CATCHMENT[k][3]=count;
		  printf("rank: %d %d %d\n",i,j,CATCHMENT[k][3]);
		}
	      }
	    }
	  }
	  //printf("%d %d %d %d %d\n",i,j,count,nrows,ncols);
	}
      }
      for(i=1;i<=nrows;i++) { // Reset cells
	 for(j=1;j<=ncols;j++) {
	   if(BASIN[i][j].flag==0) {
	     BASIN[i][j].flag=missing;
	     BASIN[i][j].direction=missing;
	   }
	   if(BASIN[i][j].flag!=missing) BASIN[i][j].flag=0;
	 }
      }
      if(count<250) printf("%d %d %d %d %d\n",i,j,count,nrows,ncols);
    }
    while(count<(*number_of_cells));

    for(i=1;i<(*number_of_cells);i++) {
      for(j=(*number_of_cells-1);j>=i;j--) {
	if(CATCHMENT[j-1][3]>CATCHMENT[i][3]) {
	  row=CATCHMENT[j-1][0];
	  col=CATCHMENT[j-1][1];
	  rank=CATCHMENT[j-1][3];
	  CATCHMENT[j-1][0]=CATCHMENT[j][0];
	  CATCHMENT[j-1][1]=CATCHMENT[j][1];
	  CATCHMENT[j-1][3]=CATCHMENT[j][3];
	  CATCHMENT[j][0]=row;
	  CATCHMENT[j][1]=col;	
	  CATCHMENT[j][3]=rank;	
	}
      }
    }

  } /* end if(SORT) */

}
/***********************************************/
/* SearchRouted                                */
/* Purpose: Find already routed cells in basin */
/***********************************************/
void SearchRouted(ARC **BASIN,
		  int row,
		  int col,
		  int nrows,
		  int ncols)
{
  int i,j;
  int ii,jj,iii,jjj;
  int count;

  count = 0;

  for(i=1;i<=nrows;i++) {
    for(j=1;j<=ncols;j++) {
      ii=i;
      jj=j;
    loop:
      if(ii>nrows || ii<1 || jj>ncols || jj<1) {
	printf("Outside basin\t");
      }
      else {
	  if(ii==row && jj==col) { 
	    count+=1;
	    BASIN[i][j].routed=1;
	    BASIN[row][col].routed=2;
	  }
	  else { 
	    /*check if the current ii,jj cell routes down
	      to the subbasin outlet point, following the
	      flow direction from each cell;
	      if you get here no_of_cells increment and you 
	      try another cell*/ 
	    if(BASIN[ii][jj].tocol!=0 &&    
	       BASIN[ii][jj].torow!=0) { 
	      iii = BASIN[ii][jj].torow;         
	      jjj = BASIN[ii][jj].tocol;         
	      ii  = iii;                  
	      jj  = jjj;                  
	      goto loop;
	    }
	  }
      }
    }
  }

  printf("Grid cells already routed: %d\n",count);
}
/***************************************************************/
/* WriteData                                                   */
/***************************************************************/
void WriteData(float *FLOW,
	       float *R_FLOW,
	       char *name,
	       char *outpath,
	       int ndays,
	       int nmonths,
	       TIME *DATE,
	       float factor_sum,
	       int first_year,
	       int first_month,
	       int last_year,
	       int last_month,
               int start_year,
	       float lat,
	       float lon,
	       int type,
	       int decimal_places)

{
  FILE *fp,*fp_mm,*fp_routed;
  char *filename_fp,*filename_fp_mm,*filename_fp_routed;
  char fmtstr[17];
  char LATLON[50];
  float MONTHLY[MAXYEARS+1][13];  /*variables for monthly means*/
  float YEARLY[13];
  float R_MONTHLY[MAXYEARS+1][13];
  float R_YEARLY[13];
  float days;
  int DaysInMonth[13] = { 0,31,28,31,30,31,30,31,31,30,31,30,31 };
  int nyears[13];
  int feb_days,feb_nrs;
  int i,j,k;
  int yy,mm;
  int leap_year;
  int count_years;

  filename_fp = (char*)calloc(100,sizeof(char));
  filename_fp_mm = (char*)calloc(100,sizeof(char));
  filename_fp_routed = (char*)calloc(100,sizeof(char));

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

  strcpy(filename_fp_routed,outpath);
  sprintf(fmtstr,"fluxes_%%.%if_%%.%if_routed",
	  decimal_places,decimal_places);
  sprintf(LATLON,fmtstr,lat,lon);
  strcat(filename_fp_routed,LATLON);
  if((fp_routed = fopen(filename_fp_routed, "w")) == NULL) {
    printf("Cannot open %s\n",filename_fp_routed);
    exit(1);
  }

  /* Initialize */
  for(i=0;i<=12;i++) {
    YEARLY[i]=0.;
    R_YEARLY[i]=0.;    
    nyears[i]=0;
    for(j=0;j<=MAXYEARS;j++) {
      MONTHLY[j][i]=0.;
      R_MONTHLY[j][i]=0.;
    }
  }

  count_years=first_year;
  if(last_year==first_year) {
    for(i=first_month;i<=last_month;i++) 
      nyears[i]+=1;
  }
  else {
    for(i=first_month;i<=12;i++) 
      nyears[i]+=1;
    count_years++;
    for(i=1;i<=last_month;i++) 
      nyears[i]+=1;
    count_years++;
    for(k=count_years;k<=last_year;k++) {
      for(i=1;i<=12;i++) 
	nyears[i]+=1;
    }
  }

  /* Write daily data and store monthly values */
  for(i=1;i<=ndays;i++) {
    if((DATE[i].year>first_year && DATE[i].year<last_year) 
       || (DATE[i].year==first_year && DATE[i].month>=first_month)
       || (DATE[i].year==last_year && DATE[i].month<=last_month)) {
      yy=DATE[i].year-start_year;
      mm=DATE[i].month;
      MONTHLY[yy][mm]+=FLOW[i];
      YEARLY[mm]+=FLOW[i];
      R_MONTHLY[yy][mm]+=R_FLOW[i];
      R_YEARLY[mm]+=R_FLOW[i];
      if(type==2) {
	fprintf(fp,"%d %d %d %f %f\n",
		DATE[i].year,DATE[i].month,DATE[i].day,R_FLOW[i],FLOW[i]);
	fprintf(fp_mm,"%d %d %d %f\n",
		DATE[i].year,DATE[i].month,DATE[i].day,R_FLOW[i]/factor_sum);
	fprintf(fp_routed,"%d %d %d %f\n",
		DATE[i].year,DATE[i].month,DATE[i].day,R_FLOW[i]);
      }
      else {
	if(i==1) 
	  printf("WriteData %d %d %d %f %f\n",
		 DATE[i].year,DATE[i].month,DATE[i].day,FLOW[i],R_FLOW[i]);
	fprintf(fp,"%d %d %d %f %f\n",
		DATE[i].year,DATE[i].month,DATE[i].day,FLOW[i],R_FLOW[i]);
	fprintf(fp_mm,"%d %d %d %f\n",
		DATE[i].year,DATE[i].month,DATE[i].day,FLOW[i]/factor_sum);
	fprintf(fp_routed,"%d %d %d %f\n",
		DATE[i].year,DATE[i].month,DATE[i].day,FLOW[i]);
      }
    }
  }

  fclose(fp);
  fclose(fp_mm);
  fclose(fp_routed);

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
  feb_days=feb_nrs=0;
  i=first_year;
  leap_year=IsLeapYear(i);
  if(first_year==last_year) {
    for(j=first_month;j<=last_month;j++) {
      days=DaysInMonth[j];
      if(j==2) {
	days=DaysInMonth[j]+leap_year;
	feb_days+=days;
	feb_nrs+=1;
      }
      if(type==2) {
	fprintf(fp,"%d %d %f %f\n",
		i,j,R_MONTHLY[i-start_year][j]/days,
		MONTHLY[i-start_year][j]/days);
	fprintf(fp_mm,"%d %d %f %f\n",
		i,j,R_MONTHLY[i-start_year][j]/factor_sum,
		MONTHLY[i-start_year][j]/factor_sum);
      }
      else {
	fprintf(fp,"%d %d %f %f\n",
		i,j,MONTHLY[i-start_year][j]/days,
		R_MONTHLY[i-start_year][j]/days);
	fprintf(fp_mm,"%d %d %f %f\n",
	      i,j,MONTHLY[i-start_year][j]/factor_sum,
		R_MONTHLY[i-start_year][j]/factor_sum);
      }
    }    
  }
  else {
    for(j=first_month;j<=12;j++) {
      days=DaysInMonth[j];
      if(j==2) {
        days=DaysInMonth[j]+leap_year;
	feb_days+=days;
	feb_nrs+=1;
      }
      if(type==2) {
	fprintf(fp,"%d %d %f %f\n",
		i,j,R_MONTHLY[i-start_year][j]/days,
		MONTHLY[i-start_year][j]/days);
	fprintf(fp_mm,"%d %d %f %f\n",
		i,j,R_MONTHLY[i-start_year][j]/factor_sum,
		MONTHLY[i-start_year][j]/factor_sum);
      }
      else {
	fprintf(fp,"%d %d %f %f\n",
		i,j,MONTHLY[i-start_year][j]/days,
		R_MONTHLY[i-start_year][j]/days);
	fprintf(fp_mm,"%d %d %f %f\n",
		i,j,MONTHLY[i-start_year][j]/factor_sum,
		R_MONTHLY[i-start_year][j]/factor_sum);
      }
    }
    for(i=first_year-start_year+1;i<last_year-start_year;i++) {
      leap_year=IsLeapYear(i+start_year);
      for(j=1;j<=12;j++) {
	days=DaysInMonth[j];
	if(j==2) {
	  days=DaysInMonth[j]+leap_year;
	  feb_days+=days;
	  feb_nrs+=1;
	}
	if(type==2) {
	  fprintf(fp,"%d %d %f %f\n",
		  i+start_year,j,R_MONTHLY[i][j]/days,
		  MONTHLY[i][j]/days);
	  fprintf(fp_mm,"%d %d %f %f\n",
		  i+start_year,j,R_MONTHLY[i][j]/factor_sum,
		  MONTHLY[i][j]/factor_sum);
	}
	else  {
	  fprintf(fp,"%d %d %f %f\n",
		  i+start_year,j,MONTHLY[i][j]/days,
		  R_MONTHLY[i][j]/days);
	  fprintf(fp_mm,"%d %d %f %f\n",
		  i+start_year,j,MONTHLY[i][j]/factor_sum,
		  R_MONTHLY[i][j]/factor_sum);
	}
      }
    }
    i=last_year;
    leap_year=IsLeapYear(i);
    for(j=1;j<=last_month;j++) {
      days=DaysInMonth[j];
      if(j==2) {
       days=DaysInMonth[j]+leap_year;
	feb_days+=days;
	feb_nrs+=1;
      }
      if(type==2) {
	fprintf(fp,"%d %d %f %f\n",
		i,j,R_MONTHLY[i-start_year][j]/days,
		MONTHLY[i-start_year][j]/days);
	fprintf(fp_mm,"%d %d %f %f\n",
		i,j,R_MONTHLY[i-start_year][j]/factor_sum,
		MONTHLY[i-start_year][j]/factor_sum);
      }
      else {	
	fprintf(fp,"%d %d %f %f\n",
		i,j,MONTHLY[i-start_year][j]/days,
		R_MONTHLY[i-start_year][j]/days);
	fprintf(fp_mm,"%d %d %f %f\n",
		i,j,MONTHLY[i-start_year][j]/factor_sum,
		R_MONTHLY[i-start_year][j]/factor_sum);
      }
    }   
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
    days=DaysInMonth[i];
    if(i==2) days=(float)feb_days/(float)feb_nrs;
    if(type==2) {
      fprintf(fp,"%d %f %f\n",
	      i,R_YEARLY[i]/(nyears[i]*days),
	      YEARLY[i]/(nyears[i]*days));
      fprintf(fp_mm,"%d %f %f\n",
	      i,R_YEARLY[i]/(nyears[i]*factor_sum),
	      YEARLY[i]/(nyears[i]*factor_sum));
    }
    else {
      fprintf(fp,"%d %f %f\n",
	      i,YEARLY[i]/(nyears[i]*days),
	      R_YEARLY[i]/(nyears[i]*days));
      fprintf(fp_mm,"%d %f %f\n",
	      i,YEARLY[i]/(nyears[i]*factor_sum),
	      R_YEARLY[i]/(nyears[i]*factor_sum));
    }
  }

  fclose(fp);
  fclose(fp_mm);
}


