/********************************************************************
 *
 *  Project future SPI based on current precip.
 *
 *********************************************************************/
#include <string.h>
#include <stdio.h>
#include <math.h>
#include "spi.h"

#define NSTA 300
#define PALMER_FORMAT

/* Prototypes */

void sum_dist (int nrun, double *pp, int im, 
	       double *beta, double *gamm, double *pzero);

double whatif (double *prec, int tscale, int lproj, double prob);
double  normal_cdf (double z);
double gamma_inv();
double gamma_cdf();
double inv_normal();

static char mon_name[12][4] =
{
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
};

int Calbeg=0, Calend=9999, Last=0, Outyr=0, Outmn=0;

main(int argc, char *argv[])
{
  char header[100], filename[80];
  int nyrs, npp, iy, im, ilen, ista, nsta, i, j, k, n;
  int tscale, lproj;
  int stanum, num_out;
  double  prec[NYRS*12];  /* Array of raw data */
  double  proj_spi;       /* SPI projection */
  double lat[NSTA], lon, elev;
  double spi_out;
  static double beta[12], gamm[12], pzero[12], prob;
  
  
  FILE *sta_list, *in_prec;

  if(argc < 4)
    {
      fprintf(stderr, "Usage: project length future prob [yr month]\n");
      fprintf(stderr, "Where:\n");
      fprintf(stderr, "length = time scale.\n");
      fprintf(stderr, "future = months into future.\n");
      fprintf(stderr, "prob = probability of future precip.\n");
      fprintf(stderr, "yr month = year and month to output(optional)\n");
      exit(100);
    }

  tscale = atoi(argv[1]);
  if(tscale == 0)
    {
      fprintf(stderr, "Bad time scale.\n");
      exit(100);
    }

  lproj = atoi(argv[2]);

  prob = atof(argv[3]);
  if(prob <= 0.0 || prob >= 1.0)
    {
      fprintf(stderr, "Bad probability.\n");
      exit(100);
    }

  if(argc == 6)
    {
      Outyr = atoi(argv[4]);
      Outmn = atoi(argv[5]);
    }

  nyrs = rd_prec(header, prec, in_prec);
  fclose(in_prec);
      
  proj_spi[nsta] = whatif(prec, tscale, lproj, prob);

  iy = Last/12; im = Last % 12;
  if(lproj > 0)
    /*printf("%4d %d/%d  %d mon. SPI - Projected %d mon. at P=%4.2f\n",
      n, im+1, iy+BEGYR, tscale, lproj, prob);*/
    printf("%4d %d/%d  - Probability %d mon. SPI being 0 or more in %d months.\n",
	   n, im+1, iy+BEGYR, tscale, lproj);
  else
    printf("%4d %d/%d  %d mon. SPI\n",
	   n, im+1, iy+BEGYR, tscale);
  printf("%6.2f %6.2f %6.3f %6d\n",
	 lon_out[i], lat_out[i], spi_out[i], num_out[i]);

}

double whatif (double *prec, int tscale, int lproj, double prob)
{
  int i, j, irun, ifut, ndata, nrun, cur_month, fut_month, err,last;
  
  double alpha, beta[12], gamm[12], pzero[12], mean, sd, skew, kurt, n_prob;
  double g_prob, g_index, cur_sum, al, bt, gm;
  double fut_mean, fut_sd, fut_beta, fut_gamm, fut_pzero, fut_sum, med_sum;
  double deficit, prb0;
  double *sums, *spi;

  /* Find last non missing */

  for(last=NYRS*12-1; last>0; last--)
    {
      if(prec[last] != MISSING) break;
    }
  if(last > Last) Last = last;

  if(Outyr)
    {
      last = Last = (Outyr - BEGYR) * 12 + Outmn - 1;
    } 

  cur_month = last % 12;
  /*printf("last,cur_month=%6d %6d\n",last, cur_month);*/

  /* Get current index and sum. */
  spi = (double *)malloc(NYRS*12*sizeof(double));
  spi_gamma (tscale, (double *)prec, beta, gamm, pzero, spi);
  g_prob = normal_cdf(spi[last]);
  cur_sum = gamma_inv(beta[cur_month], gamm[cur_month], pzero[cur_month],
		      g_prob);

  /*printf("g_prob, cur_sum=%6.2f %6.2f  ",g_prob, cur_sum);*/
  if (lproj > tscale)
    {
      fprintf(stderr, "whatif - Projection beyond tscale requested.\n");
      fprintf(stderr, "I'll continue but the results are probably not\n");
      fprintf(stderr, "what you want.\n");
    }
	  
  fut_month = (cur_month + lproj) % 12;

  /* Median expected sum */
  med_sum = gamma_inv(beta[fut_month], gamm[fut_month], pzero[fut_month],
		      0.5);
	  
  /* Compute distribution of sums for future. */
  sum_dist (lproj, prec, fut_month, 
	    &fut_beta, &fut_gamm, &fut_pzero);

  /* Compute sum for partial period */
  cur_sum = 0.0;
  for (i = 0; i < (tscale - lproj); i++)
    {
      if(prec[Last - i] == MISSING)
	return(MISSING);
      cur_sum += prec[last - i];
    }

  deficit = med_sum - cur_sum;
  if (deficit <= 0.0)
    {
      prb0 = 1.0;
    }
  else
    {
      prb0 = 1.0 - gamma_cdf(fut_beta, fut_gamm, fut_pzero, deficit);
    }
/*   printf("med_sum, cur_sum=%6.2f - %6.2f = %6.2f ",med_sum, cur_sum, deficit); */
/*   printf("spi,prb0=%6.2f %6.3f\n",spi[last], prb0); */

	  
  /* Find sum for this prob level. */
  fut_sum = gamma_inv (fut_beta, fut_gamm, fut_pzero, prob);
  fut_sum += cur_sum;
	      
  /* Get prob for this sum and compute index */
	      
  g_prob = gamma_cdf (beta[fut_month], gamm[fut_month], 
		      pzero[fut_month], fut_sum);
  g_index = inv_normal (g_prob);

  free(spi);

  /*return(g_index);*/
  return(prb0);
}

/*
* Calculate distribution of sums of length 'nrun' ending on month 'im'.
* Use incomplete gamma and put the parameters in 'beta', 'gamm' and 
* 'pzero'.  'prec' is pointer to data array.
*/
void sum_dist (int nrun, double *pp, int im, 
	       double *beta, double *gamm, double *pzero)
{
  int     i, j;
  double  sum, *temparr, *t_ptr, alpha;

  temparr = (double *) malloc(sizeof(double)*((NYRS)+1));
  t_ptr = temparr;

  for (j = im; j < NYRS*12; j+=12)
    {
      if((j-nrun+1) < 0) continue;
      *t_ptr = 0.0;
      for (i = 0; i < nrun; i++)
	{
	  if(pp[j - i] != MISSING)
	    *t_ptr += pp[j - i];
	  else
	    {
	      *t_ptr = MISSING;
	      break;
	    }
	}
      if (*t_ptr != MISSING) t_ptr++;
    }
  gamma_fit (temparr, t_ptr-temparr, &alpha, beta, gamm, pzero);
  free(temparr);
}
