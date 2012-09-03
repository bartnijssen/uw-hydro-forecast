/**
 * IO routines for working with NetCDF and VIC files
 */ 

#include <stdio.h>
#include <stdarg.h>

#include "nc2vicIO.h"

/**
 * Outputs a CRLF terminated line.
 */ 
int fprintln(FILE* stream, const char* format, ...)
{
        va_list argp;
        va_start(argp, format);
        vfprintf(stream, format, argp);
        va_end(argp);
        fprintf(stream, "\n");
}

/**
 * Safely opens a file. On error, exit(0) is called
 */
 
 FILE* safefopen(const char* filename, const char* mode) {
 	FILE* filePrt = NULL;
 	if ((filePrt=fopen(filename, mode)) == NULL) {
	    fprintln(stderr, "Error opening file %s for mode %s. System is exiting.", filename, mode);
	    exit(0);
 	}
 	return filePrt;
 }
 
 /**
  * Safely flushes and closes a file. On failure an attempt to close is made, then
  * exit(0) is called.
  */
  
 void safefclose(FILE* pf) {
 	if ((fflush(pf) + fclose(pf)) != 0) {
	    fprintln(stderr, "Error flushing and/or closing unknown file. System is exiting.");
	    exit(0);
 	}
 	return;
 }
