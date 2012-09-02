# ifndef _TOOLS_SRT_QUART
# define _TOOLS_SRT_QUART

void tools_sort(int num, float *data, float *srt);
int  tools_sort_idx(int num, float *data, float *srt, char *idx);
void tools_quart(int num, float *data, float *quart);
float tools_calc_percentile(int num, float *data, float pct);

char *upstr(char *s);

# endif
