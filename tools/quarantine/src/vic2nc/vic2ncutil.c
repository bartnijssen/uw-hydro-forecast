#include <stdio.h>
#include <time.h>
#include "vic2ncutil.h"
#include "netcdfconvertion.h"

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
  fprintf(stderr,"    29 during leap years, but does NOT write Feb 29 to the output files.  This option does\n");
  fprintf(stderr,"    not take effect if no timespan has been selected.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"  -L\n");
  fprintf(stderr,"    (Optional) If specified, this option assumes that the input files do NOT contain February\n");
  fprintf(stderr,"    29 during leap years, and does NOT write Feb 29 to the output files.  This option does\n");
  fprintf(stderr,"    not take effect if no timespan has been selected.\n");
  fprintf(stderr,"\n");
  fprintf(stderr,"  -n\n");
  fprintf(stderr,"    (Optional) If specified, the temporary file is preserved\n");
  fprintf(stderr,"\n");
}

int init3DFloat(float** var3d, int numX, int numY, float value) {
	int ret = FALSE;
	int i, j;
	
    for(i=0; i<numX; i++) {
        for(j=0; j<numY; j++) {
          var3d[i][j] = value;
        }
    }
    ret = TRUE;  
    return ret;
}

int init4DFloat(float*** var4d, int numX, int numY, int numZ, float value) {
	 int ret = FALSE;
	 int i = 0;

     for (i=0; i<numX; i++) {
     	ret = init3DFloat(var4d[i], numY, numZ, value);
     }
      
  	 return ret;
}


/**
 * Converts a Duration to miliseconds
 * @param pDuration pointer to the duration to calculate
 * @param pD pointer to a double to store the duration. If this value is nagative, the start is after the end.
 * @return 0 upon sucess
 */ 
int durationInMillis(struct Duration* pDuration, double* pD) {
	int ret = -1;
	long diff = -1;
	if (pDuration != NULL) {
		if ( ((long)pDuration->start >= 0) && ((long)pDuration->end) >= 0) {
			diff = (long)(pDuration->end - pDuration->start);
			/* diff is now in weird units (CLOCKS_PER_SEC*sec)*/
			*pD = 1000.0 * (double)diff / ((double)CLOCKS_PER_SEC);
			ret = 0;
		}		
	}
	return ret;
}


/**
 * Initializes a Duration
 * @param pDutation a pointer to the duration to initialize
 * @return 0 if sucessful. A non-zero return indicates a NULL pointer
 */ 
int initDuration(struct Duration* pDuration) {
	int ret = -1;
	clock_t start = -1;
	if (pDuration!=NULL) {
		pDuration->start = clock();
		pDuration->end = (clock_t)-1;
		ret = 0;
	}
	return ret;
}
