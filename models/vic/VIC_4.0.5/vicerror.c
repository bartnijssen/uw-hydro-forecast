#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include <vicNl.h>

static char vcid[] = "$Id: vicerror.c,v 4.1 2000/05/16 21:07:16 vicadmin Exp $";

void vicerror(char error_text[])
/**********************************************************************
	vicerror.c	Keith Cherkauer		April 23, 1997

  This subroutine was written to handle numerical errors within the
  VIC model.  This will flush all file buffers so that all records 
  that have been run will be written to disk before the model is exited.

**********************************************************************/
{
        extern option_struct options;
	extern Error_struct Error;
#if LINK_DEBUG
        extern debug_struct debug;
#endif

        filenames_struct fnames;
	void _exit();

        options.COMPRESS=FALSE;	/* turn off compression of last set of files */

	fprintf(stderr,"VIC model run-time error...\n");
	fprintf(stderr,"%s\n",error_text);
	fprintf(stderr,"...now writing output files...\n");
        close_files(&(Error.infp), &(Error.outfp), &fnames);
	fprintf(stderr,"...now exiting to system...\n");
        fflush(stdout);
        fflush(stderr);
	_exit(1);
}
