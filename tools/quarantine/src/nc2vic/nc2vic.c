#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <netcdf.h>
#include <time.h>

#include "nc2vicIO.h"

#ifndef FALSE
#define FALSE 0
#define TRUE !FALSE
#endif

#define NODATA_INT -9999
#define NODATA_FLOAT 1.e20
#define MAXVAR 200
#define MAXDIM 5
#define MAXSTRING 500
#define MAXLEV 15
#define NGLOBALS 7
#define LEAPYR(y) (!((y)%400) || (!((y)%4) && ((y)%100)))
#define FILE_HANDLE_BUFFER_COUNT 100
#define DEBUG FALSE

char *optstring = "i:o:p:f:atv:";
static int dmonth[12]={31,28,31,30,31,30,31,31,30,31,30,31};
int NRECS, NLEVELS, NCELLS, NROWS, NCOLS;
int LEVMIN, LEVMAX, COLMIN, COLMAX, ROWMIN, ROWMAX;
int NUM3d, NUM4d;
int COMPRESS = 0;
int APPEND = 0;
int PRINT_REC_TIME = 0;
int GRIDFILE = 0;
int VARLIST_SPECIFIED = 0;
char FORMAT[10];

struct OutputVar {
  char* name;
  int used;
  int position;
};

struct VarAtt {
  char name[15];
  char units[15];
  char z_dep[5];
  char sign[8];
  float mult;
  char long_name[40];
  int id;
};

struct DimInfo {
  int xdimid;
  int xlen;
  int ydimid;
  int ylen;
  int zdimid;
  int zlen;
  int tstepdimid;
  int tsteplen;
  int landdimid;
  int landlen;
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

void Read_Args(int, char **, char *, char *, char *, struct OutputVar*, int*); 
void Usage(char *);
void Get_Dimensions(char *, struct DimInfo *);
void Read_Metadata(char *, struct DimInfo, struct GridInfo *, float *, char *, char *, char *,
  char **, struct tm *, int *, struct VarAtt *, struct OutputVar*, int*);
void Write_Gridfile(char *, struct GridInfo *);
void Write_Metadata(char *, char **, struct tm *, int, struct VarAtt *, struct OutputVar*, int);
void Check_VIC_Files(char *, char *, struct GridInfo *, FILE **, int, int);
void Read_NetCDF(char *, struct GridInfo *, struct VarAtt *, struct OutputVar *, int, int, float **, float ***, int, int);
void Write_VIC(FILE **, struct VarAtt *, float **, float ***, struct tm *, int, struct OutputVar*, int, int, int);
void Close_VIC_Files(FILE **, int);
void Date_2_TM(char *, struct tm *);
void Time_2_TM(char *, struct tm *);
long long dt2sec(struct tm, int, char *);
int julian(int, int, int);
void add_sec_date(struct tm, long long, struct tm *);
void Handle_Error(int);
int Handle_V_Option(struct OutputVar*,  char*);
int isPrintableVariable(struct VarAtt*, struct OutputVar*, int);
void appendOutputVariable(int*, struct OutputVar*, char*);


//*************************************************************************************************
// Begin main program.
//*************************************************************************************************

int main(int argc, char *argv[])
{
  char infile[150], outpath[150], prefix[150];
  char filename[150], metafile[150], gridfile[150];
  FILE **outfilehandle;
  float **var3d;
  float ***var4d;
  int i, j, k, l, t, g;
  int d, h, v, ov, isValid, count3, count4;
  int dt;
  int year,mon;
  int status;
  float levels[NLEVELS];
  struct tm *data_times;
  char lev_units[5];
  char lev_long_name[20];
  char lev_positive[5];
  char *global_atts[NGLOBALS];
  struct DimInfo dim_info;
  struct VarAtt var_atts[MAXVAR];
  struct GridInfo *grid;
  struct OutputVar outputVars[MAXVAR];
  int outputVarLen = 0;
  int startHandle = 0;
  int filesRemaining = 0;
  int fileBufferLength = 0;

  //
  // Allocate space for input params & metadata
  //
  for (i=0; i<NGLOBALS; i++) {
    global_atts[i] = (char*)calloc(200,sizeof(char));
  }

  // Initialize FORMAT
  strcpy(FORMAT,"ASCII");

  //
  // Get input params
  //

  // Read cmdline parameters
  Read_Args(argc, argv, infile, outpath, prefix, outputVars, &outputVarLen);

  // Get data dimensions from headers of netcdf files
  Get_Dimensions(infile, &dim_info);

  // Allocate space/time arrays
  if (COMPRESS) {
    // NCELLS is known at this point if COMPRESS is TRUE
    grid = (struct GridInfo *)calloc(NCELLS,sizeof(struct GridInfo));
  }
  else {
    // NCELLS is not known at this point if COMPRESS is FALSE
    // so allocate max possible number of elements just to be safe
    grid = (struct GridInfo *)calloc(NROWS*NCOLS,sizeof(struct GridInfo));
  }
  data_times = (struct tm*)calloc(NRECS,sizeof(struct tm));

  // Get metadata from header of netcdf file
  Read_Metadata(infile, dim_info, grid, levels, lev_units, lev_long_name, lev_positive,
    global_atts, data_times, &dt, var_atts, outputVars, &outputVarLen);

  // Build metafile and gridfile names
  strcpy(metafile,outpath);
  strcat(metafile,"/metadata.txt");
  strcpy(gridfile,outpath);
  strcat(gridfile,"/gridfile.txt");

  /* spool info to sdtout */
  echoParams(infile,outpath, prefix, metafile, gridfile, dt, data_times, var_atts, outputVars, outputVarLen);

  //
  // Allocate space for data
  //

  // Now NCELLS is known for COMPRESS = TRUE or FALSE
  fileBufferLength = FILE_HANDLE_BUFFER_COUNT;
  outfilehandle = (FILE**)calloc(fileBufferLength,sizeof(FILE*));

  // Allocate arrays of variables
  if ( (var3d = (float**)calloc(NUM3d,sizeof(float*))) == NULL) {
    fprintf(stderr, "ERROR: cannot allocate sufficient memory for data array\n");
    exit(1);
  }
  if(NUM4d > 0) {
    if ( (var4d = (float***)calloc(NUM4d,sizeof(float**))) == NULL) {
      fprintf(stderr, "ERROR: cannot allocate sufficient memory for data array\n");
      exit(1);
    }
  }
  for (ov=0;ov<outputVarLen;ov++) {

    // find the var_atts we are looking for
    isValid = FALSE;
    count3 = count4 = -1; /* Must be initialized to -1 cause we will icrement it to 0 */
    for (v=0; v<(NUM3d+NUM4d); v++) {

      if (!strcasecmp(var_atts[v].z_dep,"FALSE")) {
        count3++;
      }
      else {
        count4++;
      }

      if (!strcasecmp(outputVars[ov].name, var_atts[v].name)) {
        isValid = TRUE;
        break;
      }

    }

    // if we didn't find it, we've got an error!
    if (isValid == FALSE) {
      fprintln(stderr, "Unable to locate variable %s in NetCDF file. Exiting", outputVars[ov].name);
      exit(1);
    }

    // only allocate space for the variables we care about
    if (!strcasecmp(var_atts[v].z_dep,"FALSE")) {
      if ( (var3d[count3] = (float*)calloc(NCELLS,sizeof(float))) == NULL) {
        fprintf(stderr, "ERROR: cannot allocate sufficient memory for data array\n");
        exit(1);
      }
    }
    else {
      if ( (var4d[count4] = (float**)calloc(NCELLS,sizeof(float*))) == NULL) {
        fprintf(stderr, "ERROR: cannot allocate sufficient memory for data array\n");
        exit(1);
      }
      for (k=0; k<NCELLS; k++) {
        if ( (var4d[count4][k] = (float*)calloc(NLEVELS,sizeof(float))) == NULL) {
          fprintf(stderr, "ERROR: cannot allocate sufficient memory for data array\n");
          exit(1);
        }
      }
    }

  }

  //
  // Write metadata and gridfile
  //
  Write_Metadata(metafile, global_atts, data_times, dt, var_atts, outputVars, outputVarLen);
  if (GRIDFILE) {
    Write_Gridfile(gridfile, grid);
  }

  //
  // Translation Section
  //

  filesRemaining = NCELLS;
  while (filesRemaining > 0 ) {

    /* the last time through, we won't have a full buffer */
    if (filesRemaining < FILE_HANDLE_BUFFER_COUNT) {
      fileBufferLength = filesRemaining;
    }

    // Open VIC files for writing
    Check_VIC_Files(outpath, prefix, grid, outfilehandle, startHandle, fileBufferLength);

    /* iterate over each Record, spooling data out to our files. */
    for (t=0; t<NRECS; t++) {

      /* Lets buffer backwards shall we? */
      // Read the netcdf file
      Read_NetCDF(infile, grid, var_atts, outputVars, outputVarLen, t, var3d, var4d, startHandle, fileBufferLength);

      // Write to VIC-format files
      Write_VIC(outfilehandle, var_atts, var3d, var4d, data_times, t, outputVars, outputVarLen, startHandle, fileBufferLength);

    }

    // Close VIC files
    Close_VIC_Files(outfilehandle, fileBufferLength);
    startHandle += fileBufferLength;
    filesRemaining -= fileBufferLength;
    ;
  }

  // Free up the memory allocated above
  free(outfilehandle);
  for (g=0; g<NGLOBALS; g++) {
    free(global_atts[g]);
  }
  free(grid);
  free(data_times);
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
  for (v=0; v<(NUM3d+NUM4d); v++) {
    free(outputVars[v].name);
  }

  return 0;

} // END PROGRAM


/**
 * Spools out all header data
 */
int echoParams(char* infile,
               char* outpath,
               char* prefix,
               char* metafile,
               char* gridfile,
               int dt,
               struct tm * data_times,
               struct VarAtt *var_atts,
               struct OutputVar *outputVars,
               int outputVarLen) {

  int v;
  int ov;

  // Echo params to user
  fprintf(stdout,"\n");
  fprintf(stdout,"** Converting from NetCDF to VIC **\n");
  fprintf(stdout,"\n");
  fprintf(stdout,"Input: %s\n",infile);
  fprintf(stdout,"Output: %s/%s*\n",outpath,prefix);
  fprintf(stdout,"Metadata file: %s\n",metafile);
  if (GRIDFILE) {
    fprintf(stdout,"Grid file: %s\n",gridfile);
  }
  fprintf(stdout,"\n");
  fprintf(stdout,"** Dimensions **\n");
  fprintf(stdout,"\n");
  if (GRIDFILE && !COMPRESS) {
    fprintf(stdout,"Grid rows: %d columns: %d\n",NROWS,NCOLS);
  }
  fprintf(stdout,"Number of active grid cells: %d\n",NCELLS);
  if (COMPRESS) {
    fprintf(stdout,"Compression by gathering: ON\n");
  }
  else {
    fprintf(stdout,"Compression by gathering: OFF\n");
  }
  fprintf(stdout,"Number of vertical levels: %d\n",NLEVELS);
  fprintf(stdout,"Number of records: %d\n",NRECS);
  fprintf(stdout,"Timestep (sec): %d\n",dt);
  fprintf(stdout,"Start date: %04d-%02d-%02d %02d:%02d:%02d\n",
    data_times[0].tm_year+1900,data_times[0].tm_mon+1,
    data_times[0].tm_mday,data_times[0].tm_hour,
    data_times[0].tm_min,data_times[0].tm_sec);
  fprintf(stdout,"End date: %04d-%02d-%02d %02d:%02d:%02d\n",
    data_times[NRECS-1].tm_year+1900,data_times[NRECS-1].tm_mon+1,
    data_times[NRECS-1].tm_mday,data_times[NRECS-1].tm_hour,
    data_times[NRECS-1].tm_min,data_times[NRECS-1].tm_sec);
  if (!strcasecmp(FORMAT,"ASCII")) {
    fprintf(stdout,"Format: ASCII\n");
  }
  else if (!strcasecmp(FORMAT,"SCIENTIFIC")) {
    fprintf(stdout,"Format: SCIENTIFIC\n");
  }
  else if (!strcasecmp(FORMAT,"BINARY")) {
    fprintf(stdout,"Format: BINARY\n");
  }
  fprintf(stdout,"\n");
  fprintf(stdout,"** Variables **\n");
  fprintf(stdout,"\n");
  fprintf(stdout,"Name            Units           Z-dep\n");
  for (ov=0;ov<outputVarLen;ov++) {

    // find the var_atts we are looking for
    for (v=0; v<(NUM3d+NUM4d); v++) {

      if (!strcasecmp(outputVars[ov].name, var_atts[v].name)) {
        fprintf(stdout,"%-15.15s %-15.15s %-5.5s\n", var_atts[v].name, var_atts[v].units, var_atts[v].z_dep);
        break;
      }

    }
  }

  fprintf(stdout,"\n");

  return;

}

//*************************************************************************************************
// Read_Args:  This routine checks the command line for valid program options.  If
// no options are found, or an invalid combination of them appear, the
// routine calls usage() to print the model usage to the screen, before exiting.
//*************************************************************************************************
void Read_Args(int argc, char *argv[], char *infile, char *outpath, char *prefix, struct OutputVar* outputVars, int* outputVarLen)
{
  extern int getopt();
  extern char *optarg;
  extern char *optstring;
  extern int optind;

  int optchar;

  if(argc==1) {
    Usage(argv[0]);
    exit(1);
  }
  
  while((optchar = getopt(argc, argv, optstring)) != EOF) {
    switch((char)optchar) {
    case 'i':
      /** Input Path **/
      strcpy(infile, optarg);
      break;
    case 'o':
      /** Output Path **/
      strcpy(outpath, optarg);
      break;
    case 'p':
      /** Output File Prefix **/
      strcpy(prefix, optarg);
      break;
    case 'v':
     /*
      * The 'v' case is a little bit special.  if this option is found
      * we iterate over the cmdline intil we find a '-' or EOF.
      * What we end up with is a list of columns to include.
      */

      if ((*outputVarLen = Handle_V_Option(outputVars, optarg)) == 0) {
        fprintln(stderr, "WARNING: -v option included, but no output variables were listed.");
      }
      VARLIST_SPECIFIED = 1;
      break;
    case 'f':
      /** Output File Format **/
      strcpy(FORMAT, optarg);
      break;
    case 'a':
      /** Append **/
      APPEND = 1;
      break;
    case 't':
      /** Print Each Record's Time **/
      PRINT_REC_TIME = 1;
      break;
    default:
      /** Print Usage if Invalid Command Line Arguments **/
      Usage(argv[0]);
      exit(1);
      break;
    }
  }

  // Validate FORMAT
  if (!strncasecmp(FORMAT,"ASC",3)) {
    strcpy(FORMAT,"ASCII");
  }
  else if (!strncasecmp(FORMAT,"SCI",3)) {
    strcpy(FORMAT,"SCIENTIFIC");
  }
  else if (!strncasecmp(FORMAT,"BIN",3)) {
    strcpy(FORMAT,"BINARY");
  }
  else {
    fprintf(stderr,"%s: Error: specified format %s not supported\n",argv[0],FORMAT);
    Usage(argv[0]);
    exit(1);
  }

}

//*************************************************************************************************
// Usage: Function to print out usage details.
//*************************************************************************************************
void Usage(char *temp)
{
  fprintf(stderr,"%s - Converts netcdf timeseries data to VIC-format.\n",temp);
  fprintf(stderr,"\n");
  fprintf(stderr,"Usage: %s  -i <infile> -o <outpath> -p <prefix> [-v <varlist>] [-f <format>] [-a] [-t]\n",temp);
  fprintf(stderr,"\n");
  fprintf(stderr,"This program takes a given netcdf file and writes its contents to a set of\n");
  fprintf(stderr,"ascii files, one file per grid cell.  The output files are formatted to have\n");
  fprintf(stderr,"one or more lines of space-separated fields.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"You may select whether to overwrite or append to any existing output files with\n");
  fprintf(stderr,"the same names.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"This program was written to work with netcdf files conforming to ALMA conventions.\n");
  fprintf(stderr,"If the names of variables or dimensions differ significantly from this standard,\n");
  fprintf(stderr,"this program may not be able to read the netcdf file.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"This program automatically determines whether the input netcdf file is indexed\n");
  fprintf(stderr,"on a grid or is compressed by gathering, based on whether the netcdf file\n");
  fprintf(stderr,"contains a dimension named \'land\'.  If this dimension is present, it is assumed\n");
  fprintf(stderr,"that the data in the netcdf file are indexed by this single dimension, rather than\n");
  fprintf(stderr,"by x and y.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"This program also creates a file (called \'metadata.txt\'), and places it in the same\n");
  fprintf(stderr,"directory as the output files.  Metadata.txt contains the names, units, and\n");
  fprintf(stderr,"descriptions of the variables from the input netcdf file, as well as the data\n");
  fprintf(stderr,"dimensions and beginning/ending times of the timeseries.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"In the case when the netcdf file contains variables named \'row\' and \'col\',\n");
  fprintf(stderr,"this program also creates a file (called \'gridfile.txt\') mapping the cells\n");
  fprintf(stderr,"to their lat, lon, row, and col.  This file is also placed in the output directory.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"-i <infile>\n");
  fprintf(stderr,"  <infile>        Input netcdf file\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"-o <outpath>\n");
  fprintf(stderr,"  <outpath>       Path to the location of output VIC files.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"-p <prefix>\n");
  fprintf(stderr,"  <prefix>        Prefix of output VIC filenames.  Files will be named as\n");
  fprintf(stderr,"                  prefix_lat_lon, where \'lat\' and \'lon\' are the latitude\n");
  fprintf(stderr,"                  and longitude of the corresponding grid cell.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"-v <varlist>      (optional)\n");
  fprintf(stderr,"  <varlist>       Comma-separated list of the variables to include in the output file.\n");
  fprintf(stderr,"                  Default: include all variables in the file.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"-f <format>       (optional)\n");
  fprintf(stderr,"  <format>        Format of output data.  Can be one of: (\"ascii\",\"scientific\")\n");
  fprintf(stderr,"                  Default: \"ascii\".\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"-a                (optional) If specified, output VIC files will be appended to\n");
  fprintf(stderr,"                  instead of being overwritten.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"-t                (optional) If specified, the time of each record will be written\n");
  fprintf(stderr,"                  to the beginning of the line in the output file.  Format: YYYY MM DD HH\n");
  fprintf(stderr,"\n");
}

//*************************************************************************************************
// Get_Dimensions: queries the netcdf file for dimension lengths
//*************************************************************************************************
void Get_Dimensions(char *infile, struct DimInfo *dim_info)
{

  int status;
  int ncid, xdimid, ydimid, tstepdimid, landdimid, zdimid;
  size_t tsteplen, landlen, xlen, ylen, zlen;

  // Open netcdf file
  if ((status =  nc_open(infile, NC_NOWRITE, &ncid)) != NC_NOERR) {
    fprintf(stderr,"Error: cannot open %s for reading\n",infile);
    exit(-1);
  }

  // Determine whether file is using compression by gathering
  if ((status = nc_inq_dimid(ncid, "land", &landdimid)) == NC_NOERR
      || (status = nc_inq_dimid(ncid, "nland", &landdimid)) == NC_NOERR) {
    // "land" is a dimension; file is using compression by gathering
    COMPRESS = 1;
    // Get number of valid cells
    status = nc_inq_dimlen(ncid, landdimid, &landlen); Handle_Error(status);
    NCELLS = (int)landlen;
  }
  else {
    // "land" is not a dimension; file is not compressed
    if ( (status = nc_inq_dimid(ncid, "x", &xdimid)) != NC_NOERR) {
      status = nc_inq_dimid(ncid, "lon", &xdimid); Handle_Error(status);
    }
    status = nc_inq_dimlen(ncid, xdimid, &xlen); Handle_Error(status);
    if ( (status = nc_inq_dimid(ncid, "y", &ydimid)) != NC_NOERR) {
      status = nc_inq_dimid(ncid, "lat", &ydimid); Handle_Error(status);
    }
    status = nc_inq_dimlen(ncid, ydimid, &ylen); Handle_Error(status);
    NROWS = (int)ylen;
    NCOLS = (int)xlen;
    // Set number of valid cells to 0 for now
    NCELLS = 0;
  }

  // Get number of vertical levels
  if ((status = nc_inq_dimid(ncid, "z", &zdimid)) == NC_NOERR
      || (status = nc_inq_dimid(ncid, "level", &zdimid)) == NC_NOERR
      || (status = nc_inq_dimid(ncid, "levsoi", &zdimid)) == NC_NOERR) {
    status = nc_inq_dimlen(ncid, zdimid, &zlen); Handle_Error(status);
    NLEVELS = (int)zlen;
  }
  else {
    NLEVELS = 1;
  }

  // Get number of records
  if ((status = nc_inq_dimid(ncid, "tstep", &tstepdimid)) == NC_NOERR
      || (status = nc_inq_dimid(ncid, "t", &tstepdimid)) == NC_NOERR
      || (status = nc_inq_dimid(ncid, "time", &tstepdimid)) == NC_NOERR
      || (status = nc_inq_dimid(ncid, "ntime", &tstepdimid)) == NC_NOERR) {
    status = nc_inq_dimlen(ncid, tstepdimid, &tsteplen); Handle_Error(status);
    NRECS = (int)tsteplen;
  }
  else {
    fprintf(stderr, "ERROR: no time dimension found\n");
    exit(-1);
  }

  // Close file
  status = nc_close(ncid); Handle_Error(status);

  // Save info for later
  dim_info->xdimid = xdimid;
  dim_info->xlen = xlen;
  dim_info->ydimid = ydimid;
  dim_info->ylen = ylen;
  dim_info->zdimid = zdimid;
  dim_info->zlen = zlen;
  dim_info->tstepdimid = tstepdimid;
  dim_info->tsteplen = tsteplen;
  dim_info->landdimid = landdimid;
  dim_info->landlen = landlen;

}

//*************************************************************************************************
// Read_Metadata: reads the header of the netcdf file and determines input data
// variables and attributes
//*************************************************************************************************
void Read_Metadata(char *infile, struct DimInfo dim_info, struct GridInfo *grid, float *levels, char *lev_units,
  char *lev_long_name, char *lev_positive, char **global_atts, struct tm *data_times,
  int *dtp, struct VarAtt *var_atts, struct OutputVar *outputVars, int *outputVarLen)
{

  int year, mon;
  int status;
  int ncid, timestepvarid, timevarid, landvarid, rowvarid, colvarid, latvarid, lonvarid, levvarid, cellidvarid, ndims;
  int i, j, v, g, k;
  long long t;
  char tempname[40];
  int *temp_array_int;
  long long *temp_timestep;
  float *temp_time;
  float *temp_array_float;
  int ncoord_var_names = 28;
  char *coord_var_names[] = {
    "row", "col", "lat", "lon", "nav_lat", "nav_lon", "land", "landmask", "cellid", "level", "levsoi", "time",
    "timestep", "timestp", "numlon", "longxy", "latixy", "area", "levlak", "landfrac", "mcdate", "mcsec",
    "mdcur", "mscur", "nstep", "time_bounds", "date_written", "time_written"
  };
  int data_var;
  char *origin_str, *origin_date_str, *origin_time_str;
  struct tm origin_time;
  char varlist[10000];
  char year_str[4],month_str[2];
  int orig_year, orig_mon, orig_day, orig_hr, orig_min, orig_sec;
  int found;
  int dimids[20];
  int dimlen1,dimlen2;
  long long dsec;
  char time_units[10];
  char time_units_str[50];

  // Allocate space for temp arrays
  if (COMPRESS) {
    temp_array_int = (int*)calloc(NCELLS,sizeof(int));
    temp_array_float = (float*)calloc(NCELLS,sizeof(float));
  }
  else {
    temp_array_int = (int*)calloc(NROWS*NCOLS,sizeof(int));
    temp_array_float = (float*)calloc(NROWS*NCOLS,sizeof(float));
  }
  temp_timestep = (long long *)calloc(NRECS,sizeof(long long));
  temp_time = (float*)calloc(NRECS,sizeof(float));
  origin_str = (char*)calloc(MAXSTRING,sizeof(char));
  origin_date_str = (char*)calloc(MAXSTRING,sizeof(char));
  origin_time_str = (char*)calloc(MAXSTRING,sizeof(char));

  // Initialize origin_time
  origin_time.tm_year = 0;
  origin_time.tm_mon = 0;
  origin_time.tm_mday = 0;
  origin_time.tm_hour = 0;
  origin_time.tm_min = 0;
  origin_time.tm_sec = 0;

  // Open netcdf file
  status = nc_open(infile, NC_NOWRITE, &ncid); Handle_Error(status);

  // Get time info

  // First look for dt
  if ((status = nc_inq_varid(ncid, "timestp", &timestepvarid)) != NC_NOERR
      && (status = nc_inq_varid(ncid, "timestep", &timestepvarid)) != NC_NOERR) {
    fprintf(stderr,"WARNING: can\'t get input dt; neither \"timestp\" nor \"timestep\" variables found\n");
//    fprintf(stderr,"Either add a \"timestep\" variable and include a \"tstep_sec\" attribute, or do\n");
//    fprintf(stderr,"not select the \"-t\" option when running this program.\n");
//    Handle_Error(status);
    fprintf(stderr,"setting input dt to 24h\n");
    *dtp = 86400;
    strcpy(time_units,"sec");
  }
  else {
    status = nc_get_att_int(ncid, timestepvarid, "tstep_sec", dtp); Handle_Error(status);
  }

  // Look for time units and check validity
  found = 0;
  if ((status = nc_inq_varid(ncid, "time", &timevarid)) == NC_NOERR) {
    if (status = nc_get_att_text(ncid, timevarid, "units", time_units_str) == NC_NOERR) {
      sscanf(time_units_str, "%s", time_units);
      if (!strcasecmp(time_units,"y") || !strcasecmp(time_units,"yr") || !strncasecmp(time_units,"year",4)) {
        sprintf(time_units,"year");
        found = 1;
      }
      else if (!strcasecmp(time_units,"m") || !strcasecmp(time_units,"mo") || !strncasecmp(time_units,"mon",3)) {
        sprintf(time_units,"month");
        found = 1;
      }
      else if (!strcasecmp(time_units,"d") || !strcasecmp(time_units,"dy") || !strncasecmp(time_units,"day",3)) {
        sprintf(time_units,"day");
        found = 1;
      }
      else if (!strcasecmp(time_units,"h") || !strcasecmp(time_units,"hr") || !strncasecmp(time_units,"hour",4)) {
        sprintf(time_units,"hour");
        found = 1;
      }
      else if (!strncasecmp(time_units,"min",3)) {
        sprintf(time_units,"min");
        found = 1;
      }
      else if (!strcasecmp(time_units,"s") || !strncasecmp(time_units,"sec",3)) {
        sprintf(time_units,"sec");
        found = 1;
      }
    }
  }
  if (!found) {
    if ((status = nc_inq_varid(ncid, "timestep", &timevarid)) == NC_NOERR
        || (status = nc_inq_varid(ncid, "timestp", &timevarid)) == NC_NOERR) {
      if (status = nc_get_att_text(ncid, timevarid, "units", time_units_str) == NC_NOERR) {
        sscanf(time_units_str, "%s", time_units);
        if (!strcasecmp(time_units,"y") || !strcasecmp(time_units,"yr") || !strncasecmp(time_units,"year",4)) {
          sprintf(time_units,"year");
          found = 1;
        }
        else if (!strcasecmp(time_units,"m") || !strcasecmp(time_units,"mo") || !strncasecmp(time_units,"mon",3)) {
          sprintf(time_units,"month");
          found = 1;
        }
        else if (!strcasecmp(time_units,"d") || !strcasecmp(time_units,"dy") || !strncasecmp(time_units,"day",3)) {
          sprintf(time_units,"day");
          found = 1;
        }
        else if (!strcasecmp(time_units,"h") || !strcasecmp(time_units,"hr") || !strncasecmp(time_units,"hour",4)) {
          sprintf(time_units,"hour");
          found = 1;
        }
        else if (!strncasecmp(time_units,"min",3)) {
          sprintf(time_units,"min");
          found = 1;
        }
        else if (!strcasecmp(time_units,"s") || !strncasecmp(time_units,"sec",3)) {
          sprintf(time_units,"sec");
          found = 1;
        }
      }
    }
  }
  if (!found) {
    fprintf(stderr, "Warning: no valid time units found; assuming seconds\n");
    strcpy(time_units, "sec");
  }

  // Look for origin date
  // First try global attributes
  if ( (status = nc_get_att_int(ncid, NC_GLOBAL, "Year", &orig_year)) == NC_NOERR
       && (status = nc_get_att_int(ncid, NC_GLOBAL, "Month", &orig_mon)) == NC_NOERR) {
    sprintf(origin_date_str,"%04d-%02d-01",orig_year,orig_mon);
    sprintf(origin_time_str,"00:00:00");
  }
  else if ( (status = nc_get_att_text(ncid, NC_GLOBAL, "time_origin", origin_str)) == NC_NOERR) {
    sscanf(origin_str,"%s %s",origin_date_str,origin_time_str);
  }
  // Next try attributes of time variables
  else {
    found = 0;
    if ((status = nc_inq_varid(ncid, "time", &timevarid)) == NC_NOERR) {
      if ((status = nc_get_att_text(ncid, timevarid, "time_origin", origin_str)) == NC_NOERR) {
        sscanf(origin_str,"%s %s",origin_date_str,origin_time_str);
	found = 1;
      }
      else if ((status = nc_get_att_text(ncid, timevarid, "origin", origin_str)) == NC_NOERR) {
        sscanf(origin_str,"%s %s",origin_date_str,origin_time_str);
	found = 1;
      }
    }
    if (! found ) {
      if ((status = nc_get_att_text(ncid, timestepvarid, "time_origin", origin_str)) == NC_NOERR) {
        sscanf(origin_str,"%s %s",origin_date_str,origin_time_str);
	found = 1;
      }
      else if ((status = nc_get_att_text(ncid, timestepvarid, "origin", origin_str)) == NC_NOERR) {
        sscanf(origin_str,"%s %s",origin_date_str,origin_time_str);
	found = 1;
      }
    }
    if (! found) {
      fprintf(stderr,"ERROR: can\'t get time origin; neither \"time_origin\" nor \"origin\" attributes found, either as global attributes or as attributes of \"time\" or \"timestep\" variables.\n");
      exit(1);
    }
  }
  Date_2_TM(origin_date_str,&origin_time);
  Time_2_TM(origin_time_str,&origin_time);

  // Compute times of records
  data_times[0].tm_year = origin_time.tm_year;
  data_times[0].tm_mon = origin_time.tm_mon;
  data_times[0].tm_mday = origin_time.tm_mday;
  data_times[0].tm_hour = origin_time.tm_hour;
  data_times[0].tm_min = origin_time.tm_min;
  data_times[0].tm_sec = origin_time.tm_sec;
  for (t=1; t<NRECS; t++) {
    dsec = dt2sec(data_times[t-1], *dtp, time_units);
    add_sec_date(data_times[t-1], dsec, &(data_times[t]));
  }

  // Get levels
  if ((status = nc_inq_varid(ncid, "level", &levvarid)) == NC_NOERR
      || (status = nc_inq_varid(ncid, "levsoi", &levvarid)) == NC_NOERR) {
    status = nc_get_att_text(ncid, levvarid, "units", lev_units);
    status = nc_get_att_text(ncid, levvarid, "long_name", lev_long_name);
    status = nc_get_att_text(ncid, levvarid, "positive", lev_positive);
    status = nc_get_var_float(ncid, levvarid, levels);
  }
  else {
    sprintf(lev_units,"m");
    sprintf(lev_long_name,"Vertical Level");
    sprintf(lev_positive,"up from surface");
    levels[0] = 0;
  }

  // Get landmask (& calculate NCELLS if necessary)
  if ((status = nc_inq_varid(ncid, "land", &landvarid)) == NC_NOERR
      || (status = nc_inq_varid(ncid, "nland", &landvarid)) == NC_NOERR
      || (status = nc_inq_varid(ncid, "landmask", &landvarid)) == NC_NOERR) {
    status = nc_get_var_int(ncid, landvarid, temp_array_int); Handle_Error(status);
  }
  if (COMPRESS) {
    for (k=0; k<NCELLS; k++) {
      grid[k].landmask = temp_array_int[k];
    }
  }
  else {
    // Copy temp_array_int to landmask and
    // compute number of valid cells while we're at it
    k = 0;
    for (g=0; g<NROWS*NCOLS; g++) {
      if (temp_array_int[g] > 0) {
        grid[k].landmask = g;
        k++;
      }
    }
    NCELLS = k;
  }

  // Get row/col
  status = nc_inq_varid(ncid, "row", &rowvarid);
  if (status == NC_NOERR) {
    GRIDFILE = 1; // If "row" is present, we'll create a grid file
    status = nc_get_var_int(ncid, rowvarid, temp_array_int); Handle_Error(status);
    if (COMPRESS) {
      // Copy temp_array_int to row
      for (k=0; k<NCELLS; k++) {
        grid[k].row = temp_array_int[k];
      }
    }
    else {
      // Compress temp_array_int into row
      k=0;
      for (g=0; g<NROWS*NCOLS; g++) {
        if (grid[k].landmask == g) {
          grid[k].row = temp_array_int[g];
          k++;
        }
      }
    }
    status = nc_inq_varid(ncid, "col", &colvarid); Handle_Error(status);
    status = nc_get_var_int(ncid, colvarid, temp_array_int); Handle_Error(status);
    if (COMPRESS) {
      // Copy temp_array_int to col
      for (k=0; k<NCELLS; k++) {
        grid[k].col = temp_array_int[k];
      }
    }
    else {
      // Compress temp_array_int into col
      k=0;
      for (g=0; g<NROWS*NCOLS; g++) {
        if (grid[k].landmask == g) {
          grid[k].col = temp_array_int[g];
          k++;
        }
      }
    }
  }
  else {
    GRIDFILE = 0;
  }

  // Get lat/lon
  latvarid = -1;
  if ((status = nc_inq_varid(ncid, "nav_lat", &latvarid)) == NC_NOERR) {
    status = nc_inq_varndims(ncid, latvarid, &ndims);
    status = nc_inq_vardimid(ncid, latvarid, dimids);
    if (COMPRESS && ndims == 1) {
      status = nc_inq_dimlen(ncid, dimids[0], &dimlen1);
      if (dimlen1 != dim_info.landlen) {
        latvarid = -1;
      }
    }
    else if (ndims == 2) {
      status = nc_inq_dimlen(ncid, dimids[0], &dimlen1);
      status = nc_inq_dimlen(ncid, dimids[1], &dimlen2);
      if (dimlen1*dimlen2 != dim_info.xlen*dim_info.ylen) {
        latvarid = -1;
      }
    }
    else {
      latvarid = -1;
    }
  }
  if (latvarid < 0) {
    if ((status = nc_inq_varid(ncid, "latixy", &latvarid)) == NC_NOERR) {
      status = nc_inq_varndims(ncid, latvarid, &ndims);
      status = nc_inq_vardimid(ncid, latvarid, dimids);
      if (COMPRESS && ndims == 1) {
        status = nc_inq_dimlen(ncid, dimids[0], &dimlen1);
        if (dimlen1 != dim_info.landlen) {
          latvarid = -1;
        }
      }
      else if (ndims == 2) {
        status = nc_inq_dimlen(ncid, dimids[0], &dimlen1);
        status = nc_inq_dimlen(ncid, dimids[1], &dimlen2);
        if (dimlen1*dimlen2 != dim_info.xlen*dim_info.ylen) {
          latvarid = -1;
        }
      }
      else {
        latvarid = -1;
      }
    }
  }
  if (latvarid < 0) {
    if ((status = nc_inq_varid(ncid, "lat", &latvarid)) == NC_NOERR) {
      status = nc_inq_varndims(ncid, latvarid, &ndims);
      status = nc_inq_vardimid(ncid, latvarid, dimids);
      if (COMPRESS && ndims == 1) {
        status = nc_inq_dimlen(ncid, dimids[0], &dimlen1);
        if (dimlen1 != dim_info.landlen) {
          latvarid = -1;
        }
      }
      else if (ndims == 2) {
        status = nc_inq_dimlen(ncid, dimids[0], &dimlen1);
        status = nc_inq_dimlen(ncid, dimids[1], &dimlen2);
        if (dimlen1*dimlen2 != dim_info.xlen*dim_info.ylen) {
          latvarid = -1;
        }
      }
      else {
        latvarid = -1;
      }
    }
  }
  if (latvarid < 0) {
    fprintf(stderr,"ERROR: can\'t find \"nav_lat\", \"latixy\", or \"lat\"\n");
    exit(-1);
  }
  status = nc_get_var_float(ncid, latvarid, temp_array_float); Handle_Error(status);
  if (COMPRESS) {
    // Copy temp_array_float to lat
    for (k=0; k<NCELLS; k++) {
      grid[k].lat = temp_array_float[k];
    }
  }
  else {
    // Compress temp_array_float into lat
    k=0;
    for (g=0; g<NROWS*NCOLS; g++) {
      if (grid[k].landmask == g) {
        grid[k].lat = temp_array_float[g];
        k++;
      }
    }
  }
  lonvarid = -1;
  if ((status = nc_inq_varid(ncid, "nav_lon", &lonvarid)) == NC_NOERR) {
    status = nc_inq_varndims(ncid, lonvarid, &ndims);
    status = nc_inq_vardimid(ncid, lonvarid, dimids);
    if (COMPRESS && ndims == 1) {
      status = nc_inq_dimlen(ncid, dimids[0], &dimlen1);
      if (dimlen1 != dim_info.landlen) {
        lonvarid = -1;
      }
    }
    else if (ndims == 2) {
      status = nc_inq_dimlen(ncid, dimids[0], &dimlen1);
      status = nc_inq_dimlen(ncid, dimids[1], &dimlen2);
      if (dimlen1*dimlen2 != dim_info.xlen*dim_info.ylen) {
        lonvarid = -1;
      }
    }
    else {
      lonvarid = -1;
    }
  }
  if (lonvarid < 0) {
    if ((status = nc_inq_varid(ncid, "longxy", &lonvarid)) == NC_NOERR) {
      status = nc_inq_varndims(ncid, lonvarid, &ndims);
      status = nc_inq_vardimid(ncid, lonvarid, dimids);
      if (COMPRESS && ndims == 1) {
        status = nc_inq_dimlen(ncid, dimids[0], &dimlen1);
        if (dimlen1 != dim_info.landlen) {
          lonvarid = -1;
        }
      }
      else if (ndims == 2) {
        status = nc_inq_dimlen(ncid, dimids[0], &dimlen1);
        status = nc_inq_dimlen(ncid, dimids[1], &dimlen2);
        if (dimlen1*dimlen2 != dim_info.xlen*dim_info.ylen) {
          lonvarid = -1;
        }
      }
      else {
        lonvarid = -1;
      }
    }
  }
  if (lonvarid < 0) {
    if ((status = nc_inq_varid(ncid, "lon", &lonvarid)) == NC_NOERR) {
      status = nc_inq_varndims(ncid, lonvarid, &ndims);
      status = nc_inq_vardimid(ncid, lonvarid, dimids);
      if (COMPRESS && ndims == 1) {
        status = nc_inq_dimlen(ncid, dimids[0], &dimlen1);
        if (dimlen1 != dim_info.landlen) {
          lonvarid = -1;
        }
      }
      else if (ndims == 2) {
        status = nc_inq_dimlen(ncid, dimids[0], &dimlen1);
        status = nc_inq_dimlen(ncid, dimids[1], &dimlen2);
        if (dimlen1*dimlen2 != dim_info.xlen*dim_info.ylen) {
          lonvarid = -1;
        }
      }
      else {
        lonvarid = -1;
      }
    }
  }
  if (lonvarid < 0) {
    fprintf(stderr,"ERROR: can\'t find \"nav_lon\", \"longxy\", or \"lon\"\n");
    exit(-1);
  }
  status = nc_get_var_float(ncid, lonvarid, temp_array_float); Handle_Error(status);
  if (COMPRESS) {
    // Copy temp_array_float to lon
    for (k=0; k<NCELLS; k++) {
      grid[k].lon = temp_array_float[k];
    }
  }
  else {
    // Compress temp_array_float into lon
    k=0;
    for (g=0; g<NROWS*NCOLS; g++) {
      if (grid[k].landmask == g) {
        grid[k].lon = temp_array_float[g];
        k++;
      }
    }
  }

  if (GRIDFILE) {
    // Compute min/max row/col
    ROWMIN = grid[0].row;
    ROWMAX = grid[0].row;
    COLMIN = grid[0].col;
    COLMAX = grid[0].col;
    for (k=1; k<NCELLS; k++) {
      if (grid[k].row < ROWMIN) ROWMIN = grid[k].row;
      if (grid[k].row > ROWMAX) ROWMAX = grid[k].row;
      if (grid[k].col < COLMIN) COLMIN = grid[k].col;
      if (grid[k].col > COLMAX) COLMAX = grid[k].col;
    }
  }

  if (GRIDFILE) {
    // Get cellid
    if ((status = nc_inq_varid(ncid, "CellID", &cellidvarid)) == NC_NOERR
        || (status = nc_inq_varid(ncid, "cellid", &cellidvarid)) == NC_NOERR) {
      status = nc_get_var_int(ncid, cellidvarid, temp_array_int); Handle_Error(status);
      if (COMPRESS) {
        // Copy temp_array_int to cellid
        for (k=0; k<NCELLS; k++) {
          grid[k].cellid = temp_array_int[k];
        }
      }
      else {
        // Compress temp_array_int into cellid
        k=0;
        for (g=0; g<NROWS*NCOLS; g++) {
          if (grid[k].landmask == g) {
            grid[k].cellid = temp_array_int[g];
            k++;
          }
        }
      }
    }
    else {
      // CellID not stored in netcdf file; generate it from array index
      for (k=0; k<NCELLS; k++) {
        grid[k].cellid = k+1;
      }
    }
  }

  // Get global attributes
//  status = nc_get_att_text(ncid, NC_GLOBAL, "institution", global_atts[0]);
//  status = nc_get_att_text(ncid, NC_GLOBAL, "sources", global_atts[1]);
//  status = nc_get_att_text(ncid, NC_GLOBAL, "production", global_atts[2]);
//  status = nc_get_att_text(ncid, NC_GLOBAL, "history", global_atts[3]);
//  status = nc_get_att_text(ncid, NC_GLOBAL, "projection", global_atts[4]);
//  status = nc_get_att_text(ncid, NC_GLOBAL, "SurfSgn_convention", global_atts[5]);

  // Get names and attributes of other variables
  v = 0;
  NUM3d = 0;
  NUM4d = 0;
  for (i=0; i<MAXVAR*2; i++) {
    if ( (status = nc_inq_varname(ncid, i, tempname)) != NC_NOERR ) {
      break;
    }
    // Filter out coordinate variables
    data_var = 1;
    for (j=0; j<ncoord_var_names; j++) {
      if (!strcasecmp(tempname,coord_var_names[j])) {
        data_var = 0;
      }
    }
    if (data_var) {
      if (!VARLIST_SPECIFIED) {
        if (v == 0) {
          strcpy(varlist,tempname);
        }
        else {
          strcat(varlist,",");
          strcat(varlist,tempname);
        }
      }
      sprintf(var_atts[v].name,"%s",tempname);
//fprintf(stderr,"%s\n",var_atts[v].name);
      if ((status = nc_get_att_text(ncid, i, "units", var_atts[v].units)) != NC_NOERR) {
        strcpy(var_atts[v].units,"-");
      }
      if ((status = nc_get_att_text(ncid, i, "long_name", var_atts[v].long_name)) != NC_NOERR) {
        strcpy(var_atts[v].long_name,"-");
      }
      status = nc_inq_varndims(ncid, i, &ndims); Handle_Error(status);
//fprintf(stderr,"ndims: %d\n",ndims);
      var_atts[v].id = i;
      if (COMPRESS) {
        if (ndims >= 3) {
          strcpy(var_atts[v].z_dep,"TRUE");
          NUM4d++;
        }
        else {
          strcpy(var_atts[v].z_dep,"FALSE");
          NUM3d++;
        }
      }
      else {
        if (ndims >= 4) {
          strcpy(var_atts[v].z_dep,"TRUE");
          NUM4d++;
        }
        else {
          strcpy(var_atts[v].z_dep,"FALSE");
          NUM3d++;
        }
      }
      v++;
    }
  }

  // Build list of output variables, if not specified on cmdline
  if (!VARLIST_SPECIFIED) {
    *outputVarLen = Handle_V_Option(outputVars, varlist);
  }

  // Close file
  status = nc_close(ncid); Handle_Error(status);

  // Free allocated space
  free(temp_array_int);
  free(temp_array_float);
  free(temp_timestep);
  free(temp_time);
  free(origin_str);
  free(origin_date_str);
  free(origin_time_str);

}


//*************************************************************************************************
//  Write_Metadata: writes metadata to metadata file
//*************************************************************************************************
void Write_Metadata(char *metafile, char **global_atts, struct tm *data_times,
  int dt, struct VarAtt *var_atts, struct OutputVar *outputVars, int outputVarLen) {

  FILE *mf;
  int timestep;
  char *start_datetime_str, *end_datetime_str;
  char *linestr, *optstr;
  char *file_start_date_str, *file_start_time_str;
  char *file_end_date_str, *file_end_time_str;
  char *file_start_datetime_str, *file_end_datetime_str;
  int file_dt;
  int v;
  int ov;

  linestr = (char *)calloc(MAXSTRING,sizeof(char));
  optstr = (char *)calloc(MAXSTRING,sizeof(char));
  start_datetime_str = (char *)calloc(20,sizeof(char));
  end_datetime_str = (char *)calloc(20,sizeof(char));
  file_start_date_str = (char *)calloc(20,sizeof(char));
  file_start_time_str = (char *)calloc(20,sizeof(char));
  file_end_date_str = (char *)calloc(20,sizeof(char));
  file_end_time_str = (char *)calloc(20,sizeof(char));
  file_start_datetime_str = (char *)calloc(20,sizeof(char));
  file_end_datetime_str = (char *)calloc(20,sizeof(char));

  // Set up time info
  timestep = dt/3600;
  sprintf(start_datetime_str,"%04d-%02d-%02d %02d:%02d:%02d",
    data_times[0].tm_year+1900,data_times[0].tm_mon+1,
    data_times[0].tm_mday,data_times[0].tm_hour,
    data_times[0].tm_min,data_times[0].tm_sec);
  sprintf(end_datetime_str,"%04d-%02d-%02d %02d:%02d:%02d",
    data_times[NRECS-1].tm_year+1900,data_times[NRECS-1].tm_mon+1,
    data_times[NRECS-1].tm_mday,data_times[NRECS-1].tm_hour,
    data_times[NRECS-1].tm_min,data_times[NRECS-1].tm_sec);

  // If we're appending, first check for an existing metadata file,
  // validate its start/end times and timestep length,
  // and replace our current start time with its start time.
  if (APPEND) {

    // Open metadata file for reading
    if((mf = fopen (metafile, "r")) == NULL) {
      fprintf(stderr, "Error opening %s\n", metafile);
      exit(0);
    }

    // Get start/end times and time step length
    fgets(linestr,MAXSTRING,mf);
    while (!feof(mf)) {
      if (linestr[0]!='#' && linestr[0]!='\n' && linestr[0]!='\0') {

        sscanf(linestr,"%s",optstr);

        if (strcasecmp("START_TIME",optstr)==0) {
          sscanf(linestr,"%*s %s %s",file_start_date_str,file_start_time_str);
        }
        else if (strcasecmp("END_TIME",optstr)==0) {
          sscanf(linestr,"%*s %s %s",file_end_date_str,file_end_time_str);
        }
        else if (strcasecmp("TIME_STEP",optstr)==0) {
          sscanf(linestr,"%*s %d",&file_dt);
        }

      }
      fgets(linestr,MAXSTRING,mf);
    }

    fclose(mf);

//    // Validate metadata file's time info
//    sprintf(file_start_datetime_str,"%s %s",file_start_date_str,file_start_time_str);
//    sprintf(file_end_datetime_str,"%s %s",file_end_date_str,file_end_time_str);
//    if (strcmp(file_start_datetime_str,start_datetime_str) > 0) {
//      fprintf(stderr, "ERROR: data start time from previous metadata file (%s) is LATER than start time of current data (%s); cannot append current data to previous data\n",file_start_datetime_str,start_datetime_str);
//      exit(1);
//    }
//    else if (strcmp(file_end_datetime_str,start_datetime_str) > 0) {
//      fprintf(stderr, "ERROR: data end time from previous metadata file (%s) is LATER than start time of current data (%s); cannot append current data to previous data\n",file_end_datetime_str,start_datetime_str);
//      exit(1);
//    }
//    else if (file_dt != timestep) {
//      fprintf(stderr, "ERROR: time step length from previous metadata file (%d) does not equal time step length of current data (%d); cannot append current data to previous data\n",file_dt, dt);
//      exit(1);
//    }

    // Assuming metadata file's time info is valid, use start time from the metadata file
    // instead of start time of current data
    strcpy(start_datetime_str,file_start_datetime_str);

  }


  // Open metadata file for writing
  if((mf = fopen (metafile, "w")) == NULL) {
    fprintf(stderr, "Error opening %s\n", metafile);
    exit(0);
  }

  // Describe global attributes
  fprintf(mf,"# This file contains metadata for the\n");
  fprintf(mf,"# VIC-format data files\n");
  fprintf(mf,"#--------------------------------------------\n");
  fprintf(mf,"# Global Attributes\n");
  fprintf(mf,"#--------------------------------------------\n");
  fprintf(mf,"INSTITUTION\t\t%s\n",global_atts[0]);
  fprintf(mf,"SOURCES\t\t\t%s\n",global_atts[1]);
  fprintf(mf,"PRODUCTION\t\t%s\n",global_atts[2]);
  fprintf(mf,"HISTORY\t\t\t%s\n",global_atts[3]);
  fprintf(mf,"PROJECTION\t\t%s\n",global_atts[4]);
  fprintf(mf,"SURFSGNCONVENTION\t%s\n",global_atts[5]);

  // Describe data dimensions
  fprintf(mf,"\n");
  fprintf(mf,"#--------------------------------------------\n");
  fprintf(mf,"# Dimensions\n");
  fprintf(mf,"#--------------------------------------------\n");
  fprintf(mf,"# Time\n");
  fprintf(mf,"START_TIME\t%s\n",start_datetime_str);
  fprintf(mf,"END_TIME\t%s\n",end_datetime_str);
  fprintf(mf,"TIME_STEP\t%d\n",timestep);
  fprintf(mf,"TIME_UNITS\thours\n");
  fprintf(mf,"# Levels (Z-axis)\n");
  fprintf(mf,"NLEVELS\t%d\n",NLEVELS);

  // Describe data variables
  fprintf(mf,"\n");
  fprintf(mf,"#--------------------------------------------\n");
  fprintf(mf,"# Variables\n");
  fprintf(mf,"#--------------------------------------------\n");
  fprintf(mf,"FORMAT\t%s\n",FORMAT);
  fprintf(mf,"# Read	Name           	Units           Z-Dep?  Description\n");
  for (ov=0;ov<outputVarLen;ov++) {

    // find the var_atts we are looking for
    for (v=0; v<(NUM3d+NUM4d); v++) {

      if (!strcasecmp(outputVars[ov].name, var_atts[v].name)) {
        fprintf(mf,"TRUE\t%-15.15s\t%-15.15s %-14.14s %-40.40s\n", var_atts[v].name,
          var_atts[v].units, var_atts[v].z_dep, var_atts[v].long_name);
        break;
      }

    }
  }

  // Close metadata file
  fclose(mf);

  // Free allocated space
  free(linestr);
  free(optstr);
  free(start_datetime_str);
  free(end_datetime_str);
  free(file_start_date_str);
  free(file_start_time_str);
  free(file_end_date_str);
  free(file_end_time_str);
  free(file_start_datetime_str);
  free(file_end_datetime_str);

}


//*************************************************************************************************
//  Write_Gridfile: writes grid info to grid file
//*************************************************************************************************
void Write_Gridfile(char *gridfile, struct GridInfo *grid) {

  FILE *gf;
  int i, j, k;

  // Open grid file
  gf = safefopen(gridfile, "w");

  // Write out each cell's row, col, lat, and lon
  for (k=0; k<NCELLS; k++) {
    fprintf(gf,"%d %d %d %f %f\n",grid[k].cellid,grid[k].row,grid[k].col,grid[k].lat,grid[k].lon);
  }

  // Close grid file
  safefclose(gf);

  return;

}


//*************************************************************************************************
// Check_VIC_Files: opens VIC output files and builds array of filehandles
//*************************************************************************************************
void Check_VIC_Files(char *outpath, char *prefix, struct GridInfo *grid, FILE **outfilehandle,
  int  startHandle, int fileBufferLength)
{

  int i,j,k,g;
  char outfile[MAXSTRING];

  // Loop over grid cells
  for (k=0; k<fileBufferLength; k++) {

    // Build output filename
    sprintf(outfile, "%s/%s_%.4f_%.4f", outpath, prefix, grid[startHandle+k].lat, grid[startHandle+k].lon);

    // Open file
    if (APPEND) {
      if((outfilehandle[k] = fopen (outfile, "a")) == NULL) {
        fprintf(stderr, "Error opening %s\n", outfile);
        exit(-1);
      }
    }
    else {
      if((outfilehandle[k] = fopen (outfile, "w")) == NULL) {
        fprintf(stderr, "Error opening %s\n", outfile);
        exit(-1);
      }
    }

  }

}


//*************************************************************************************************
// Read_NetCDF: reads NetCDF files
//   This function gets called within a loop that iterates over each Rec.
//*************************************************************************************************
void Read_NetCDF(char *infile, struct GridInfo *grid, struct VarAtt *var_atts, struct OutputVar* outputVars,
  int outputVarLen, int timestep, float **var3d, float ***var4d, int start, int length)
{

  int status;
  int ncid, tstepdimid;
  size_t tsteplen;
  int g, v, k, l;
  int varid, ov, isValid;
  float *temp3d, *temp4d;
  int count, count3, count4;
  size_t start3d_cmp[2], count3d_cmp[2], start4d_cmp[3], count4d_cmp[3];
  size_t start3d[3], count3d[3], start4d[4], count4d[4];
  size_t tmpCount = -1;
  size_t tmpStart = -1;

  // Open netcdf file
  status =  nc_open(infile, NC_NOWRITE, &ncid); Handle_Error(status);

  // Get number of records in file
  status = nc_inq_unlimdim(ncid, &tstepdimid);
  if (status != NC_NOERR || tstepdimid < 0) {
    status = nc_inq_dimid(ncid, "tstep", &tstepdimid); Handle_Error(status);
  }
  status = nc_inq_dimlen(ncid, tstepdimid, &tsteplen); Handle_Error(status);
  NRECS = (int)tsteplen;

  // Allocate temp arrays
  temp3d = (float*)calloc(NCELLS*NRECS,sizeof(float));
  temp4d = (float*)calloc(NCELLS*NLEVELS*NRECS,sizeof(float));

  // Array dimensions
  start3d_cmp[0] = timestep;
  start3d_cmp[1] = 0;
  count3d_cmp[0] = 1;
  count3d_cmp[1] = NCELLS;
  start4d_cmp[0] = timestep;
  start4d_cmp[1] = 0;
  start4d_cmp[2] = 0;
  count4d_cmp[0] = 1;
  count4d_cmp[1] = NLEVELS;
  count4d_cmp[2] = NCELLS;
  start3d[0] = timestep;
  start3d[1] = 0;
  start3d[2] = 0;
  count3d[0] = 1;
  count3d[1] = NROWS;
  count3d[2] = NCOLS;
  start4d[0] = timestep;
  start4d[1] = 0;
  start4d[2] = 0;
  start4d[3] = 0;
  count4d[0] = 1;
  count4d[1] = NLEVELS;
  count4d[2] = NROWS;
  count4d[3] = NCOLS;

  // Read variables

  /* iterate over the output variables */
  for (ov=0;ov<outputVarLen;ov++) {

    // find the var_atts we are looking for
    isValid = FALSE;
    count3 = count4 = -1; /* Must be initialized to -1 cause we will icrement it to 0 */
    for (v=0; v<(NUM3d+NUM4d); v++) {

      if (!strcasecmp(var_atts[v].z_dep,"FALSE")) {
        count3++;
      }
      else {
        count4++;
      }

      if (!strcasecmp(outputVars[ov].name, var_atts[v].name)) {
        isValid = TRUE;
        break;
      }

    }

    // if we didn't find it, we've got an error!
    if (isValid == FALSE) {
      fprintln(stderr, "Unable to locate variable %s in NetCDF file. Exiting", outputVars[ov].name);
      exit(1);
    }

    if (COMPRESS) {
      // Compressed data is fine as it is (since we're storing it compressed anyway);
      // just loop over valid cells
      if (!strcasecmp(var_atts[v].z_dep,"FALSE")) {
        status = nc_get_vara_float(ncid, var_atts[v].id, start3d_cmp, count3d_cmp, temp3d); Handle_Error(status);
        count = start;
        for (k=start; k<start+length; k++) {
          var3d[count3][k] = temp3d[count++];
        }
      }
      else {
        status = nc_get_vara_float(ncid, var_atts[v].id, start4d_cmp, count4d_cmp, temp4d); Handle_Error(status);
        for (l=0; l<NLEVELS; l++) {
          count = l*NCELLS+start;
          for (k=start; k<start+length; k++) {
            var4d[count4][k][l] = temp4d[count++];
          }
        }
      }
    }
    else {
      // Uncompressed data needs to be compressed to fit in our array;
      // Filter out invalid cells
      if (!strcasecmp(var_atts[v].z_dep,"FALSE")) {
        status = nc_get_vara_float(ncid, var_atts[v].id, start3d, count3d, temp3d); Handle_Error(status);
        for (k=start; k<start+length; k++) {
          var3d[count3][k] = temp3d[grid[k].landmask];
        }
      }
      else {
        status = nc_get_vara_float(ncid, var_atts[v].id, start4d, count4d, temp4d); Handle_Error(status);
        for (l=0; l<NLEVELS; l++) {
          for (k=start; k<start+length; k++) {
            var4d[count4][k][l] = temp4d[l*NROWS*NCOLS+grid[k].landmask];
          }
        }
      }
    }

  }

  status = nc_close(ncid); Handle_Error(status);

  // Free allocated space
  free(temp3d);
  free(temp4d);

}


//*************************************************************************************************
// Write_VIC: writes to VIC-format files
//*************************************************************************************************
void Write_VIC(FILE **outfilehandle, struct VarAtt *var_atts, float **var3d, float ***var4d,
  struct tm *data_times, int rec, struct OutputVar* outputVars, int outputVarLen, int startCell, int numCells2Spool)
{

  int k, t, v, l, ov;
  int count3, count4;
  int count;
  struct VarAtt toPrint;
  int isValid = FALSE;
  int isZDep = FALSE;
  char* format = ASCII_FLOAT_FORMAT;
  int spooled = 0;
  int fileIdx = 0;

  if (!strcmp(FORMAT,"SCIENTIFIC")) {
    format = SCIENTIFIC_FLOAT_FORMAT;
  }

  if (numCells2Spool < 1 ) {
    fprintln(stderr, "ERROR: nc2vic.Write_VIC(): numCells2Spool must be positive. Found %d", numCells2Spool);
    exit(1);
  }

  if (numCells2Spool > NCELLS) {
    fprintln(stderr, "ERROR: nc2vic.Write_VIC(): numCells2Spool cannot exceed NCELLS. Found %d", numCells2Spool);
    exit(1);
  }

  // Loop over valid grid cells
  for (k=startCell; k<startCell+numCells2Spool; k++) {

    fileIdx=k-startCell;

    // Write to output file
    if (PRINT_REC_TIME) {
      fprintf(outfilehandle[fileIdx],"%04d\t%02d\t%02d\t%02d\t",
        data_times[rec].tm_year+1900,data_times[rec].tm_mon+1,
        data_times[rec].tm_mday,data_times[rec].tm_hour);
      }

    /* iterate over the output variables */
    // BEGIN
    for (ov=0;ov<outputVarLen;ov++) {

      isValid = FALSE;
      count3 = count4 = -1; /* Must be initialized to -1 cause we will icrement it to 0 */

      // find the var_atts we are looking for
      for (v=0; v<(NUM3d+NUM4d); v++) {

        // if the variable is not Z dependent
        if (!strcasecmp(var_atts[v].z_dep,"FALSE")) {
          isZDep = FALSE;
          count3++;
        }
        else {
          isZDep = TRUE;
          count4++;
        }

        if (!strcasecmp(outputVars[ov].name, var_atts[v].name)) {
          toPrint = var_atts[v];
          isValid = TRUE;
          break;
        }

      }

      // if we didn't find it, we've got an error!
      if (isValid == FALSE) {
        fprintln(stderr, "Unable to locate variable %s in NetCDF file. Exiting", outputVars[ov].name);
        exit(1);
      }

      // spool 3d or 4d data
      if (!isZDep) {
        fprintf(outfilehandle[fileIdx], format, var3d[count3][k]);
      }
      else {
        for (l=0; l<NLEVELS; l++) {
          fprintf(outfilehandle[fileIdx], format, var4d[count4][k][l]);
        }
      }
    } // END

    fprintln(outfilehandle[fileIdx],"");
    spooled++;

  }
  return;

}



//*************************************************************************************************
// Close_VIC_Files: closes VIC-format files
//*************************************************************************************************
void Close_VIC_Files(FILE **outfilehandle, int length)
{

  int k;

  for (k=0; k<length; k++) {
    safefclose(outfilehandle[k]);
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


/**
 * Appends an OutputVar to an Array.
 * @param max the maximum number of OutputVars
 * @param size the current size
 * @param vars the count of OutputVar
 * @param newVar the OutputVar to add
 * @return the current number size of vars
 **/
void appendOutputVariable(int* pSize, struct OutputVar* outputVars, char* name) {
        int i=0;
        int* tmp=NULL;
        char* cpyName=NULL;

        if (*pSize > MAXVAR) {
                fprintln(stderr,
                        "ERROR: Maximum number of output variables exceeded. Maximum is %d",
                        MAXVAR);
                exit(0);
        }

        if ((cpyName = (char*)malloc((strlen(name)+1)*( sizeof(char)))) == NULL) {
                fprintln(stderr,
                        "ERROR: Unable to allocate memory for output variable name.");
                exit(0);
        }

        strcpy(cpyName,name);
        /** Add code to handle the position here */
        outputVars[(*pSize)].name = cpyName;
        (*pSize)++;
        outputVars[(*pSize)].position = (*pSize);

        return ;
}

/**
 * Tokenizes the request parameter and stores them as an array in outputVars
 * Returns the length of the array.
 */
int Handle_V_Option(struct OutputVar* outputVars,  char* optarg) {
        int size=0;
        char* value;
        char* varNames;
        char* p4strTok_r;

        int len = strlen(optarg)+1;


        varNames = (char*)malloc(len * sizeof(char));
        value = (char*)malloc(len * sizeof(char));


        strcpy(varNames, optarg);

        /*
         * Tokenize a comma separated string
         */
        value = strtok_r(varNames, ",",&p4strTok_r);
        while (value!=NULL) {
                appendOutputVariable(&size, outputVars, value);
                if (DEBUG) {
                        fprintln(stdout, "Adding output variable '%s'.", value);
                }
                value=strtok_r(NULL, ",",&p4strTok_r);
        }


        free(value);
        free(varNames);

        return size;
}

/**
 * returns true if we are to output this variable
 */
int isPrintableVariable(struct VarAtt* var_atts, struct OutputVar* outputVars, int length) {
        int ret = TRUE;
        int i=0;
        if (outputVars != NULL) {
                ret = FALSE;
                for (i=0;i<length;i++) {
                        if (!strcasecmp(outputVars[i].name, var_atts->name)) {
                                ret = TRUE;
                                outputVars[i].used=TRUE;
                                break;
                        }
                }
        }
        return ret;
}

