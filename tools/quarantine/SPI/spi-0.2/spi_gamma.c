/*************************************************************************
*
*     These functions compute the Standardized Precipitation Index
*     using an incomplete gamma distribution function to estimate
*     probabilities.
*
*     Useful references are:
*
*     _Numerical Recipes in C_ by Flannery, Teukolsky and Vetterling
*     Cambridge University Press, ISBN 0-521-35465-x 
*
*     _Handbook of Mathematical Functions_ by Abramowitz and Stegun
*     Dover, Standard Book Number 486-61272-4
*
*
*************************************************************************/

#include "spi.h"

double  gammaq (double a, double x);
double  gammap (double a, double x);
static double   gammcf (double a, double x);
static double   gammser (double a, double x);
double  inv_normal (double prob);
double  gamma_cdf (double beta, double gamm, double pzero, double x);
int gamma_fit (double *datarr, int n,
	       double *alpha, double *beta, double *gamm, double *pzero);

/* Calculate indices assuming incomplete gamma distribution. */
void spi_gamma (int nrun,              /* input - run length */
		double *pp,            /* input - prec array */
				       /* dimensioned [NYRS][12] */
		double *beta,          /* output - beta param */
		double *gamm,          /* output - gamma param */
		double *pzero,         /* output - prob of x = 0 */
		double *index)         /* output - index values */
				       /* also dimensioned [NYRS][12] */
{
    int     im, i, j, n;
    double  *temparr, *t_ptr, alpha;

    /* Allocate temporary space */
    temparr = (double *) malloc(sizeof(double)*((NYRS)+1));

    /* The first nrun-1 index values will be missing. */
    for (j = 0; j < nrun-1; j++)
      index[j] = MISSING;

    /* Sum nrun precip. values; 
       store them in the appropriate index location.
       If any value is missing; set the sum to missing.*/
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

    /*  For nrun<12, the monthly distributions will be substantially
	different.  So we need to compute gamma parameters for
	each month starting with the (nrun-1)th. */
    for (i = 0; i<12; i++)
    {
    	t_ptr = temparr;
	for (j = nrun+i-1; j<NYRS*12; j+=12)
	{
	    if(index[j] != MISSING)
	      {
		*t_ptr = index[j];
		t_ptr++;
	      }
	}
	n = t_ptr - temparr;
	im = (nrun + i - 1) % 12;  /* im is the calendar month; 0=jan...*/

	/* Here's where we do the fitting. */
	gamma_fit (temparr, n, &alpha, &beta[im], &gamm[im], &pzero[im]);
    }

    /* Replace precip. sums stored in index with SPI's */
    for (j = nrun-1; j < NYRS*12; j++)
    {
    	im = j%12;
	if(index[j] != MISSING)
	  {
	    /* Get the probability */
	    index[j] = gamma_cdf(beta[im], gamm[im], pzero[im], index[j]);

	    /* Convert prob. to z value. */
	    index[j] = inv_normal(index[j]);
	  }
    }

    /* Free temp space and return */
    free(temparr);
}


double  inv_normal (double prob)
/****************************************************************************
*
*   input prob; return z.
*
*   See Abromowitz and Stegun _Handbook of Mathematical Functions_, p. 933
*
****************************************************************************/
{
  
  double  t, minus;
  static double   c0 = 2.515517, c1 = 0.802853, c2 = 0.010328,
                  d1 = 1.432788, d2 = 0.189269, d3 = 0.001308;
  
  if (prob > 0.5)
    {
      minus = 1.0;
      prob = 1.0 - prob;
    }
  else
    {
      minus = -1.0;
    }
  
  if (prob < 0.0)
    {
      fprintf (stderr, "Error in inv_normal(). Prob. not in [0,1.0].\n");
      return ((double) 0.0);
    }
  if (prob == 0.0)
    return (9999.0 * minus);
  
  t = sqrt (log (1.0 / (prob * prob)));
  
  return (minus * (t - ((((c2 * t) + c1) * t) + c0) / 
		   ((((((d3 * t) + d2) * t) + d1) * t) + 1.0)));
}


/***************************************************************************
*
*  Estimate incomplete gamma parameters.
*
*  Input:
*      datarr - data array
*      n - size of datarr
*
*  Output:
*      alpha, beta, gamma - gamma paarameters
*      pzero - probability of zero.
*
*  Return:
*      number of non zero items in datarr.
*
****************************************************************************/
int gamma_fit (double *datarr, int n,
		   double *alpha, double *beta, double *gamm, double *pzero)
{
  int     i;
  double  sum, sumlog, mn, nact;
  
  if (n <= 0)
    return (0);
  sum = sumlog = *pzero = 0.0;
  nact = 0;
  
  /*  compute sums */
  for (i = 0; i < n; i++)
    {
      if (datarr[i] > 0.0)
	{
	  sum += datarr[i];
	  sumlog += log (datarr[i]);
	  nact++;
	}
      else
	{
	  (*pzero)++;
	}
    }
  
  *pzero /= n;
  if(nact != 0.0) mn = sum / nact;
  
  if(nact == 1)  /* Bogus data array but do something reasonable */
    {
      *alpha = 0.0;
      *gamm = 1.0;
      *beta = mn;
      return(nact);
    }
  if(*pzero == 1.0) /* They were all zeroes. */
    {
      *alpha = 0.0;
      *gamm = 1.0;
      *beta = mn;
      return(nact);
    }

  /* Use MLE */
  *alpha = log (mn) - sumlog / nact;
  *gamm = (1.0 + sqrt (1.0 + 4.0 * *alpha / 3.0)) / (4.0 * *alpha);
  *beta = mn / *gamm;
  
  return (nact);
}

/**************************************************************************
*
*  Compute probability of a<=x using incomplete gamma parameters.
*
*  Input:
*      beta, gamma - gamma parameters
*      pzero - probability of zero.
*      x - value.
*
*  Return:
*      Probability  a<=x.
*
****************************************************************************/

double  gamma_cdf (double beta, double gamm, double pzero, double x)
{
  if      (x <= 0.0)
      return (pzero);
  else
      return (pzero + (1.0 - pzero) * gammap (gamm, x / beta));
}

/***************************************************************************
*
*  Compute inverse gamma function; i.e. return x given p where CDF(x) = p.
*
*  Input:
*      beta, gamma - gamma parameters
*      pzero - probability of zero.
*      prob - probability.
*
*  Return:
*      x as above.
*
*  Method:
*      We use a simple binary search to first bracket out initial
*      guess and then to refine our guesses until two guesses are within
*      tolerance (eps).  Is there a better way to do this?
*
***************************************************************************/

double  gamma_inv (double beta, double gamm, double pzero, double prob)
{
  int     count = 0;
  double  eps = 1.0e-7;
  double  t_low, t_high, t, p_low, p_high, p;
  
  /* Check if prob < prob of zero */
  if (prob <= pzero)
    return (0.0);
  
  /* Otherwise adjust prob */
  prob = (prob - pzero) / (1.0 - pzero);
  
  /* Make initial guess */
  for (t_high = 2.0*eps; 
       (p_high = gamma_cdf (beta, gamm, pzero, t_high)) < prob;
       t_high *= 2.0);
  t_low = t_high / 2.0;
  p_low = gamma_cdf (beta, gamm, pzero, t_low);
  
  while ((t_high - t_low) > eps)
    {
      count++;
      t = (t_low + t_high) / 2.0;
      p = gamma_cdf (beta, gamm, pzero, t);
      
      if (p < prob)
	{
	  t_low = t;
	  p_low = p;
	}
      else
	{
	  t_high = t;
	  p_high = p;
	}
    }
  return ((t_low + t_high) / 2.0);
}


/*******************************************************************
 *
 *  Functions for the incomplete gamma functions P and Q
 *
 *                  1     /x  -t a-1
 *   P (a, x) = -------- |   e  t    dt,  a > 0
 *              Gamma(x)/ 0
 *
 *   Q (a, x) = 1 - P (a, x)
 *
 * Reference: Press, Flannery, Teukolsky, and Vetterling, 
 *        _Numerical Recipes_, pp. 160-163
 *
 * Thanks to kenny@cs.uiuc.edu
 *
 *********************************************************************/

#include <errno.h>

/* Maximum number of iterations, and bound on error */

#define maxiter 100
#define epsilon 3.0e-7

static double   gln;		/* Holds log gamma (a), in case the  */
                                /* small gamma function is ever needed */

/* Evaluate P(a,x) by its series representation.  Also put log gamma(a)
   into gln. */

static double   gammser (double a, double x)
{
  
  double ap,  sum,  del;
  static int  warn = 0;
  int    n;
  
  gln = lgamma (a);
  
  if (x == 0.0)
    return 0.0;
  
  ap = a;
  sum = 1.0 / a;
  del = sum;
  
  for (n = 0; n < maxiter; ++n)
    {
      sum += (del *= (x / ++ap));
      if (fabs (del) < epsilon * fabs (sum))
	goto exit;
    }
  if (warn++ < 20.)
    {
      fprintf (stderr, "gammser( %f, %f): not converging. \n", a, x);
      fprintf (stderr, "Approximate value of %f  + /-%f used.\n ", sum, del);
    }
  
 exit: 
  return sum * exp (-x + a * log (x) - gln);
}

/* Evaluate P(a,x) in its continued fraction representation.  Once again,
   return gln = log gamma (a). */

static double   gammcf (double a, double x)
{
  double  g = 0.0, gold, a0, a1, b0, b1, fac;
  static int  nwarn = 0;
  register int    n;
  
  gln = lgamma (a);
  gold = 0.0;
  a0 = 1.0;
  a1 = x;
  b0 = 0.0;
  b1 = 1.0;
  fac = 1.0;
  for (n = 1; n <= maxiter; ++n)
    {
      double  an = n;
      double  ana = an - a;
      double  anf;
      a0 = (a1 + a0 * ana) * fac;
      b0 = (b1 + b0 * ana) * fac;
      anf = an * fac;
      a1 = x * a0 + anf * a1;
      b1 = x * b0 + anf * b1;
      if (a1 != 0.0)
	{
	  fac = 1.0 / a1;
	  g = b1 * fac;
	  if (fabs ((g - gold) / g) < epsilon)
	    goto exit;
	  gold = g;
	}
    }
  if (nwarn++ < 20)
    {
      fprintf (stderr, "gammser( %f, %f): not converging. \n", a, x);
      fprintf (stderr, "Inaccurate value of %f +/- %f used.\n", g, fabs (g - gold));
    }
  
 exit: 
  return g * exp (-x + a * log (x) - gln);
}

/* Evaluate the incomplete gamma function P(a,x), choosing the most 
   appropriate representation. */

double  gammap (double a, double x)
{
  if (x < a + 1.0)
    return gammser (a, x);
  else
    return 1.0 - gammcf (a, x);
}

/* Evaluate the incomplete gamma function Q(a,x), choosing the most 
   appropriate representation. */

double  gammaq (double a, double x)
{
  if (x < a + 1.0)
    return 1.0 - gammser (a, x);
  else
    return gammcf (a, x);
}


