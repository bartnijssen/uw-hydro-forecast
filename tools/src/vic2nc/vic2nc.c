#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <netcdf.h>
#include <time.h>
#include <sys/types.h>
#include <dirent.h>

#ifndef FALSE
#define FALSE 0
#define TRUE !FALSE
#endif

#define NODATA_INT -9999
#define NODATA_FLOAT 1.e20
#define MAXVAR 25
#define MAXDIM 5
#define MAXSTRING 500
#define MAXLEV 15
#define NGLOBALS 7
#define LEAPYR(y) (y%400==0) || ( (y%4==0) && (y%100!=0) )

char *optstring = "i:p:m:o:g:t:clL";
static int dmonth[12]={31,28,31,30,31,30,31,31,30,31,30,31};
int NRECS, NSECS, NFILES, NLEVELS, NCOLS, NROWS, NCELLS;
int LEVMIN, LEVMAX, MINCOL, MAXCOL, MINROW, MAXROW;
int NUM3d, NUM4d;
int GRIDFILE = 0;
int TIMESPAN = 0;
int COMPRESS = 0;
int NO_LEAP_OUT = 0;
char FORMAT[10];
int ENDIAN;

struct VarAtt {
  char read[5];
  char name[15];
  char units[15];
  char z_dep[5];
  char sign[8];
  float mult;
  char long_name[40];
  int id;
};

struct GridInfo {
  int landmask;
  int cellid;
  int row;
  int col;
  float lat;
  float lon;
};

// Function prototypes.

void Read_Args(int, char **, char *, char *, char *, char *, char *, char *); 
void Usage(char *);
void Read_Metadata(char *, char **, struct tm *, struct tm *, float *,
  char *, char *, char *, char *, float *, char *, char *, struct VarAtt *);
struct GridInfo *Read_Gridfile(char *);
struct GridInfo *Calc_Grid(char *, char *);
int numeric(const void *, const void *);
int alphabetic(const void *, const void *);
void Check_VIC_Files(char *, char *, struct GridInfo *, FILE **);
void Compute_NFILES(struct tm *, struct tm *, char *);
void Compute_File_Time_Properties(char *, struct tm *, struct tm *, struct tm *, int, char *, int, int, struct tm *, struct tm *);
void Read_VIC(struct GridInfo *, FILE **, struct VarAtt *, float **, float ***);
void Open_NetCDF(char *, char *, char *, char *, char *, char *, char *, float,
  struct VarAtt *, char **, struct GridInfo *, float *, int *, int *, int *);
void Write_NetCDF(int, struct GridInfo *, int, int, struct VarAtt *, int, float, int, float **, float ***);
void Close_VIC_Files(FILE **);
long long diff_date(struct tm, struct tm);
long long dt2sec(struct tm, int, char *);
int julian(int, int, int);
void add_sec_date(struct tm, long long, struct tm *);
void Date_2_TM(char *, struct tm *);
void Time_2_TM(char *, struct tm *);
void Handle_Error(int);

//*************************************************************************************************
// Begin main program.
//*************************************************************************************************

int main(int argc, char *argv[])
{
  char inpath[150], prefix[150], outfile[200], outprefix[200], metafile[100], gridfile[100], timespan[10];
  FILE **infilehandle;
  int i, j, k, l, t, g, d, h, v;
  float levels[MAXLEV];
  float time;
  int timestep;
  float **var3d;
  float ***var4d;
  float dt;
  char time_units[10];
  char file_start_time_str[19];
  char time_units_str[40];
  char timestep_units_str[40];
  char lev_units[5];
  char lev_long_name[20];
  char lev_positive[5];
  char *global_atts[NGLOBALS];
  struct tm *data_start_time;
  struct tm *data_end_time;
  struct tm *file_start_time;
  struct tm *file_end_time;
  struct tm *first_rec_time;
  struct tm *last_rec_time;
  struct tm *curr_rec_time;
  struct VarAtt var_atts[MAXVAR];
  struct GridInfo *grid;
  int ncid, timevarid, timestepvarid, status;
  long long cumulative_recs, cumulative_secs;
  int fidx;
  long long dsec;
   
  // Initialize FORMAT and ENDIAN
  strcpy(FORMAT,"ASCII");
  ENDIAN = 1; // LITTLE

  // Allocate param structures
  for (g=0; g<NGLOBALS; g++) {
    global_atts[g] = (char *)calloc(MAXSTRING,sizeof(char));
  }

  // Allocate time structures
  data_start_time = (struct tm*)malloc(sizeof(struct tm));
  data_end_time = (struct tm*)malloc(sizeof(struct tm));
  file_start_time = (struct tm*)malloc(sizeof(struct tm));
  file_end_time = (struct tm*)malloc(sizeof(struct tm));
  first_rec_time = (struct tm*)malloc(sizeof(struct tm));
  last_rec_time = (struct tm*)malloc(sizeof(struct tm));
  curr_rec_time = (struct tm*)malloc(sizeof(struct tm));

  // Initialize data start/end times
  data_start_time->tm_year = 0;
  data_start_time->tm_mon = 0;
  data_start_time->tm_mday = 1;
  data_start_time->tm_hour = 0;
  data_start_time->tm_min = 0;
  data_start_time->tm_sec = 0;
  data_start_time->tm_isdst = 0;
  data_end_time->tm_year = 0;
  data_end_time->tm_mon = 0;
  data_end_time->tm_mday = 1;
  data_end_time->tm_hour = 0;
  data_end_time->tm_min = 0;
  data_end_time->tm_sec = 0;
  data_end_time->tm_isdst = 0;
  file_start_time->tm_year = 0;
  file_start_time->tm_mon = 0;
  file_start_time->tm_mday = 1;
  file_start_time->tm_hour = 0;
  file_start_time->tm_min = 0;
  file_start_time->tm_sec = 0;
  file_start_time->tm_isdst = 0;
  file_end_time->tm_year = 0;
  file_end_time->tm_mon = 0;
  file_end_time->tm_mday = 1;
  file_end_time->tm_hour = 0;
  file_end_time->tm_min = 0;
  file_end_time->tm_sec = 0;
  file_end_time->tm_isdst = 0;
  first_rec_time->tm_year = 0;
  first_rec_time->tm_mon = 0;
  first_rec_time->tm_mday = 1;
  first_rec_time->tm_hour = 0;
  first_rec_time->tm_min = 0;
  first_rec_time->tm_sec = 0;
  first_rec_time->tm_isdst = 0;
  last_rec_time->tm_year = 0;
  last_rec_time->tm_mon = 0;
  last_rec_time->tm_mday = 1;
  last_rec_time->tm_hour = 0;
  last_rec_time->tm_min = 0;
  last_rec_time->tm_sec = 0;
  last_rec_time->tm_isdst = 0;

  //
  // Get input params and metadata
  //

  // Read cmdline parameters
  Read_Args(argc, argv, inpath, prefix, metafile, outprefix, gridfile, timespan);

  // Read the metadata file
  Read_Metadata(metafile, global_atts, data_start_time, data_end_time, &dt, time_units, time_units_str, timestep_units_str, lev_units, levels, lev_long_name, lev_positive, var_atts);

  // Compute grid characteristics
  if (GRIDFILE) {
    // Read the grid file
    grid = Read_Gridfile(gridfile);
  }
  else {
    // Determine grid characteristics from lat and lon in VIC filenames
    grid = Calc_Grid(inpath, prefix);
  }

  // Allocate filehandle array
  if ( (infilehandle = (FILE **)calloc(NCELLS,sizeof(FILE *))) == NULL) {
    fprintf(stderr, "ERROR: cannot allocate sufficient number of file pointers (descriptors) to cover all input files\n");
    exit(1);
  }

  // Echo params to user
  fprintf(stdout,"\n");
  fprintf(stdout,"** Converting from VIC to NetCDF **\n");
  fprintf(stdout,"\n");
  fprintf(stdout,"Input: %s/%s*\n",inpath,prefix);
  if (TIMESPAN) {
    fprintf(stdout,"Output: %s*\n",outprefix);
  }
  else {
    fprintf(stdout,"Output: %s\n",outprefix);
  }
  fprintf(stdout,"Metadata file: %s\n",metafile);
  if (GRIDFILE)
    fprintf(stdout,"Grid file: %s\n",gridfile);
  fprintf(stdout,"\n");
  fprintf(stdout,"** Dimensions **\n");
  fprintf(stdout,"\n");
  fprintf(stdout,"Grid: rows %d min %d max %d\n",NROWS,MINROW,MAXROW);
  fprintf(stdout,"Grid: cols %d min %d max %d\n",NCOLS,MINCOL,MAXCOL);
  fprintf(stdout,"Total number of cells in grid (rows*columns): %d\n",NROWS*NCOLS);
  fprintf(stdout,"Number of valid grid cells in land mask: %d\n",NCELLS);
  if (COMPRESS) {
    fprintf(stdout,"Compression by gathering: ON\n");
  }
  else {
    fprintf(stdout,"Compression by gathering: OFF\n");
  }
  fprintf(stdout,"Number of vertical levels: %d\n",NLEVELS);
  fprintf(stdout,"Timestep length (%s): %f\n",time_units,dt);
  fprintf(stdout,"Start date: %04d-%02d\n",data_start_time->tm_year+1900,data_start_time->tm_mon+1);
  fprintf(stdout,"End date: %04d-%02d\n",data_end_time->tm_year+1900,data_end_time->tm_mon+1);
  if (!strcasecmp(FORMAT,"ASCII")) {
    fprintf(stdout,"Format: ASCII\n");
  }
  else if (!strcasecmp(FORMAT,"SCIENTIFIC")) {
    fprintf(stdout,"Format: SCIENTIFIC\n");
  }
  else if (!strcasecmp(FORMAT,"BINARY")) {
    fprintf(stdout,"Format: BINARY\n");
  }
  if (TIMESPAN) {
    if (!strcmp(timespan,"m")) {
      fprintf(stdout,"Each output file will contain 1 month of data\n");
    }
    else {
      fprintf(stdout,"Each output file will contain 1 year of data\n");
    }
  }
  else {
    fprintf(stdout,"All output data will be written to 1 output file\n");
  }
  fprintf(stdout,"\n");
  fprintf(stdout,"** Variables **\n");
  fprintf(stdout,"\n");
  fprintf(stdout,"Name            Units           Z-dep\n");
  for (v=0; v<(NUM3d+NUM4d); v++) {
    if (!strcasecmp(var_atts[v].read,"TRUE")) {
      fprintf(stdout,"%-15.15s %-15.15s %-5.5s\n", var_atts[v].name,var_atts[v].units,var_atts[v].z_dep);
    }
  }
  fprintf(stdout,"\n");

  //
  // Translation Section
  //

  // Try to open all of the VIC files; build the array of input file handles.
  Check_VIC_Files(inpath, prefix, grid, infilehandle);

  // Allocate array of 3D variables
  // Here, this array is compressed to save space;
  // dimensions are: [variable,cell#].
  // In the output file, the variables in the array
  // will have dimensions [timestep, cell#] (compressed)
  // or [timestep, y, x] (uncompressed)
  if ( (var3d = (float**)calloc(NUM3d,sizeof(float*))) == NULL ) {
    fprintf(stderr,"ERROR: cannot allocate sufficient memory for data array\n");
    exit(1);
  }
  for(v=0; v<NUM3d; v++) {
    if ( (var3d[v] = (float*)calloc(NCELLS,sizeof(float))) == NULL ) {
      fprintf(stderr,"ERROR: cannot allocate sufficient memory for data array\n");
      exit(1);
    }
  }

  // Allocate array of 4D variables
  // This array is compressed to save space;
  // dimensions are: [variable,cell#,level].
  // In the output file, the variables in the array
  // will have dimensions [timestep, z, cell#] (compressed)
  // or [timestep, z, y, x] (uncompressed)
  if (NUM4d > 0) {
    if ( (var4d = (float***)calloc(NUM4d,sizeof(float**))) == NULL ) {
      fprintf(stderr,"ERROR: cannot allocate sufficient memory for data array\n");
      exit(1);
    }
    for(v=0; v<NUM4d; v++) {
      if ( (var4d[v] = (float**)calloc(NCELLS,sizeof(float*))) == NULL ) {
        fprintf(stderr,"ERROR: cannot allocate sufficient memory for data array\n");
        exit(1);
      }
      for(k=0; k<NCELLS; k++) {
        if ( (var4d[v][k] = (float*)calloc(NLEVELS,sizeof(float))) == NULL ) {
          fprintf(stderr,"ERROR: cannot allocate sufficient memory for data array\n");
          exit(1);
        }
      }
    }
  }

  // Compute levels
  for (l=0; l<NLEVELS; l++) {
    levels[l] = l;
  }
  LEVMIN = LEVMAX = levels[0];
  for (i=1; i<NLEVELS; i++) {
    LEVMIN = (levels[i] < LEVMIN) ? levels[i] : LEVMIN;
    LEVMAX = (levels[i] > LEVMAX) ? levels[i] : LEVMAX;
  }

  // Compute number of output timespans between data start and end dates
  Compute_NFILES(data_start_time, data_end_time, timespan);

  // Initialize time counters
  cumulative_secs = 0;
  first_rec_time->tm_year = data_start_time->tm_year;
  first_rec_time->tm_mon = data_start_time->tm_mon;
  first_rec_time->tm_mday = data_start_time->tm_mday;
  first_rec_time->tm_hour = data_start_time->tm_hour;
  first_rec_time->tm_min = data_start_time->tm_min;
  first_rec_time->tm_sec = data_start_time->tm_sec;

  // Loop over output timespans
  for (fidx=0; fidx<NFILES; fidx++) {

    // Compute file start date/time
    add_sec_date(*data_start_time, cumulative_secs, file_start_time);
    sprintf(file_start_time_str,"%04d-%02d-%02d %02d:%02d:%02d",
      file_start_time->tm_year+1900,
      file_start_time->tm_mon+1,
      file_start_time->tm_mday,
      file_start_time->tm_hour,
      file_start_time->tm_min,
      file_start_time->tm_sec);
    sprintf(time_units_str,"%s since %s",time_units,file_start_time_str);
    sprintf(timestep_units_str,"timesteps since %s",file_start_time_str);

    // Compute file time properties
    Compute_File_Time_Properties(timespan, file_start_time, data_end_time, first_rec_time, dt, time_units, NFILES, fidx, file_end_time, last_rec_time);

    // Open the netcdf-format output file
    if (!strcasecmp(timespan,"total")) {
      sprintf(outfile, "%s.nc", outprefix);
    }
    else if (!strcasecmp(timespan,"y")) {
      sprintf(outfile, "%s.%04d.nc", outprefix, file_start_time->tm_year+1900);
    }
    else if (!strcasecmp(timespan,"m")) {
      sprintf(outfile, "%s.%04d%02d.nc", outprefix, file_start_time->tm_year+1900, file_start_time->tm_mon+1);
    }
    fprintf(stdout, "Writing to file %s\n", outfile);
    Open_NetCDF(outfile, lev_units, lev_long_name, lev_positive, time_units_str,
      file_start_time_str, timestep_units_str, dt, var_atts, global_atts, grid, levels, &ncid, &timevarid, &timestepvarid);

    // For each time step, read an image of each variable
    // over all grid cells and write it to the output file
    curr_rec_time->tm_year = file_start_time->tm_year;
    curr_rec_time->tm_mon = file_start_time->tm_mon;
    curr_rec_time->tm_mday = file_start_time->tm_mday;
    curr_rec_time->tm_hour = 0;
    curr_rec_time->tm_min = 0;
    curr_rec_time->tm_sec = 0;
    for(t=0; t<NRECS; t++) {

      // Compute time, timestep values relative to beginning of file
      time = (float)(t*dt);
      timestep = t;

      // Initialize vars to NODATA_FLOAT.
      for(v=0; v<NUM3d; v++) {
        for(k=0; k<NCELLS; k++) {
          var3d[v][k] = NODATA_FLOAT;
        }
      }
      for(v=0; v<NUM4d; v++) {
        for(k=0; k<NCELLS; k++) {
          for(l=0; l<NLEVELS; l++) {
            var4d[v][k][l] = NODATA_FLOAT;
          }
        }
      }

      // Read the next timestep from the VIC-format files
      Read_VIC(grid, infilehandle, var_atts, var3d, var4d);

      // Write this timestep to the netcdf-format file
      // But if we are on Feb 29 of a leap year and NO_LEAP_OUT is TRUE, skip writing
      if (!(NO_LEAP_OUT && LEAPYR(curr_rec_time->tm_year) && curr_rec_time->tm_mon == 1 && curr_rec_time->tm_mday == 29)) {
        Write_NetCDF(ncid, grid, timevarid, timestepvarid, var_atts, t, time, timestep, var3d, var4d);
      }

      // Compute date of next record
      dsec = dt2sec(*curr_rec_time, dt, time_units);
      add_sec_date(*curr_rec_time, dsec, curr_rec_time);

    }

    // Close the output file
    status = nc_close(ncid);

    // Advance the date/time counters
    cumulative_recs += NRECS;
    cumulative_secs += NSECS;
    first_rec_time->tm_year = curr_rec_time->tm_year;
    first_rec_time->tm_mon = curr_rec_time->tm_mon;
    first_rec_time->tm_mday = curr_rec_time->tm_mday;
    first_rec_time->tm_hour = curr_rec_time->tm_hour;
    first_rec_time->tm_min = curr_rec_time->tm_min;
    first_rec_time->tm_sec = curr_rec_time->tm_sec;

  }

  // Free allocated space
  for (g=0; g<NGLOBALS; g++) {
    free(global_atts[g]);
  }
  free(data_start_time);
  free(data_end_time);
  free(file_start_time);
  free(file_end_time);
  free(first_rec_time);
  free(last_rec_time);
  free(curr_rec_time);
  free(grid);
  for(v=0; v<NUM3d; v++) {
    free(var3d[v]);
  }
  free(var3d);
  if (NUM4d > 0) {
    for(v=0; v<NUM4d; v++) {
      for(k=0; k<NCELLS; k++) {
        free(var4d[v][k]);
      }
      free(var4d[v]);
    }
    free(var4d);
  }

} // END PROGRAM


//*************************************************************************************************
// Read_Args:  This routine checks the command line for valid program options.  If
// no options are found, or an invalid combination of them appear, the
// routine calls usage() to print the model usage to the screen, before exiting.
//*************************************************************************************************
void Read_Args(int argc, char *argv[], char *inpath, char *prefix, char *metafile, char *outfile, char *gridfile, char *timespan)
{
  extern int getopt();
  extern char *optarg;
  extern char *optstring;

  int optchar;

  if(argc==1) {
    Usage(argv[0]);
    exit(1);
  }
  
  while((optchar = getopt(argc, argv, optstring)) != EOF) {
    switch((char)optchar) {
    case 'i':
      /** Input Path **/
      strcpy(inpath, optarg);
      break;
    case 'p':
      /** Input Filename prefix **/
      strcpy(prefix, optarg);
      break;
    case 'm':
      /** File containing metadata **/
      strcpy(metafile, optarg);
      break;
    case 'o':
      /** Output File **/
      strcpy(outfile, optarg);
      break;
    case 'g':
      /** Grid File (for grids that aren't aligned with lat-lon) **/
      GRIDFILE = 1;
      strcpy(gridfile, optarg);
      break;
    case 't':
      /** Time span **/
      TIMESPAN = 1;
      strcpy(timespan, optarg);
      break;
    case 'c':
      /** Compression by gathering **/
      COMPRESS = 1;
      break;
    case 'l':
      /** Input files contain Feb 29 but output files don't **/
      NO_LEAP_OUT = 1;
      break;
    default:
      /** Print Usage if Invalid Command Line Arguments **/
      Usage(argv[0]);
      exit(1);
      break;
    }
  }

  // Validate timespan
  if (TIMESPAN) {
    if (!strcasecmp(timespan,"m")) {
      sprintf(timespan,"m");
    }
    else if (!strcasecmp(timespan,"y")) {
      sprintf(timespan,"y");
    }
    else {
      fprintf(stderr, "ERROR: the specified value of timespan, %s, is not valid\n", timespan);
      Usage(argv[0]);
      exit(1);
    }
  }
  else {
    sprintf(timespan,"total");
  }

}

//*************************************************************************************************
// Usage: Function to print out usage details.
//*************************************************************************************************
void Usage(char *temp)
{
  fprintf(stderr,"%s - converts traditional VIC forcing or results files into netcdf format.\n",temp);
  fprintf(stderr,"\n");
  fprintf(stderr,"Usage: %s  -i<inpath> -p<prefix> -m<metadata> -o<outfile> [-g<gridfile>] [-t<timespan>] [-c] [-l] [-L]\n",temp);
  fprintf(stderr,"\n");
  fprintf(stderr,"This program takes as input a set of VIC-format data files, 1 per grid cell,\n");
  fprintf(stderr,"and writes their contents into 1 netcdf file.  The VIC-format data files must\n");
  fprintf(stderr,"be ascii text files, consisting of one or more lines of space-separated fields.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"In addition to specifying the location of the input files, you must supply a\n");
  fprintf(stderr,"metadata file (the \'metafile\') containing the names and order of the variables\n");
  fprintf(stderr,"in the input files and the overall data dimensions.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"By default, this program assumes that the grid\'s rows and columns are aligned\n");
  fprintf(stderr,"with lines of latitude and longitude.  It uses the latitude and longitude values\n");
  fprintf(stderr,"in the VIC data file names to determine the row and column indices of the position\n");
  fprintf(stderr,"in the netcdf array where the data will be stored.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"However, if you are working with an equal-area grid, in which latitude and longitude\n");
  fprintf(stderr,"may not be constant along a row or column, you can tell the program to get the row and\n");
  fprintf(stderr,"column of each grid cell from a separate file, called the \'gridfile\'.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"  -i <inpath>\n");
  fprintf(stderr,"    <inpath>   Path to location of VIC data files.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"  -p <prefix>\n");
  fprintf(stderr,"    <prefix>   Filename prefix of VIC files.  VIC data files must have names of\n");
  fprintf(stderr,"               form prefix_lat_lon, where \'lat\' and \'lon\' are the latitude and\n");
  fprintf(stderr,"               longitude of the grid cell and \'prefix\' is some character string.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"  -m <metadata>\n");
  fprintf(stderr,"    <metadata> Text file containing metadata for VIC files, including start/end\n");
  fprintf(stderr,"               times, time step, vertical levels, variables and their attributes.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"  -o <outfile>\n");
  fprintf(stderr,"    <outfile>  Output netcdf file name.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"  -g <gridfile>\n");
  fprintf(stderr,"    (Optional) If -g is specified, the row and column values in the given gridfile\n");
  fprintf(stderr,"    will be used to index the grid cells in the netcdf file, instead of calculating the\n");
  fprintf(stderr,"    row and column from the lat and lon of the grid cells.  This option is useful when\n");
  fprintf(stderr,"    working with an equal-area grid, in which the rows and columns are not necessarily\n");
  fprintf(stderr,"    aligned with lines of latitude and longitude.\n");
  fprintf(stderr,"    <gridfile> Text file with id#, row, col, lat, lon of grid cells.  Format:\n");
  fprintf(stderr,"                 CellID Row Col Lat Lon\n");
  fprintf(stderr,"               where CellID = ID number of the cell, Row and Col are the cell\'s row\n");
  fprintf(stderr,"               and column indexes, and Lat and Lon are the cell\'s latitude and\n");
  fprintf(stderr,"               longitude.\n");
  fprintf(stderr,"    Note: when -g is specified, \'row\', \'col\', and \'cellid\' will be stored in the\n");
  fprintf(stderr,"    netcdf file\n");
  fprintf(stderr,"    Default: if -g is NOT specified, row and col indexes will be determined from the\n");
  fprintf(stderr,"    grid cell lat and lon values.  In addition, \'row\', \'col\', and \'cellid\' will\n");
  fprintf(stderr,"    not be stored in the netcdf file.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"  -t <timespan>\n");
  fprintf(stderr,"    (Optional) If -t is specified, multiple output files will be created, each spanning\n");
  fprintf(stderr,"    the length of time indicated by <timespan>.\n");
  fprintf(stderr,"    <timespan> One of (\'m\',\'y\'), as follows:\n");
  fprintf(stderr,"                 m: monthly\n");
  fprintf(stderr,"                 y: yearly\n");
  fprintf(stderr,"    The output filenames will be of the format <outfile>.<date>.nc, where <outfile> is\n");
  fprintf(stderr,"    the string specified with the -o option above, and <date> is the date of the first\n");
  fprintf(stderr,"    record in the file.  If <timespan> \'m\', <date> will be YYYYMM, where YYYY = year\n");
  fprintf(stderr,"    and MM = month.  If <timespan> is \'y\' <date> will be YYYY.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"  -c\n");
  fprintf(stderr,"    (Optional) If specified, use compression by gathering to save space.  This will\n");
  fprintf(stderr,"    cause the netcdf file\'s \'x\' and \'y\' dimensions to be replaced by a single\n");
  fprintf(stderr,"    \'land\' dimension.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"  -l\n");
  fprintf(stderr,"    (Optional) If specified, this option assumes that the input files DO contain February\n");
  fprintf(stderr,"    29 during leap years, but does NOT write Feb 29 to the output files.\n");
  fprintf(stderr,"\n");
}

//*************************************************************************************************
// Read_Metadata: reads the metadata file and determines input data
// start/end times, time step, number of levels, variables and attributes
//*************************************************************************************************
void Read_Metadata(char *metafile, char **global_atts, struct tm *data_start_time, struct tm *data_end_time, float *dtp,
  char *time_units, char *time_units_str, char *timestep_units_str, char *lev_units, float *levels, char *lev_long_name,
  char *lev_positive, struct VarAtt *var_atts)
{

  FILE *mf;
  char cmdstr[MAXSTRING];
  char optstr[MAXSTRING];
  char data_start_date_str[20];
  char data_start_time_str[20];
  char data_end_date_str[20];
  char data_end_time_str[20];
  char file_start_time_str[20];
  int i, l, varcount, count3, count4;
  char current_date[50];
//  time_t *tp;
  char multstr[10];
  char endian_str[10];
  long long dsec;

  // Open and read file
  if ((mf = fopen(metafile, "r")) == NULL) {
    fprintf(stderr, "Error opening %s.\n",metafile);
    exit(1);
  }  

  varcount = 0;
  count3 = 0;
  count4 = 0;
  fgets(cmdstr,MAXSTRING,mf);
  while (!feof(mf)) {
    if (cmdstr[0]!='#' && cmdstr[0]!='\n' && cmdstr[0]!='\0') {

      sscanf(cmdstr,"%s",optstr);

      if (strcasecmp("INSTITUTION",optstr)==0) {
        sscanf(cmdstr,"%*s %[^\n]",global_atts[0]);
      }
      else if (strcasecmp("SOURCES",optstr)==0) {
        sscanf(cmdstr,"%*s %[^\n]",global_atts[1]);
      }
      else if (strcasecmp("PRODUCTION",optstr)==0) {
        sscanf(cmdstr,"%*s %[^\n]",global_atts[2]);
      }
      else if (strcasecmp("HISTORY",optstr)==0) {
        sscanf(cmdstr,"%*s %[^\n]",global_atts[3]);
      }
      else if (strcasecmp("PROJECTION",optstr)==0) {
        sscanf(cmdstr,"%*s %[^\n]",global_atts[4]);
      }
      else if (strcasecmp("SURFSGNCONVENTION",optstr)==0) {
        sscanf(cmdstr,"%*s %[^\n]",global_atts[5]);
      }
      else if (strcasecmp("START_TIME",optstr)==0) {
        sscanf(cmdstr,"%*s %s %s",data_start_date_str,data_start_time_str);
      }
      else if (strcasecmp("END_TIME",optstr)==0) {
        sscanf(cmdstr,"%*s %s %s",data_end_date_str,data_end_time_str);
      }
      else if (strcasecmp("TIME_STEP",optstr)==0) {
        sscanf(cmdstr,"%*s %f",dtp);
      }
      else if (strcasecmp("TIME_UNITS",optstr)==0) {
        sscanf(cmdstr,"%*s %s",time_units);
      }
      else if (strcasecmp("NLEVELS",optstr)==0) {
        sscanf(cmdstr,"%*s %d", &NLEVELS);
      }
      else if (strcasecmp("LEVEL_VALUES",optstr)==0) {
        // Note: there's got to be a better way to do this...
        if (NLEVELS == 1) {
          sscanf(cmdstr,"%*s %f", &levels[0]);
        }
        if (NLEVELS == 2) {
          sscanf(cmdstr,"%*s %f %f", &levels[0], &levels[1]);
        }
        if (NLEVELS == 3) {
          sscanf(cmdstr,"%*s %f %f %f", &levels[0], &levels[1], &levels[2]);
        }
      }
      else if (strcasecmp("LEVEL_UNITS",optstr)==0) {
        sscanf(cmdstr,"%*s %s", lev_units);
      }
      else if (strcasecmp("LEVEL_DESCR",optstr)==0) {
        sscanf(cmdstr,"%*s %[^\n]", lev_long_name);
      }
      else if (strcasecmp("LEVEL_POSITIVE",optstr)==0) {
        sscanf(cmdstr,"%*s %s", lev_positive);
      }
      else if (strcasecmp("FORMAT",optstr)==0) {
        sscanf(cmdstr,"%*s %s", FORMAT);
      }
      else if (strcasecmp("ENDIAN",optstr)==0) {
        sscanf(cmdstr,"%*s %s", endian_str);
        if (!strcasecmp(endian_str,"LITTLE"))
          ENDIAN = 1;
        else
          ENDIAN = 0;
      }
      else if (!strcasecmp("TRUE",optstr) || !strcasecmp("FALSE",optstr)) {
        sscanf(cmdstr,"%s %s %s %s %s %s %[^\n]", var_atts[varcount].read, var_atts[varcount].name, var_atts[varcount].units,
          var_atts[varcount].z_dep, var_atts[varcount].sign, multstr, var_atts[varcount].long_name);
        if (!strcasecmp("TRUE",optstr)) {
          var_atts[varcount].mult = atof(multstr);
        }
        else {
          var_atts[varcount].mult = 0;
        }
        (!strcasecmp(var_atts[varcount].z_dep,"FALSE")) ? count3++ : count4++;
        varcount++;
      }
      else {
        fprintf(stderr,"Error: parameter not recognized: %s\n", optstr);
      }
    }
    fgets(cmdstr,MAXSTRING,mf);
  }

  fclose(mf);

  // Compute total number of 3d, 4d vars
  NUM3d = count3;
  NUM4d = count4;

  // Store start/end date/time in tm structures
  Date_2_TM(data_start_date_str, data_start_time);
  Time_2_TM(data_start_time_str, data_start_time);
  data_start_time->tm_isdst = 0;
  Date_2_TM(data_end_date_str, data_end_time);
  Time_2_TM(data_end_time_str, data_end_time);
  data_end_time->tm_isdst = 0;

  // Adjust data end time to be the final second before the next record (which is not in the data set)
  dsec = dt2sec(*data_end_time, *dtp, time_units);
  add_sec_date(*data_end_time, dsec, data_end_time);
  add_sec_date(*data_end_time, -1, data_end_time);

  // Check the units; if valid, map to standard names; else give error message
  if (!strcasecmp(time_units,"y") || !strcasecmp(time_units,"yr") || !strncasecmp(time_units,"year",4)) {
    sprintf(time_units,"year");
  }
  else if (!strcasecmp(time_units,"m") || !strcasecmp(time_units,"mo") || !strncasecmp(time_units,"mon",3)) {
    sprintf(time_units,"month");
  }
  else if (!strcasecmp(time_units,"d") || !strcasecmp(time_units,"dy") || !strncasecmp(time_units,"day",3)) {
    sprintf(time_units,"day");
  }
  else if (!strcasecmp(time_units,"h") || !strcasecmp(time_units,"hr") || !strncasecmp(time_units,"hour",4)) {
    sprintf(time_units,"hour");
  }
  else if (!strncasecmp(time_units,"min",3)) {
    sprintf(time_units,"min");
  }
  else if (!strcasecmp(time_units,"s") || !strncasecmp(time_units,"sec",3)) {
    sprintf(time_units,"sec");
  }
  else {
    fprintf(stderr, "Error: given time units (%s) are invalid\n", time_units);
    exit(1);
  }

  // Generate time metadata
  sprintf(file_start_time_str,"%04d-%02d-%02d %02d:%02d:%02d",
    data_start_time->tm_year+1900,
    data_start_time->tm_mon+1,
    data_start_time->tm_mday,
    data_start_time->tm_hour,
    data_start_time->tm_min,
    data_start_time->tm_sec);
  sprintf(time_units_str,"%s since %s",time_units,file_start_time_str);
  sprintf(timestep_units_str,"timesteps since %s",file_start_time_str);

//  // Add this operation to history
//  time(tp);
//  current_date = ctime(time(tp));
//  strcat(global_atts[3],"; Converted to NetCDF ");
//  strcat(global_atts[3],current_date);

}


//*************************************************************************************************
// Read_Gridfile: reads the grid file and stores the id#, row, col,
// lat, and lon of each grid cell
//*************************************************************************************************
struct GridInfo *Read_Gridfile(char *gridfile)
{

  FILE *fg;
  char linestr[MAXSTRING];
  int g,i,j,k;
  int cellid, row, col;
  int row_adj, col_adj;
  float lat, lon, minlat, maxlat, minlon, maxlon;
  int first_time;
  struct GridInfo *grid;

  // Open gridfile
  if((fg = fopen(gridfile, "r")) == NULL) {
    fprintf(stderr, "Error opening %s.\n", gridfile);
    exit(1);
  }

  // Get dimensions of grid
  k = 0;
  first_time = 1;
  fgets(linestr,MAXSTRING,fg);
  while(!feof(fg)) {
    // Skip comments (begin with #) and blank lines
    if(linestr[0]!='#' && linestr[0]!='\n' && linestr[0]!='\0') {
      sscanf(linestr, "%d %d %d %f %f", &cellid, &row, &col, &lat, &lon);
      if (first_time) {
        MINROW = row;
        MAXROW = row;
        MINCOL = col;
        MAXCOL = col;
        first_time = 0;
      }
      else {
        if (row < MINROW) MINROW = row;
        if (row > MAXROW) MAXROW = row;
        if (col < MINCOL) MINCOL = col;
        if (col > MAXCOL) MAXCOL = col;
      }
      k++;
    }
    fgets(linestr,MAXSTRING,fg);
  }

  // Close gridfile
  fclose(fg);

  // Total number of valid grid cells
  NCELLS = k;

  // Number of grid rows and cols
  NROWS = MAXROW - MINROW + 1;
  NCOLS = MAXCOL - MINCOL + 1;

  // Allocate grid structure
  grid = (struct GridInfo *)calloc(NCELLS, sizeof(struct GridInfo));

  // Initialize grid
  for (k=0; k<NCELLS; k++) {
      grid[k].landmask = 0;
      grid[k].cellid = NODATA_INT;
      grid[k].row = NODATA_INT;
      grid[k].col = NODATA_INT;
      grid[k].lat = NODATA_FLOAT;
      grid[k].lon = NODATA_FLOAT;
  }

  // Open gridfile again
  if((fg = fopen(gridfile, "r")) == NULL) {
    fprintf(stderr, "Error opening %s.\n", gridfile);
    exit(1);
  }

  // Now store data in grid structure
  k = 0;
  fgets(linestr,MAXSTRING,fg);
  while(!feof(fg)) {
    // Skip comments (begin with #) and blank lines
    if(linestr[0]!='#' && linestr[0]!='\n' && linestr[0]!='\0') {
      sscanf(linestr, "%d %d %d %f %f", &cellid, &row, &col, &lat, &lon);
      row_adj = row - MINROW;
      col_adj = col - MINCOL;
      grid[k].landmask = row_adj*NCOLS+col_adj;
      grid[k].cellid = cellid;
      grid[k].row = row;
      grid[k].col = col;
      grid[k].lat = lat;
      grid[k].lon = lon;
      k++;
    }
    fgets(linestr,MAXSTRING,fg);
  }

  // Close gridfile
  fclose(fg);

  return grid;

}


//*************************************************************************************************
// Calc_Grid: calculates row and column indices from lat and lon values
//   This assumes that the cells are aligned with latitude and longitude lines,
//   and that the landmask contains at least one pair of cells whose latitudes
//   differ by delta_lat (change in latitude between rows) and at least one pair
//   whose longitudes differ by delta_lon (change in longitude between columns).
//*************************************************************************************************
struct GridInfo *Calc_Grid(char *inpath, char *prefix)
{

  DIR *dp;
  struct dirent *filep;
  int k, first_time;
  char tmpstr[MAXSTRING], *latstr, *lonstr;
  char **latlonstr;
  float lat, lon, minlat, maxlat, minlon, maxlon, delta_lat, delta_lon, temp;
  float *lats, *lons, *latlon;
  int row, col, row_adj, col_adj;
  struct GridInfo *grid;
  int i,n;
  char *tok;
  float tmpfloat;
  int tmpint;
  double tmpdouble;

  // Open inpath
  if((dp = opendir(inpath)) == NULL) {
    fprintf(stderr, "Error opening %s.\n", inpath);
    exit(1);
  }

  // Get dimensions of grid
  k = 0;
  first_time = 1;
  while((filep = readdir(dp)) != NULL) {
    if (!strncmp(filep->d_name,prefix,strlen(prefix))) {

      // Parse filename into lat and lon
      sscanf(filep->d_name, "%s", tmpstr);
      n = 0;
      tok = strtok(tmpstr, "_");
      while (tok != NULL && strlen(tmpstr) > 0) {
        n++;
        tok = strtok(NULL, "_");
      }
      sscanf(filep->d_name, "%s", tmpstr);
      tok = strtok(tmpstr, "_");
      for (i=1; i<n-1; i++) {
        tok = strtok(NULL, "_");
      }
      lat = atof(tok);
      tok = strtok(NULL, "_");
      lon = atof(tok);

      if (first_time) {
        first_time = 0;

        // Initialize min/max lat/lon 
        minlat = lat;
        maxlat = lat;
        minlon = lon;
        maxlon = lon;

      }
      else {

        // Update min/max lat/lon
        if (lat < minlat) minlat = lat;
        if (lat > maxlat) maxlat = lat;
        if (lon < minlon) minlon = lon;
        if (lon > maxlon) maxlon = lon;

      }

      k++;

    }
  }

  // Close inpath
  closedir(dp);

  // Total number of valid grid cells
  NCELLS = k;

  // Allocate arrays
  lats = (float *)calloc(NCELLS,sizeof(float));
  lons = (float *)calloc(NCELLS,sizeof(float));
  latlon = (float *)calloc(NCELLS,sizeof(float));
  latlonstr = (char **)calloc(NCELLS,sizeof(char *));
  for (k=0; k<NCELLS; k++) {
    latlonstr[k] = (char *)calloc(20,sizeof(char));
  }

  // Open inpath again
  if((dp = opendir(inpath)) == NULL) {
    fprintf(stderr, "Error opening %s.\n", inpath);
    exit(1);
  }

  // Get lats and lons
  k = 0;
  first_time = 1;
  while((filep = readdir(dp)) != NULL) {
    if (!strncmp(filep->d_name,prefix,strlen(prefix))) {

      // Parse filename into lat and lon
      sscanf(filep->d_name, "%s", tmpstr);
      n = 0;
      tok = strtok(tmpstr, "_");
      while (tok != NULL && strlen(tmpstr) > 0) {
        n++;
        tok = strtok(NULL, "_");
      }
      sscanf(filep->d_name, "%s", tmpstr);
      tok = strtok(tmpstr, "_");
      for (i=1; i<n-1; i++) {
        tok = strtok(NULL, "_");
      }
      lat = ( atof(tok) + 100 ) * 10000;
      tok = strtok(NULL, "_");
      lon = ( atof(tok) + 360 ) * 10000;
      sprintf(latlonstr[k],"%.0f.%.0f",lat,lon);

      k++;

    }
  }

  // Close inpath
  closedir(dp);

  // Sort latlon
  qsort(latlonstr, NCELLS, sizeof(char*), alphabetic);

  // Parse latlonstr into lat and lon
  for (k=0; k<NCELLS; k++) {
      strcpy(tmpstr,latlonstr[k]);
      n = 0;
      tok = strtok(tmpstr, ".");
      while (tok != NULL && strlen(tmpstr) > 0) {
        n++;
        tok = strtok(NULL, ".");
      }
      strcpy(tmpstr,latlonstr[k]);
      tok = strtok(tmpstr, ".");
      for (i=1; i<n-1; i++) {
        tok = strtok(NULL, ".");
      }
      lats[k] = ( atof(tok) / 10000 ) - 100;
      tok = strtok(NULL, ".");
      lons[k] = ( atof(tok) / 10000 ) - 360;
  }

  if (NCELLS > 1) {

    // Calculate delta_lat
    delta_lat = maxlat - minlat;
    first_time = 1;
    for (k=0; k<NCELLS; k++) {
      if (first_time) {
        temp = lats[k];
        first_time = 0;
      }
      else {
        if (fabs(lats[k] - temp) >= 0.0001 && delta_lat > fabs(lats[k] - temp)) {
          delta_lat = fabs(lats[k] - temp);
        }
        temp = lats[k];
      }
    }

    // Calculate delta_lon
    delta_lon = maxlon - minlon;
    first_time = 1;
    for (k=0; k<NCELLS; k++) {
      if (first_time) {
        temp = lons[k];
        first_time = 0;
      }
      else {
        if (fabs(lons[k] - temp) >= 0.0001 && delta_lon > fabs(lons[k] - temp)) {
          delta_lon = fabs(lons[k] - temp);
        }
        temp = lons[k];
      }
    }

    // Calculate NROWS, NCOLS
    MINROW = 1;
    MAXROW = (maxlat - minlat)/delta_lat + 1;
    NROWS = MAXROW;
    MINCOL = 1;
    MAXCOL = (maxlon - minlon)/delta_lon + 1;
    NCOLS = MAXCOL;

  }
  else if (NCELLS == 1) {

    // Calculate NROWS, NCOLS
    MINROW = 1;
    MAXROW = 1;
    NROWS = 1;
    MINCOL = 1;
    MAXCOL = 1;
    NCOLS = 1;
    delta_lat = 1;
    delta_lon = 1;

  }
  else {

    // Calculate NROWS, NCOLS
    MINROW = 0;
    MAXROW = 0;
    NROWS = 0;
    MINCOL = 0;
    MAXCOL = 0;
    NCOLS = 0;
    delta_lat = 1;
    delta_lon = 1;

  }

  // Allocate grid structure
  grid = (struct GridInfo *)calloc(NCELLS, sizeof(struct GridInfo));

  // Initialize grid
  for (k=0; k<NCELLS; k++) {
    grid[k].landmask = 0;
    grid[k].cellid = NODATA_INT;
    grid[k].row = NODATA_INT;
    grid[k].col = NODATA_INT;
    grid[k].lat = NODATA_FLOAT;
    grid[k].lon = NODATA_FLOAT;
  }

  for (k=0; k<NCELLS; k++) {
    row = (lats[k] - minlat)/delta_lat + 1;
    col = (lons[k] - minlon)/delta_lon + 1;
    row_adj = row - MINROW;
    col_adj = col - MINCOL;
    grid[k].landmask = row_adj*NCOLS+col_adj;
    grid[k].cellid = k+1;
    grid[k].row = row;
    grid[k].col = col;
    grid[k].lat = lats[k];
    grid[k].lon = lons[k];
  }

  free(lats);
  free(lons);
  free(latlon);
  for (k=0; k<NCELLS; k++) {
    free(latlonstr[k]);
  }
  free(latlonstr);

  return grid;

}


//*************************************************************************************************
// numeric: comparison function for use by qsort()
//*************************************************************************************************
int numeric(const void *a, const void *b)
{

  if (*(float *)a < *(float *)b) return -1;
  if (*(float *)a > *(float *)b) return 1;
  return 0;

}


//*************************************************************************************************
// alphabetic: comparison function for use by qsort()
//*************************************************************************************************
int alphabetic(const void *a, const void *b)
{

  if (strcmp(*(char**)a,*(char**)b) < 0) return -1;
  if (strcmp(*(char**)a,*(char**)b) > 0) return 1;
  return 0;

}


//*************************************************************************************************
// Check_VIC_Files: attempts to open VIC-format files for reading and
// returns array of filehandles for these files.
//*************************************************************************************************
void Check_VIC_Files(char *inpath, char *prefix, struct GridInfo *grid, FILE **infilehandle)
{

  int i,j,k;
  char filename[150];

  //  Loop over all points.
  for (k=0; k<NCELLS; k++) {

    // Generate the first VIC file name for the current point
    sprintf(filename, "%s/%s_%.4f_%.4f",inpath, prefix, grid[k].lat, grid[k].lon);

    // Try to open VIC file associated with this point
    if (!strcasecmp(FORMAT,"BINARY")) {
      if((infilehandle[k] = fopen(filename, "rb")) == NULL) {

        // If we can't open this file, complain
        fprintf(stderr,"Error: cannot open %s\n",filename);
        exit(-1);

      }
    }
    else {
      if((infilehandle[k] = fopen(filename, "r")) == NULL) {

        // If we can't open this file, complain
        fprintf(stderr,"Error: cannot open %s\n",filename);
        exit(-1);

      }
    }

  }

}


//*************************************************************************************************
// Compute_NFILES: computes number of output files
//*************************************************************************************************
void Compute_NFILES(struct tm *data_start_time, struct tm *data_end_time, char *timespan)
{

  long long tmp;
  struct tm curr_time;

  if (!strcmp(timespan,"total")) {
    NFILES = 1;
    return;
  }

  curr_time.tm_year = data_start_time->tm_year;
  curr_time.tm_mon = data_start_time->tm_mon;
  curr_time.tm_mday = data_start_time->tm_mday;
  curr_time.tm_hour = data_start_time->tm_hour;
  curr_time.tm_min = data_start_time->tm_min;
  curr_time.tm_sec = data_start_time->tm_sec;
  NFILES = 0;

  while ((tmp = diff_date(curr_time, *data_end_time)) < 0) {
    if (!strcmp(timespan,"y")) {
      curr_time.tm_year++;
    }
    else if (!strcmp(timespan,"m")) {
      curr_time.tm_mon++;
      if (curr_time.tm_mon >= 12) {
        curr_time.tm_year++;
        curr_time.tm_mon == 0;
      }
    }
    NFILES++;
  }

}


//*************************************************************************************************
// Compute_File_Time_Properties: computes number of records, etc, for current output file
//*************************************************************************************************
void Compute_File_Time_Properties(char *timespan, struct tm *file_start_time, struct tm *data_end_time,
struct tm *first_rec_time, int dt, char *time_units, int NFILES, int fidx, struct tm *file_end_time, struct tm *last_rec_time)
{

  int i;
  long ndays;
  long long dsec;
  long long tmp;
  struct tm curr_time;

  // Compute file end time
  if (!strcmp(timespan,"total") || fidx == NFILES-1) {
    file_end_time->tm_year = data_end_time->tm_year;
    file_end_time->tm_mon = data_end_time->tm_mon;
    file_end_time->tm_mday = data_end_time->tm_mday;
    file_end_time->tm_hour = data_end_time->tm_hour;
    file_end_time->tm_min = data_end_time->tm_min;
    file_end_time->tm_sec = data_end_time->tm_sec;
  }
  else {
    if (!strcmp(timespan,"y")) {
      ndays = 364;
      if ( (LEAPYR(file_start_time->tm_year) && (file_start_time->tm_mon == 0 || (file_start_time->tm_mon == 1 && file_start_time->tm_mday <= 28))) || (LEAPYR(file_start_time->tm_year+1) && file_start_time->tm_mon == 2) ) {
        ndays++;
      }
    }
    else if (!strcmp(timespan,"m")) {
      ndays = dmonth[file_start_time->tm_mon]-1;
      if (LEAPYR(file_start_time->tm_year) && file_start_time->tm_mon == 1) {
        ndays++;
      }
    }
    dsec = ndays*86400LL + 86399LL;
    add_sec_date(*file_start_time, dsec, file_end_time);
  }

  // Compute number of records, and times of records, in the file
  NRECS = 0;
  NSECS = 0;
  curr_time.tm_year = first_rec_time->tm_year;
  curr_time.tm_mon = first_rec_time->tm_mon;
  curr_time.tm_mday = first_rec_time->tm_mday;
  curr_time.tm_hour = first_rec_time->tm_hour;
  curr_time.tm_min = first_rec_time->tm_min;
  curr_time.tm_sec = first_rec_time->tm_sec;
  while ((tmp = diff_date(curr_time, *file_end_time)) < 0) {
    NRECS++;
    // Compute time of next rec
    dsec = dt2sec(curr_time, dt, time_units);
    add_sec_date(curr_time, dsec, &curr_time);
    NSECS += dsec;
  }
  add_sec_date(curr_time, -dsec, last_rec_time);

}


//*************************************************************************************************
// dt2sec: computes number of seconds in record dt interval
//*************************************************************************************************
long long dt2sec(struct tm rec_time, int dt, char *time_units)
{

  long ndays;
  int i;
  long long dsec;

  if (!strcmp(time_units,"year")) {
    ndays = 0;
    for (i=0; i<dt; i++) {
      rec_time.tm_year++;
      ndays += 365;
      if ( (LEAPYR(rec_time.tm_year-1) && (rec_time.tm_mon == 0 || (rec_time.tm_mon == 1 && rec_time.tm_mday <= 28)))
          || (LEAPYR(rec_time.tm_year) && rec_time.tm_mon > 1) ) {
        ndays++;
      }
    }
    dsec = ndays*86400LL;
  }
  else if (!strcmp(time_units,"month")) {
    ndays = 0;
    for (i=0; i<dt; i++) {
      rec_time.tm_mon++;
      ndays += dmonth[rec_time.tm_mon-1];
      if ( LEAPYR(rec_time.tm_year) && (rec_time.tm_mon-1 == 1 && rec_time.tm_mday <= 28) ) {
        ndays++;
      }
      if (rec_time.tm_mon >= 12) {
        rec_time.tm_year++;
        rec_time.tm_mon = 0;
      }
    }
    dsec = ndays*86400LL;
  }
  else if (!strcmp(time_units,"day")) {
    dsec = dt*86400LL;
  }
  else if (!strcmp(time_units,"hour")) {
    dsec = dt*3600LL;
  }
  else if (!strcmp(time_units,"min")) {
    dsec = dt*60LL;
  }
  else if (!strcmp(time_units,"sec")) {
    dsec = dt;
  }

  return dsec;

}


//*************************************************************************************************
// Read_VIC: reads VIC-format files
//*************************************************************************************************
void Read_VIC(struct GridInfo *grid, FILE **infilehandle, struct VarAtt *var_atts,
  float **var3d, float ***var4d)
{

  int i, j, k, t, v, l, f;
  int count3, count4;
  float tempfloat;
  char *tempstr;
  int my_endian;
  signed short stmp;
  unsigned short ustmp;

  if (!strcasecmp(FORMAT,"BINARY")) {
    i = 1;
    if(*(char *)&i == 1)
      my_endian = 1; // LITTLE
    else
      my_endian = 0; // BIG
  }

  // Loop over grid cells
  for (k=0; k<NCELLS; k++) {

    if (!strcasecmp(FORMAT,"BINARY")) {

      // BINARY

      // Read current record
      count3 = count4 = 0;
      for (v=0; v<(NUM3d+NUM4d); v++) {
        if (!strcasecmp(var_atts[v].z_dep,"FALSE")) {
          if (!strcasecmp(var_atts[v].sign,"SIGNED")) {
            if( !feof(infilehandle[k])
              && fread(&stmp,sizeof(short int),1,infilehandle[k])
              && !ferror(infilehandle[k]) )
            {
              if (my_endian != ENDIAN) {
                stmp = ((stmp & 0xFF) << 8) | ((stmp >> 8) & 0xFF);
              }
              var3d[count3][k] = (float)stmp / var_atts[v].mult;
            }
            else {
              var3d[count3][k] = NODATA_FLOAT;
            }
          }
          else {
            if ( !feof(infilehandle[k])
              && fread(&ustmp,sizeof(unsigned short int),1,infilehandle[k])
              && !ferror(infilehandle[k]) )
            {
              if (my_endian != ENDIAN) {
                ustmp = ((ustmp & 0xFF) << 8) | ((ustmp >> 8) & 0xFF);
              }
              var3d[count3][k] = (float)ustmp / var_atts[v].mult;
            }
            else {
              var3d[count3][k] = NODATA_FLOAT;
            }
          }
          if (!strcasecmp(var_atts[v].read,"TRUE")) {
            count3++;
          }
        }
        else {
          for (l=0; l<NLEVELS; l++) {
            if (!strcasecmp(var_atts[v].sign,"SIGNED")) {
              if( !feof(infilehandle[k])
                && fread(&stmp,sizeof(short int),1,infilehandle[k])
                && !ferror(infilehandle[k]) )
              {
                if (my_endian != ENDIAN) {
                  stmp = ((stmp & 0xFF) << 8) | ((stmp >> 8) & 0xFF);
                }
                var4d[count4][k][l] = (float)stmp / var_atts[v].mult;
              }
              else {
                var4d[count4][k][l] = NODATA_FLOAT;
              }
            }
            else {
              if ( !feof(infilehandle[k])
                && fread(&ustmp,sizeof(unsigned short int),1,infilehandle[k])
                && !ferror(infilehandle[k]) )
              {
                if (my_endian != ENDIAN) {
                  ustmp = ((ustmp & 0xFF) << 8) | ((ustmp >> 8) & 0xFF);
                }
                var4d[count4][k][l] = (float)ustmp / var_atts[v].mult;
              }
              else {
                var4d[count4][k][l] = NODATA_FLOAT;
              }
            }
          }
          if (!strcasecmp(var_atts[v].read,"TRUE")) {
            count4++;
          }
        }
      }

    }
    else {

    // ASCII or SCIENTIFIC

    // Read record
      count3 = count4 = 0;
      for (v=0; v<(NUM3d+NUM4d); v++) {
        if (!strcasecmp(var_atts[v].z_dep,"FALSE")) {
          if (!strcasecmp(FORMAT,"SCIENTIFIC")) {
            if (fscanf(infilehandle[k], "%e", &(var3d[count3][k])) == EOF) {
              var3d[count3][k] = NODATA_FLOAT;
            }
          }
          else {
            if (fscanf(infilehandle[k], "%f", &(var3d[count3][k])) == EOF) {
              var3d[count3][k] = NODATA_FLOAT;
            }
          }
          if (!strcasecmp(var_atts[v].read,"TRUE")) {
            count3++;
          }
        }
        else {
          for (l=0; l<NLEVELS; l++) {
            if (!strcasecmp(FORMAT,"SCIENTIFIC")) {
              if (fscanf(infilehandle[k], "%e", &(var4d[count4][k][l])) == EOF) {
                var4d[count4][k][l] = NODATA_FLOAT;
              }
            }
            else {
              if (fscanf(infilehandle[k], "%f", &(var4d[count4][k][l])) == EOF) {
                var4d[count4][k][l] = NODATA_FLOAT;
              }
            }
          }
          if (!strcasecmp(var_atts[v].read,"TRUE")) {
            count4++;
          }
        }
      }

    }

  }

}


//*************************************************************************************************
// Open_NetCDF: opens netcdf files
//*************************************************************************************************
void Open_NetCDF(char *outfile, char *lev_units, char *lev_long_name, char *lev_positive,
  char *time_units_str, char *file_start_time_str, char *timestep_units_str, float dt,
  struct VarAtt *var_atts, char **global_atts, struct GridInfo *grid,
  float *levels, int *ncidp, int *timevaridp, int *timestepvaridp)
{

  int status;
  int i,j,k,t,l,v,g;
  int ncid;
  int ydimid, xdimid, zdimid, landdimid, tstepdimid;
  int rowvarid, colvarid, latvarid, lonvarid, levvarid, landvarid, cellidvarid;
  int ndim, dims[MAXDIM];
  int *temp_array_int_cmp;
  int *temp_array_int;
  float *temp_array_cmp;
  float *temp_array;
  int tempint;
  float tempfloat; 

  // Allocate temp arrays
  if (COMPRESS) {
    temp_array_int_cmp = (int*)calloc(NCELLS, sizeof(int));
    temp_array_cmp = (float*)calloc(NCELLS, sizeof(float));
  }
  temp_array_int = (int*)calloc(NROWS*NCOLS, sizeof(int));
  temp_array = (float*)calloc(NROWS*NCOLS, sizeof(float));

//  fprintf(stderr,"Defining netcdf file\n");
  status = nc_create(outfile, NC_CLOBBER, ncidp);  Handle_Error(status);
  ncid = *ncidp;

  // Define Dimensions
  if (COMPRESS) {
    status = nc_def_dim(ncid, "land", NCELLS, &landdimid);  Handle_Error(status);
  }
  else {
    status = nc_def_dim(ncid, "x", NCOLS, &xdimid) ;  Handle_Error(status);
    status = nc_def_dim(ncid, "y", NROWS, &ydimid);  Handle_Error(status);
  }
  status = nc_def_dim(ncid, "z", NLEVELS, &zdimid);  Handle_Error(status);
  status = nc_def_dim(ncid, "tstep", NC_UNLIMITED, &tstepdimid);  Handle_Error(status);

//  fprintf(stderr,"Done defining dimensions\n");

  // Define Coordinate VARIABLES

  // Row, Col, Longitude and Latitude
  if (COMPRESS) {
    ndim = 1;
    dims[0] = landdimid;
  }
  else {
    ndim=2;
    dims[0] = ydimid;
    dims[1] = xdimid;
  }

  // Row and Col only written when user has specified a grid file
  if (GRIDFILE) {
    // Row
    status = nc_def_var(ncid, "row", NC_INT, ndim, dims, &rowvarid);  Handle_Error(status);
    status = nc_put_att_text(ncid, rowvarid, "axis", strlen("YX"),"YX");  Handle_Error(status);
    status = nc_put_att_text(ncid, rowvarid, "units", strlen("-"), "-");  Handle_Error(status);
    tempint = MINROW;
    status = nc_put_att_int(ncid, rowvarid, "valid_min", NC_INT, 1, &tempint);  Handle_Error(status);
    tempint = MAXROW;
    status = nc_put_att_int(ncid, rowvarid, "valid_max", NC_INT, 1, &tempint);  Handle_Error(status);
    status = nc_put_att_text(ncid, rowvarid, "long_name",strlen("Grid Row"), "Grid Row");  Handle_Error(status);
    if (COMPRESS) {
      status = nc_put_att_text(ncid, rowvarid, "associate", strlen("(row col)"), "(row col)");  Handle_Error(status);
    }
    else {
      status = nc_put_att_text(ncid, rowvarid, "associate", strlen("row col"), "row col");  Handle_Error(status);
    }
    tempint = NODATA_INT;
    status = nc_put_att_int(ncid, rowvarid, "missing_value", NC_INT, 1, &tempint);  Handle_Error(status);

    // Col
    status = nc_def_var(ncid, "col", NC_INT, ndim, dims, &colvarid);  Handle_Error(status);
    status = nc_put_att_text(ncid, colvarid, "axis", strlen("YX"),"YX");  Handle_Error(status);
    status = nc_put_att_text(ncid, colvarid, "units", strlen("-"), "-");  Handle_Error(status);
    tempint = MINCOL;
    status = nc_put_att_int(ncid, colvarid, "valid_min", NC_INT, 1, &tempint);  Handle_Error(status);
    tempint = MAXCOL;
    status = nc_put_att_int(ncid, colvarid, "valid_max", NC_INT, 1, &tempint);  Handle_Error(status);
    status = nc_put_att_text(ncid, colvarid, "long_name",strlen("Grid Col"), "Grid Col");  Handle_Error(status);
    if (COMPRESS) {
      status = nc_put_att_text(ncid, colvarid, "associate", strlen("(row col)"), "(row col)");  Handle_Error(status);
    }
    else {
      status = nc_put_att_text(ncid, colvarid, "associate", strlen("row col"), "row col");  Handle_Error(status);
    }
    tempint = NODATA_INT;
    status = nc_put_att_int(ncid, colvarid, "missing_value", NC_INT, 1, &tempint);  Handle_Error(status);
  }

  // Latitude
  status = nc_def_var(ncid, "nav_lat", NC_FLOAT, ndim, dims, &latvarid);  Handle_Error(status);
  status = nc_put_att_text(ncid, latvarid, "axis", strlen("YX"),"YX");  Handle_Error(status);
  status = nc_put_att_text(ncid, latvarid, "units", strlen("degrees_north"), "degrees_north");  Handle_Error(status);
  tempfloat = -90.0;
  status = nc_put_att_float(ncid, latvarid, "valid_min", NC_FLOAT, 1, &tempfloat);  Handle_Error(status);
  tempfloat = 90.0;
  status = nc_put_att_float(ncid, latvarid, "valid_max", NC_FLOAT, 1, &tempfloat);  Handle_Error(status);
  status = nc_put_att_text(ncid, latvarid, "long_name",strlen("Latitude"), "Latitude");  Handle_Error(status);
  if (COMPRESS) {
    status = nc_put_att_text(ncid, latvarid, "associate", strlen("(row col)"), "(row col)");  Handle_Error(status);
  }
  else {
    status = nc_put_att_text(ncid, latvarid, "associate", strlen("row col"), "row col");  Handle_Error(status);
  }
  tempfloat = NODATA_FLOAT;
  status = nc_put_att_float(ncid, latvarid, "missing_value", NC_FLOAT, 1, &tempfloat);  Handle_Error(status);

  // Longitude
  status = nc_def_var(ncid, "nav_lon", NC_FLOAT, ndim, dims, &lonvarid);  Handle_Error(status);
  status = nc_put_att_text(ncid, lonvarid, "axis", strlen("YX"),"YX");  Handle_Error(status);
  status = nc_put_att_text(ncid, lonvarid, "units", strlen("degrees_east"), "degrees_east");  Handle_Error(status);
  tempfloat = -180.0;
  status = nc_put_att_float(ncid, lonvarid, "valid_min", NC_FLOAT, 1, &tempfloat);  Handle_Error(status);
  tempfloat = 180.0;
  status = nc_put_att_float(ncid, lonvarid, "valid_max", NC_FLOAT, 1, &tempfloat);  Handle_Error(status);
  status = nc_put_att_text(ncid, lonvarid, "modulo", strlen("360.0"), "360.0");  Handle_Error(status);
  status = nc_put_att_text(ncid, lonvarid, "topology", strlen("circular"), "circular");  Handle_Error(status);
  status = nc_put_att_text(ncid, lonvarid, "long_name",strlen("Longitude"), "Longitude");  Handle_Error(status);
  if (COMPRESS) {
    status = nc_put_att_text(ncid, lonvarid, "associate", strlen("(row col)"), "(row col)");  Handle_Error(status);
  }
  else {
    status = nc_put_att_text(ncid, lonvarid, "associate", strlen("row col"), "row col");  Handle_Error(status);
  }
  tempfloat = NODATA_FLOAT;
  status = nc_put_att_float(ncid, lonvarid, "missing_value", NC_FLOAT, 1, &tempfloat);  Handle_Error(status);

  // Landmask
  status = nc_def_var(ncid, "land", NC_INT, ndim, dims, &landvarid);  Handle_Error(status);
  if (COMPRESS) {
    status = nc_put_att_text(ncid, landvarid, "compress", strlen("y x"), "y x");  Handle_Error(status);
  }
  else {
    status = nc_put_att_text(ncid, landvarid, "axis", strlen("YX"),"YX");  Handle_Error(status);
    status = nc_put_att_text(ncid, landvarid, "units", strlen("0=invalid, 1=valid"), "0=invalid, 1=valid");  Handle_Error(status);
    status = nc_put_att_text(ncid, landvarid, "associate", strlen("row col"), "row col");  Handle_Error(status);
  }
  status = nc_put_att_text(ncid, landvarid, "long_name",strlen("Land Mask"), "Land Mask");  Handle_Error(status);

  // Level
  ndim=1;
  dims[0] = zdimid;
  status = nc_def_var(ncid, "level", NC_FLOAT, ndim, dims, &levvarid);  Handle_Error(status);
  status = nc_put_att_text(ncid, levvarid, "units", strlen(lev_units), lev_units);  Handle_Error(status);
  status = nc_put_att_text(ncid, levvarid, "positive", strlen(lev_positive), lev_positive);  Handle_Error(status);
  tempfloat = LEVMIN;
  status = nc_put_att_float(ncid, levvarid, "valid_min", NC_FLOAT, 1, &tempfloat);  Handle_Error(status);
  tempfloat = LEVMAX;
  status = nc_put_att_float(ncid, levvarid, "valid_max", NC_FLOAT, 1, &tempfloat);  Handle_Error(status);
  status = nc_put_att_text(ncid, levvarid, "long_name", strlen(lev_long_name), lev_long_name);  Handle_Error(status);

  // Time
  ndim=1;
  dims[0]=tstepdimid;
  status = nc_def_var(ncid, "time", NC_FLOAT, ndim, dims, timevaridp);  Handle_Error(status);
  status = nc_put_att_text(ncid, *timevaridp, "units", strlen(time_units_str), time_units_str);  Handle_Error(status);
  status = nc_put_att_text(ncid, *timevaridp, "calendar", strlen("gregorian"), "gregorian");  Handle_Error(status);
  status = nc_put_att_text(ncid, *timevaridp, "title", strlen("Time"), "Time");  Handle_Error(status);
  status = nc_put_att_text(ncid, *timevaridp, "long_name", strlen("Time axis"), "Time axis");  Handle_Error(status);
  status = nc_put_att_text(ncid, *timevaridp, "origin", strlen(file_start_time_str), file_start_time_str);  Handle_Error(status);

  // Timestep
  ndim=1;
  dims[0]=tstepdimid;
  status = nc_def_var(ncid, "timestp", NC_INT, ndim, dims, timestepvaridp);  Handle_Error(status);
  status = nc_put_att_text(ncid, *timestepvaridp, "units", strlen(timestep_units_str), timestep_units_str);  Handle_Error(status);
  status = nc_put_att_text(ncid, *timestepvaridp, "title", strlen("Time Steps"), "Time Steps");  Handle_Error(status);
  tempint = (int)dt;
  status = nc_put_att_int(ncid, *timestepvaridp, "tstep_sec", NC_INT, 1, &tempint);  Handle_Error(status);
  status = nc_put_att_text(ncid, *timestepvaridp, "long_name", strlen("Time step axis"), "Time step axis");  Handle_Error(status);
  status = nc_put_att_text(ncid, *timestepvaridp, "origin", strlen(file_start_time_str), file_start_time_str);  Handle_Error(status);

//  fprintf(stderr,"Done defining coordinate variables\n");


  // Define the data variables and their attributes

  // Cell ID
  if (COMPRESS) {
    ndim = 1;
    dims[0] = landdimid;
  }
  else {
    ndim=2;
    dims[0] = ydimid;
    dims[1] = xdimid;
  }
  status = nc_def_var(ncid, "CellID", NC_INT, ndim, dims, &cellidvarid);  Handle_Error(status);
  status = nc_put_att_text(ncid, cellidvarid, "axis", strlen("YX"),"YX");  Handle_Error(status);
  status = nc_put_att_text(ncid, cellidvarid, "long_name", strlen("Cell ID"), "Cell ID");  Handle_Error(status);
  if (COMPRESS) {
    status = nc_put_att_text(ncid, cellidvarid, "associate", strlen("(row col)"), "(row col)");  Handle_Error(status);
  }
  else {
    status = nc_put_att_text(ncid, cellidvarid, "associate", strlen("row col"), "row col");  Handle_Error(status);
  }
  tempint = NODATA_INT;
  status = nc_put_att_int(ncid, cellidvarid, "missing_value", NC_INT, 1, &tempint);  Handle_Error(status);

  // Misc 3d and 4d vars
  for(v=0; v<(NUM3d+NUM4d); v++) {
    if(!strcasecmp(var_atts[v].read,"TRUE")) {
      if(!strcasecmp(var_atts[v].z_dep,"FALSE")) {
        if (COMPRESS) {
          ndim=2;
          dims[0] = tstepdimid;
          dims[1] = landdimid;
        }
        else {
          ndim=3;
          dims[0] = tstepdimid;
          dims[1] = ydimid;
          dims[2] = xdimid;
        }
        status = nc_def_var(ncid, var_atts[v].name, NC_FLOAT, ndim, dims, &(var_atts[v].id));  Handle_Error(status);
        status = nc_put_att_text(ncid, var_atts[v].id, "axis", strlen("TYX"),"TYX");  Handle_Error(status);
        status = nc_put_att_text(ncid, var_atts[v].id, "units", strlen(var_atts[v].units), var_atts[v].units);  Handle_Error(status);
        status = nc_put_att_text(ncid, var_atts[v].id, "long_name", strlen(var_atts[v].long_name), var_atts[v].long_name);  Handle_Error(status);
        if (COMPRESS) {
          status = nc_put_att_text(ncid, var_atts[v].id, "associate", strlen("time (row col)"), "time (row col)");  Handle_Error(status);
        }
        else {
          status = nc_put_att_text(ncid, var_atts[v].id, "associate", strlen("time row col"), "time row col");  Handle_Error(status);
        }
        tempfloat = NODATA_FLOAT;
        status = nc_put_att_float(ncid, var_atts[v].id, "missing_value", NC_FLOAT, 1, &tempfloat);  Handle_Error(status);
      }
      else {
        if (COMPRESS) {
          ndim=3;
          dims[0] = tstepdimid;
          dims[1] = zdimid;
          dims[2] = landdimid;
        }
        else {
          ndim=4;
          dims[0] = tstepdimid;
          dims[1] = zdimid;
          dims[2] = ydimid;
          dims[3] = xdimid;
        }
        status = nc_def_var(ncid, var_atts[v].name, NC_FLOAT, ndim, dims, &(var_atts[v].id));  Handle_Error(status);
        status = nc_put_att_text(ncid, var_atts[v].id, "axis", strlen("TZYX"),"TZYX");  Handle_Error(status);
        status = nc_put_att_text(ncid, var_atts[v].id, "units", strlen(var_atts[v].units), var_atts[v].units);  Handle_Error(status);
        status = nc_put_att_text(ncid, var_atts[v].id, "long_name", strlen(var_atts[v].long_name), var_atts[v].long_name);  Handle_Error(status);
        if (COMPRESS) {
          status = nc_put_att_text(ncid, var_atts[v].id, "associate", strlen("time level (row col)"), "time level (row col)");  Handle_Error(status);
        }
        else {
          status = nc_put_att_text(ncid, var_atts[v].id, "associate", strlen("time level row col"), "time level row col");  Handle_Error(status);
        }
        tempfloat = NODATA_FLOAT;
        status = nc_put_att_float(ncid, var_atts[v].id, "missing_value", NC_FLOAT, 1,&tempfloat);  Handle_Error(status);
      }
    }
  }

//  fprintf(stderr,"Done defining data variables\n");


  // Global attributes

  status = nc_put_att_text(ncid, NC_GLOBAL, "file_name", strlen(outfile), outfile);  Handle_Error(status);
  status = nc_put_att_text(ncid, NC_GLOBAL, "Conventions", strlen("GDT 1.2"), "GDT 1.2");  Handle_Error(status);
  status = nc_put_att_text(ncid, NC_GLOBAL, "institution", strlen(global_atts[0]),global_atts[0]); Handle_Error(status);
  status = nc_put_att_text(ncid, NC_GLOBAL, "sources", strlen(global_atts[1]),global_atts[1]); Handle_Error(status);
  status = nc_put_att_text(ncid, NC_GLOBAL, "production", strlen(global_atts[2]),global_atts[2]); Handle_Error(status);
  status = nc_put_att_text(ncid, NC_GLOBAL, "history", strlen(global_atts[3]),global_atts[3]); Handle_Error(status);
  status = nc_put_att_text(ncid, NC_GLOBAL, "projection", strlen(global_atts[4]),global_atts[4]); Handle_Error(status);
  status = nc_put_att_text(ncid, NC_GLOBAL, "SurfSgn_convention", strlen(global_atts[5]),global_atts[5]); Handle_Error(status);

//  fprintf(stderr,"Done defining global attributes\n");

  // Finish the definition phase

  status = nc_enddef(ncid);  Handle_Error(status);


  // Write coordinate variables

  if (GRIDFILE) {
    // Row
    if (COMPRESS) {
      // If COMPRESS, write grid row info directly to output file
      for (k=0; k<NCELLS; k++) {
        temp_array_int_cmp[k] = grid[k].row;
      }
      status = nc_put_var_int(ncid, rowvarid, temp_array_int_cmp);  Handle_Error(status);
    }
    else {
      // No compression; pad invalid cells with NODATA
      k = 0;
      for (g=0; g<NROWS*NCOLS; g++) {
        if (g == grid[k].landmask) {
          temp_array_int[g] = grid[k].row;
          k++;
        }
        else {
          temp_array_int[g] = NODATA_INT;
        }
      }
      status = nc_put_var_int(ncid, rowvarid, temp_array_int);  Handle_Error(status);
    }

    // Col
    if (COMPRESS) {
      // If COMPRESS, write grid col info directly to output file
      for (k=0; k<NCELLS; k++) {
        temp_array_int_cmp[k] = grid[k].col;
      }
      status = nc_put_var_int(ncid, colvarid, temp_array_int_cmp);  Handle_Error(status);
    }
    else {
      // No compression; pad invalid cells with NODATA
      k = 0;
      for (g=0; g<NROWS*NCOLS; g++) {
        if (g == grid[k].landmask) {
          temp_array_int[g] = grid[k].col;
          k++;
        }
        else {
          temp_array_int[g] = NODATA_INT;
        }
      }
      status = nc_put_var_int(ncid, colvarid, temp_array_int);  Handle_Error(status);
    }
  }

  // Lat
  if (COMPRESS) {
    // If COMPRESS, write grid lat info directly to output file
    for (k=0; k<NCELLS; k++) {
      temp_array_cmp[k] = grid[k].lat;
    }
    status = nc_put_var_float(ncid, latvarid, temp_array_cmp);  Handle_Error(status);
  }
  else {
    // No compression; pad invalid cells with NODATA
    k = 0;
    for (g=0; g<NROWS*NCOLS; g++) {
      if (g == grid[k].landmask) {
        temp_array[g] = grid[k].lat;
        k++;
      }
      else {
        temp_array[g] = NODATA_FLOAT;
      }
    }
    status = nc_put_var_float(ncid, latvarid, temp_array);  Handle_Error(status);
  }

  // Lon
  if (COMPRESS) {
    // If COMPRESS, write grid lon info directly to output file
    for (k=0; k<NCELLS; k++) {
      temp_array_cmp[k] = grid[k].lon;
    }
    status = nc_put_var_float(ncid, lonvarid, temp_array_cmp);  Handle_Error(status);
  }
  else {
    // No compression; pad invalid cells with NODATA
    k = 0;
    for (g=0; g<NROWS*NCOLS; g++) {
      if (g == grid[k].landmask) {
        temp_array[g] = grid[k].lon;
        k++;
      }
      else {
        temp_array[g] = NODATA_FLOAT;
      }
    }
    status = nc_put_var_float(ncid, lonvarid, temp_array);  Handle_Error(status);
  }

  // Landmask
  if (COMPRESS) {
    // If COMPRESS, write grid landmask info directly to output file
    for (k=0; k<NCELLS; k++) {
      temp_array_int_cmp[k] = grid[k].landmask;
    }
    status = nc_put_var_int(ncid, landvarid, temp_array_int_cmp);  Handle_Error(status);
  }
  else {
    // No compression; valid cells = 1, invalid cells = 0
    k = 0;
    for (g=0; g<NROWS*NCOLS; g++) {
      if (g == grid[k].landmask) {
        temp_array_int[g] = 1;
        k++;
      }
      else {
        temp_array_int[g] = 0;
      }
    }
    status = nc_put_var_int(ncid, landvarid, temp_array_int);  Handle_Error(status);
  }

  // Level
  status = nc_put_var_float(ncid, levvarid, levels);  Handle_Error(status);

  // CellID
  if (COMPRESS) {
    // If COMPRESS, write grid cellid info directly to output file
    for (k=0; k<NCELLS; k++) {
      temp_array_int_cmp[k] = grid[k].cellid;
    }
    status = nc_put_var_int(ncid, cellidvarid, temp_array_int_cmp);  Handle_Error(status);
  }
  else {
    // No compression; pad invalid cells with NODATA
    k = 0;
    for (g=0; g<NROWS*NCOLS; g++) {
      if (g == grid[k].landmask) {
        temp_array_int[g] = grid[k].cellid;
        k++;
      }
      else {
        temp_array_int[g] = NODATA_INT;
      }
    }
    status = nc_put_var_int(ncid, cellidvarid, temp_array_int);  Handle_Error(status);
  }

//  fprintf(stderr,"Done writing coordinate variables\n");

  // De-allocate space
  if (COMPRESS) {
    free((char*)temp_array_int_cmp);
    free((char*)temp_array_cmp);
  }
  else {
    free((char*)temp_array_int);
    free((char*)temp_array);
  }

}


//*************************************************************************************************
// Write_NetCDF: writes 1 timestep's worth of data to netcdf files
//*************************************************************************************************
void Write_NetCDF(int ncid, struct GridInfo *grid, int timevarid, int timestepvarid, struct VarAtt *var_atts, int t_index, float time, int timestep, float **var3d, float ***var4d)
{

  int status;
  int i,j,k,t,l,v,g;
  int ndim, dims[MAXDIM];
  float *temp_array_cmp;
  float *temp_array;
  int varcount3, varcount4;
  size_t start1d[1];
  size_t count1d[1];
  size_t start3d[3];
  size_t count3d[3];
  size_t start4d[4];
  size_t count4d[4];
  size_t start3d_cmp[2];
  size_t count3d_cmp[2];
  size_t start4d_cmp[3];
  size_t count4d_cmp[3];

  // Allocate temp arrays
  if (COMPRESS) {
    temp_array_cmp = (float*)calloc(NCELLS, sizeof(float));
  }
  else {
    temp_array = (float*)calloc(NROWS*NCOLS, sizeof(float));
  }

  // Time
  start1d[0] = t_index;
  count1d[0] = 1;
  status = nc_put_vara_float(ncid, timevarid, start1d, count1d, &time);  Handle_Error(status);
  status = nc_put_vara_int(ncid, timestepvarid, start1d, count1d, &timestep);  Handle_Error(status);

  // Write data variables

//  fprintf(stderr,"Start to write data variables\n");

  // Misc 3d and 4d vars
  varcount3 = varcount4 = 0;
  if (COMPRESS) {
    // If COMPRESS, only write values for valid grid cells
    for(v=0; v<(NUM3d+NUM4d); v++) {
      if(!strcasecmp(var_atts[v].read,"TRUE")) {
        if(!strcasecmp(var_atts[v].z_dep,"FALSE")) {
          // 3D vars
          for(k=0; k<NCELLS; k++) {
            temp_array_cmp[k] = var3d[varcount3][k];
          }
          start3d_cmp[0] = t_index;
          start3d_cmp[1] = 0;
          count3d_cmp[0] = 1;
          count3d_cmp[1] = NCELLS;
          status = nc_put_vara_float(ncid, var_atts[v].id, start3d_cmp, count3d_cmp, temp_array_cmp);  Handle_Error(status);
          varcount3++;
        }
        else {
          // 4D vars
          for(l=0; l<NLEVELS; l++) {
            for(k=0; k<NCELLS; k++) {
              temp_array_cmp[k] = var4d[varcount4][k][l];
            }
            start4d_cmp[0] = t_index;
            start4d_cmp[1] = l;
            start4d_cmp[2] = 0;
            count4d_cmp[0] = 1;
            count4d_cmp[1] = 1;
            count4d_cmp[2] = NCELLS;
            status = nc_put_vara_float(ncid, var_atts[v].id, start4d_cmp, count4d_cmp, temp_array_cmp);  Handle_Error(status);
          }
          varcount4++;
        }
      }
    }
  }
  else {
    // No compression, so write values for all grid cells;
    // if grid cell is not valid (g != grid[k].landmask), then write NODATA_FLOAT
    for(v=0; v<(NUM3d+NUM4d); v++) {
      if(!strcasecmp(var_atts[v].read,"TRUE")) {
        if(!strcasecmp(var_atts[v].z_dep,"FALSE")) {
          // 3D vars
          k = 0;
          for(g=0; g<NROWS*NCOLS; g++) {
            if (g == grid[k].landmask) {
              temp_array[g] = var3d[varcount3][k];
              k++;
            }
            else {
              temp_array[g] = NODATA_FLOAT;
            }
          }
          start3d[0] = t_index;
          start3d[1] = 0;
          start3d[2] = 0;
          count3d[0] = 1;
          count3d[1] = NROWS;
          count3d[2] = NCOLS;
          status = nc_put_vara_float(ncid, var_atts[v].id, start3d, count3d, temp_array);  Handle_Error(status);
          varcount3++;
        }
        else {
          // 4D vars
          for(l=0; l<NLEVELS; l++) {
            k = 0;
            for(g=0; g<NROWS*NCOLS; g++) {
              if (g == grid[k].landmask) {
                temp_array[g] = var4d[varcount4][k][l];
                k++;
              }
              else {
                temp_array[g] = NODATA_FLOAT;
              }
            }
            start4d[0] = t_index;
            start4d[1] = l;
            start4d[2] = 0;
            start4d[3] = 0;
            count4d[0] = 1;
            count4d[1] = 1;
            count4d[2] = NROWS;
            count4d[3] = NCOLS;
            status = nc_put_vara_float(ncid, var_atts[v].id, start4d, count4d, temp_array);  Handle_Error(status);
          }
          varcount4++;
        }
      }
    }
  }

//  fprintf(stderr,"Done writing data variables\n");

  // De-allocate space
  if (COMPRESS) {
    free((char*)temp_array_cmp);
  }
  else {
    free((char*)temp_array);
  }

}

//*************************************************************************************************
// Close_VIC_Files: close all open VIC files
//*************************************************************************************************
void Close_VIC_Files(FILE **infilehandle)
{

  int k;

  for (k=0; k<NCELLS; k++) {
    fclose(infilehandle[k]);
  }

}

//*************************************************************************************************
// Date_2_TM: stores a string containing a date (format: yyyy-mm-dd)
// in a variable of type struct tm.
//*************************************************************************************************
void Date_2_TM(char *date_str, struct tm *date_struct)
{

  char *tok;

  if ((tok = strtok(date_str, "-")) != NULL)
    date_struct->tm_year = atoi(tok) - 1900;
  if ((tok = strtok(NULL, "-")) != NULL)
    date_struct->tm_mon = atoi(tok) - 1;
  if ((tok = strtok(NULL, "-")) != NULL)
    date_struct->tm_mday = atoi(tok);

}


//*************************************************************************************************
// Time_2_TM: stores a string containing a time (format: hh:mm:ss)
// in a variable of type struct tm.
//*************************************************************************************************
void Time_2_TM(char *time_str, struct tm *date_struct)
{

  char *tok;

  if ((tok = strtok(time_str, "-")) != NULL)
    date_struct->tm_hour = atoi(tok);
  if ((tok = strtok(NULL, "-")) != NULL)
    date_struct->tm_min = atoi(tok);
  if ((tok = strtok(NULL, "-")) != NULL)
    date_struct->tm_sec = atoi(tok);

}


//*************************************************************************************************
//  diff_date: computes difference in seconds between date1 and date2
//*************************************************************************************************
long long diff_date(struct tm date1, struct tm date2) {

  long long dsec;
  int i;
  long ndays, ndays1, ndays2;

  // Compute difference in sec between times of day
  dsec = ((date1.tm_hour - date2.tm_hour)*60 + (date1.tm_min - date2.tm_min))*60 + date1.tm_sec - date2.tm_sec;

  // Compute number of days since 0000-01-00 for both dates
  ndays = date1.tm_mday;
  for (i=1; i<=date1.tm_mon; i++) {
    ndays += dmonth[i-1];
    if (LEAPYR(date1.tm_year) && i==1) {
      ndays++;
    }
  }
  for (i=0; i<date1.tm_year; i++) {
    ndays += 365;
    if (LEAPYR(i)) {
      ndays++;
    }
  }
  ndays1 = ndays;
  ndays = date2.tm_mday;
  for (i=1; i<=date2.tm_mon; i++) {
    ndays += dmonth[i-1];
    if (LEAPYR(date2.tm_year) && i==1) {
      ndays++;
    }
  }
  for (i=0; i<date2.tm_year; i++) {
    ndays += 365;
    if (LEAPYR(i)) {
      ndays++;
    }
  }
  ndays2 = ndays;

  // Add difference in sec between calendar days
  dsec += (ndays1 - ndays2)*86400LL;

  return dsec;
  
}


//*************************************************************************************************
//  julian: computes julian day, given year, month, and day of month
//          month should be indexed from 0 (January = 0)
//*************************************************************************************************
int julian(int year, int mon, int mday) {

  int i;
  int jday;

  jday = mday;

  if (mon > 0) {
    for (i=0; i<mon; i++) { 
      jday += dmonth[i];
      if (LEAPYR(year) && i==1) {
        jday++;
      }
    }
  }

  return jday;

}



//*************************************************************************************************
//  add_sec_date: computes new date by adding a given number of seconds to a given date
//*************************************************************************************************
void add_sec_date(struct tm start_date, long long sec_to_add, struct tm *new_date) {

  int nhour, nmin, nsec;
  long ndays;
  int jday;
  int days_in_year, days_in_month, days_until_year_rollover, days_until_month_rollover, mon;

  // Initialize new_date
  new_date->tm_year = start_date.tm_year;
  new_date->tm_mon = start_date.tm_mon;
  new_date->tm_mday = start_date.tm_mday;
  new_date->tm_hour = start_date.tm_hour;
  new_date->tm_min = start_date.tm_min;
  new_date->tm_sec = start_date.tm_sec;

  // Convert sec_to_add into ndays, nhours, etc.
  nsec = sec_to_add % 60;
  nmin = ( (sec_to_add - nsec) % 3600 ) / 60;
  nhour = ( (sec_to_add - (nmin*60) - nsec) % 86400 ) / 3600;
  ndays = (int)(sec_to_add / 86400);

  // Add nhour, nmin, nsec to new_date; carry over as necessary
  new_date->tm_sec += nsec;
  if (new_date->tm_sec >= 60) {
    new_date->tm_sec -= 60;
    nmin++;
  }
  else if (new_date->tm_sec < 0) {
    new_date->tm_sec += 60;
    nmin--;
  }
  new_date->tm_min += nmin;
  if (new_date->tm_min >= 60) {
    new_date->tm_min -= 60;
    nhour++;
  }
  else if (new_date->tm_min < 0) {
    new_date->tm_min += 60;
    nhour--;
  }
  new_date->tm_hour += nhour;
  if (new_date->tm_hour >= 24) {
    new_date->tm_hour -= 24;
    ndays++;
  }
  else if (new_date->tm_hour < 0) {
    new_date->tm_hour += 24;
    ndays--;
  }

  // Loop over ndays, subtracting out year (or month) worth of days at a time,
  // taking leap years into account
  while (ndays) {

    // Compute number of days required to increment/decrement year
    days_in_year = 365;
    if (LEAPYR(new_date->tm_year)) {
      // Leap year
      days_in_year++;
    }
    jday = julian(new_date->tm_year, new_date->tm_mon, new_date->tm_mday);
    if (ndays > 0)
      days_until_year_rollover = days_in_year - jday + 1;
    else if (ndays < 0)
      days_until_year_rollover = -jday;

    // Increment/decrement year if possible
    if (ndays > 0 && ndays >= days_until_year_rollover) {
      new_date->tm_year++;
      new_date->tm_mon = 0;
      new_date->tm_mday = 1;
      ndays -= days_until_year_rollover;
    }
    else if (ndays < 0 && ndays <= days_until_year_rollover) {
      new_date->tm_year--;
      new_date->tm_mon = 11;
      new_date->tm_mday = 31;
      ndays -= days_until_year_rollover;
    }
    else {

      while (ndays) {

        // Compute number of days required to increment/decrement month
        days_in_month = dmonth[new_date->tm_mon];
        if (LEAPYR(new_date->tm_year) && new_date->tm_mon == 1) {
          // February of a leap year
          days_in_month++;
        }
        if (ndays > 0)
          days_until_month_rollover = days_in_month - new_date->tm_mday + 1;
        else if (ndays < 0)
          days_until_month_rollover = -new_date->tm_mday;

        // Increment/decrement month if possible
        if (ndays > 0 && ndays >= days_until_month_rollover) {
          new_date->tm_mon++;
          new_date->tm_mday = 1;
          ndays -= days_until_month_rollover;
        }
        else if (ndays < 0 && ndays <= days_until_month_rollover) {
          new_date->tm_mon--;
          new_date->tm_mday = dmonth[new_date->tm_mon];
          ndays -= days_until_month_rollover;
        }
        else {

          // Add remainder to day
          new_date->tm_mday += ndays;
          ndays = 0;
        }

      }

    }

  }

}



//*************************************************************************************************
// Handle_Error: Error reporting function.
//*************************************************************************************************
void Handle_Error(int status) 
{
  if (status != NC_NOERR) {
    fprintf(stderr, "%s\n", nc_strerror(status));
    exit(-1);
  }
}
