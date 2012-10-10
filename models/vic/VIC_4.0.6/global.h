/**********************************************************************
                        Global Variables

  $Id: global.h,v 4.1.2.7 2008/01/20 05:59:13 vicadmin Exp $

  29-Oct-03 Added version string and removed unused options from
	    optstring.						TJB
**********************************************************************/
char *version = "4.0.6";

char *optstring = "g:vo";

#if QUICK_FS
double   temps[] = { -1.e-5, -0.075, -0.20, -0.50, -1.00, -2.50, -5, -10 };
#endif

int flag;

global_param_struct global_param;
veg_lib_struct *veg_lib;
option_struct options;
#if LINK_DEBUG
debug_struct debug;
#endif
Error_struct Error;
param_set_struct param_set;
