#include "spi.h"

/* Prototypes */
double *empiric_fit(int n, double *datarr);
double empiric_cdf(int n, double *sortarr, double x);
double  inv_normal (double prob);

/* Calculate SPI assuming incomplete gamma distribution. */
void spi_empiric (int nrun,              /* input - run length */
		  double *pp,            /* input - prec array */
		                         /* dimensioned [NYRS][12] */
		  double *index)         /* output - index values */
                                         /* also dimensioned [NYRS][12] */
{
  int     im, i, j, n, nsort[12];
  double  *temparr, *sort[12], *t_ptr;
  
  temparr = (double *) malloc(sizeof(double)*((NYRS)+1));
  
  for (j = 0; j < nrun-1; j++)
    index[j] = MISSING;
  
  for (j = nrun-1; j < NYRS*12; j++)
    {
      index[j] = 0.0;
      for (i = 0; i < nrun; i++)
	{
	  if(pp[j - i] != MISSING)
	    index[j] += pp[j - i];
	  else
	    {
	      index[j] = MISSING;
	      break;
	    }
	}
    }
  
  for (i = 0; i<12; i++)
    {
      t_ptr = temparr;
      n = 0;
      for (j = nrun+i-1; j<NYRS*12; j+=12)
	{
	  if(index[j] != MISSING)
	    {
	      *t_ptr = index[j];
	      t_ptr++;
	      n++;
	    }
	}
      im = (nrun + i - 1) % 12;
      nsort[im] = n;
      sort[im] = empiric_fit (n, temparr);
    }
  
  for (j = nrun-1; j < NYRS*12; j++)
    {
      im = j%12;
      /*printf("%2d %6.2lf ", im, index[j]);*/
      if(index[j] != MISSING)
	{
	  index[j] = empiric_cdf(nsort[im], sort[im], index[j]);
	  /*printf("%6.2lf ", index[j]);*/
	  index[j] = inv_normal(index[j]);
	  /*printf("%6.2lf\n", index[j]);*/
	}
    }
  free(temparr);
  for(i=0; i<12; i++) free(sort[i]);
}

/* Double compare; needed by qsort. */

int dblcmp (double *a, double *b)
{
  if (*a < *b)
    return (-1);
  else
    if (*a > *b)
      return (1);
    else
      return (0);
}

/*******************************************************************
 *
 *	Form array of sorted data (empirical distribution).
 *
 *	Input:
 *		n - number of data points
 *		datarr - array of input data
 *
 *	Return:
 *		sortarr - pointer to sorted array of points
 *
 *******************************************************************/
double *empiric_fit(int n, double *datarr)
{
  double *sortarr;
  
  if((sortarr = (double *) malloc(n*sizeof(double))) == NULL)
    {
      fprintf(stderr," empiric_fit: cannot allocate memory.\n");
      exit(100);
    }
  memcpy(sortarr, datarr, n*sizeof(double));
  
  qsort (sortarr, n, sizeof(double), dblcmp);
  return (sortarr);
}


/*******************************************************************
 *
 *	Input:
 *		n - array size
 *		sortarr - sorted array
 *		x -  value.
 *	Return:
 *		Probability a value is .le. x (CDF).
 *
 *******************************************************************/
double empiric_cdf(int n, double *sortarr, double x)
{
  
  int hi, lo, mid;
  double prb;
  
  if(x < sortarr[0]) return(0.0);
  if(x > sortarr[n-1]) return(1.0);
  
  hi = n-1;
  lo = 0;
  
  while((mid = (hi + lo) / 2) != lo)
    {
      if (x < sortarr[mid])
	{
	  hi = mid;
	}
      else
	{
	  lo = mid;
	}
    }
  while(sortarr[lo] == sortarr[lo+1]) lo++;
  prb = (double) (lo+1) / (double) (n+1);
  prb += (x - sortarr[lo]) / ((sortarr[lo+1] - sortarr[lo])*(n+1));
  return (prb);
}
