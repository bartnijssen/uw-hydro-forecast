#ifndef NETCDFCONVERTION_H_
#define NETCDFCONVERTION_H_

#endif /*NETCDFCONVERTION_H_*/

#define NODATA_INT -9999
#define NODATA_FLOAT 1.e20
#define MAXVAR 25
#define MAXGRID 4000
#define MAXDIM 5
#define MAXSTRING 500
#define MAXLEV 15
#define NGLOBALS 7
#define LEAPYR(y) (!((y)%400)) || (!((y%4) && ((y)%100)))
#ifndef FALSE
#define FALSE 0
#define TRUE !FALSE
#endif



/* 
 * Globally defined NetCDF to Vic structs
 */ 
struct VarAtt {
  char *read;
  char *name;
  char *units;
  char *z_dep;
  char *sign;
  float mult;
  char *long_name;
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
