# include <ctype.h>
# include "tools.h"

void tools_sort(int num, float *data, float *srt)
{
  int i, ii, jj; float x;

  srt[0] = data[0];
  for (i = 1; i < num; i ++) {
    x = data[i];
    ii = 0;
    while ((ii < i) && (x >= srt[ii])) ii ++;
    if (ii == i) {srt[i] = x; continue;}

    for (jj = i; jj > ii; jj --) srt[jj] = srt[jj - 1];
    srt[ii] = x;
  }
}

int tools_sort_idx(int num, float *data, float *srt, char *idx)
{
  int i, i1, ii, jj; float x;

  i1 = 0;
  for (i = 0; i < num; i ++) {
    if (idx[i] == 0) continue;
    x = data[i];
    ii = 0;
    while ((ii < i1) && (x >= srt[ii])) ii ++;
    if (ii == i1) {srt[i1] = x; i1 ++; continue;}

    for (jj = i1; jj > ii; jj --) srt[jj] = srt[jj - 1];
    srt[ii] = x; i1 ++;
  }
  return(i1);
}

void tools_quart(int num, float *data, float *quart)
{
  quart[1] = data[0]; quart[4] = data[num - 1];

  quart[0] = tools_calc_percentile(num, data, 0.5);
  quart[2] = tools_calc_percentile(num, data, 0.25);
  quart[3] = tools_calc_percentile(num, data, 0.75);
}

float tools_calc_percentile(int num, float *data, float pct)
{
  int n; float fn, k;
//  fn = (num - 1) * pct; n = fn; k = fn - n;
  fn = (num + 1) * pct - 1; n = fn; k = fn - n;
  return(data[n] * (1.0 - k) + data[n + 1] * k);
}

char *upstr(char *s)
{
  char *p;
  for (p = s; *p != '\0'; p ++) *p = toupper(*p);
  return(s);
}

