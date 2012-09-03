#ifndef VIC2NCUTIL_H_
#define VIC2NCUTIL_H_

#endif /*VIC2NCUTIL_H_*/

#include <time.h>

void Usage(char *);
int init3DFloat(float**, int, int, float);
int init4DFloat(float***, int, int, int, float);

struct Duration {
	clock_t start;
	clock_t end;
};

int durationInMillis(struct Duration* pDuration, double* pD);
int initDuration(struct Duration* pDuration);
