// program fcst_sflow.c by XDZ
// read sflow data of ESP/CPC forecast and write stats
// .... original from a set of csh and pl scripts
//
// Input data
// .... (1) sflow (route) data of ESP/CPC forecast
// .... (.) STN climatology stats file (STN.cum.stat)
// .... (.) enso pdo index file cover the forecast period
// Output data
// .... (1) BAS stats files: ESP/CPC_flowdata_BAS.txt, BAS.forweb, BAS.ESPstats, BAS.ESPstats_DIFF, BAS.ESPstats_trace (if required)
// .... (2) STN quart files, and enso (cold/neut/warm), enso_pdo for ESP, and sflow.STN.all
// .... (.) BAS.sav (binary).
// Control files
// .... common control file ESPsflow.ctr (default)
// .... BAS control file, e.g., BAS.ctr, as program input
// .... STN namelist file, e.g., BAS.stn, indicated in the BAS control file
//
// to make executable,
//      gcc -o ../fcst_sflow fcst_sflow.c tools.o
// to run,
//      fcst_sflow <FCST> <BAS.ctr file> <fcst year> <month> <day> <READ_SAV(optional)>
//

# include <stdio.h>
# include <stdlib.h>
# include <string.h>
# include <unistd.h>

# include "tools.h"

// -------------------------------------------------
# define  MAX_CHAR  600

# define  MAX_METYR 40
# define  MAX_MON   18
# define  MAX_STN   200 
# define  MAX_QUART 5
# define  MAX_STAT  8        
// quart: 0: med, 1: min, 2: 25%, 3: 75%, 4: max
// stat:  0-2: 10%, 50%, 90% pct over clim_avg; 3-4: med/med, avg/avg; 5-6: ENSO med/avg, avg/avg; 7: trace avg/avg

# define  NAME_BAS  20
# define  NAME_STN  8
# define  MAX_HIST  400

# define  ERR       0.0001

// -------------------------------------------------
// ------- parameter provide by control file -------
char fcst_type;              // forecast type: 1 for ESP, 2 for CPC, 3 for CFS
char str_fcst[4];            // ESP, CPC or CPC

char path_work[MAX_CHAR];
char path_route[MAX_CHAR];
char path_clim[MAX_CHAR];
char path_spinup[MAX_CHAR];

char file_enso_pdo[MAX_CHAR];
char file_trace_year[MAX_CHAR];

char name_bas[NAME_BAS];
char name_stn[MAX_STN][NAME_STN];
char name_stn_full[MAX_STN][MAX_CHAR];
char name_stn_last[MAX_STN][NAME_STN];  // stations occurred in last forecast 

int  total_stn, total_mon = 12;   // total_mon: total forecast month, 12 for ESP and CPC, 6 for CFS
int  fcst_yr, fcst_mn, fcst_dy;   // fcst yr, mn, and dy
int  metyr0;                      // metyr0: start of ESP/CPC met years; 
int temp_yr = 1962;
int  mon0;                        // first fcst month (for routing output), can be different with fcst_mn during apr-sep;
int  max_ens = MAX_METYR;         // total ensemble members. 40 for ESP and CPC, 20 for CFS
char idx_enso;                    // enso: -1: cold; 0: neutral; 1 : warm
char idx_pdo;
char idx_stats_type;              // stats: 1: apr-sep; 2: apr-jul;

char op_read_data;                // 1: read from ESP/CPC route output (default); 
                                  // 2: read from BAS.sav for further analysis;
char op_calc_diff = 1;            // 1: calculate ESP/CPC change since last forecast; 0: donot calcaulte;
char op_trace_year = 0;           // 1 if work on trace year; 0 donot;

// --------- parameter used in calculation ---------
float flow[MAX_STN][MAX_MON][MAX_METYR];
float flow_quart[MAX_STN][MAX_MON][MAX_QUART];
float flow_ENSO_quart[MAX_STN][MAX_MON][MAX_QUART];
float flow_ENSO_PDO_quart[MAX_STN][MAX_MON][MAX_QUART];

int   stn_cum_stat[MAX_STN][MAX_STAT];
int   stn_cum_stat_last[MAX_STN][MAX_STAT];
int   stn_6mon_cum[MAX_STN][MAX_STAT];

float stn_clim_stat[MAX_STN][13][2];       // for each stn: 0: avg; 1: median.
                                           // for each mon: 0: summer cum; 1-12: 6-mons average;

char  idx_metyr_enso[MAX_METYR];       // index if the year is of specified enso event (1 for YES);
char  idx_metyr_enso_pdo[MAX_METYR];
float wgt_trace_year[MAX_METYR];       // weight of trace year;
char  stn_idx[MAX_STN];                // >=0: number of this stn in last forecast; 
                                       // -1: missing in last forecast
                                       // -2: not data in current forecast

int   total_yr_enso, total_yr_enso_pdo;
int   total_mon_cum;                   // total months for accumulation (e.g., 4 for apr-jul);
int   MN_IS_APR;                       // which month in the forecast is April. please note that the lower bound of array is 0.
                                       // e.g., if the forecast start from April, MN_IS_APR = 0 instead of 1

char  path_old[MAX_CHAR];
char CURR_PATH[MAX_CHAR];
char  *name_cum_period[] = {"", "apr-sep", "apr-jul"};
char  *name_enso[] = {"cold", "neut", "warm"};
char  *str_enso, *str_cum_period;

long  cur_fcst;                        // cur_fcst = fcst_yr * 10000 + fcst_mn * 100 + fcst_dy
long  bas_fcst_hist[MAX_HIST];         // sorted list of ESP/CPC fcst date for the bas
int   num_fcst_hist, idx_cur_fcst;     // total number of fcsts and index of current in history
char op_calc_cum;                      // 1: calc seasonal cum flow (oct - jun); 0: donot calc (jul - sep);

typedef struct {                       // struct defined as file header for BAS.sav 
  int  total_stn;
  char idx[8];                         // idx[0-2]: MAX_METYR, MAX_MON, MAX_STAT
  int  p[5];                           // p[0] for mon0, p[1] for total_mon
} SAV_HDR;

// -------------------------------------------------
void read_argv(int argc, char *argv[]);
void get_common_para(char *esp_file_bas);
void get_bas_info(char *file_bas);
void read_enso_pdo_index(int metyr0, int metyr1, int mn);
void read_hydro_trace_years(int metyr0, int metyr1, int mn);
void read_clim_stat(int total_stn);
void read_fcst_sflow(int total_stn, int total_mon, int fcst_mn, int dy0, int metyr0);
void read_fcst_last(int total_stn);
void read_sav_data(int total_stn, long cur_fcst);
void update_bas_fcst_hist(long cur_fcst);

void srt_quart_fcst(int total_stn, int total_mon);
void srt_quart_ESP_ENSO_PDO(int total_stn, int total_mon);
void calc_cum_flow(int total_stn, int mn0, int total_mon, int clim_sts_mn, int stat[][MAX_STAT]);
void write_stats(int total_stn);
void write_flowdata_header(FILE *fp, char *fcst_type, char *str1);

// -------------------------------------------------
int main(int argc, char *argv[])
{
  read_argv(argc, argv);
  getcwd(path_old, MAX_CHAR);
  //chdir("input"); /// Shrad made this change
  get_common_para(argv[2]);
  get_bas_info(argv[3]);
  if (((fcst_mn < 7) || (fcst_mn > 9)) && (fcst_type != 3)) op_calc_cum = 1;  // calc seasonal cum flow during oct - jun.
  else {op_calc_cum = 0; op_calc_diff = 0;}
  //*chdir("..");

  if (fcst_type == 1) { // need ENSO indexes and trace year information for ESP forecast
    read_enso_pdo_index(metyr0, metyr0 + MAX_METYR, mon0);
    read_hydro_trace_years(metyr0, metyr0 + MAX_METYR, mon0);
  }
  read_clim_stat(total_stn);
  if (op_read_data != 2) read_fcst_sflow(total_stn, total_mon, fcst_mn, fcst_dy, metyr0);
  else                   read_sav_data(total_stn, cur_fcst);

  //*chdir(path_work);
  update_bas_fcst_hist(cur_fcst);
  if (op_calc_diff) read_fcst_last(total_stn);

  srt_quart_fcst(total_stn, total_mon);
  if (fcst_type == 1) srt_quart_ESP_ENSO_PDO(total_stn, total_mon);  // do ENSO statistics only for ESP forecast
  printf("\ncalculate cum flow and make stats...\n");
  if (op_calc_cum) calc_cum_flow(total_stn, MN_IS_APR, total_mon_cum, 0, stn_cum_stat);
  else memset((void *)&stn_cum_stat[0][0], -1, sizeof(stn_cum_stat));
  calc_cum_flow(total_stn, fcst_mn - mon0, 6, fcst_mn, stn_6mon_cum);
  write_stats(total_stn);

  //*chdir(path_old);
  printf("\njob finished!\n\n");
  return(1);
}

void read_argv(int argc, char *argv[])
{
  if (argc < 7){
    printf("USAGE:  fcst_sflow <FCST> <ESP sflow.ctr file> <BAS.ctr file> <fcst year> <month> <day> <READ_SAV(optional)>\n"); // Shrad changed the input to this script
    printf("where   FCST should be ESP, CPC or CFS\n");
    printf("        READ_SAV == YES to read data from previous BAS.sav. (optional)\n");
    exit(-1);
  }
  
  strncpy(str_fcst, argv[1], 3);
  if (strcmp(str_fcst, "ESP") == 0) {fcst_type = 1;}
  else if (strcmp(str_fcst, "CPC") == 0) {fcst_type = 2;}
  else if (strcmp(str_fcst, "CFS") == 0) {fcst_type = 3; max_ens = 20; total_mon = 6;}
  else {
    printf("FCST should be ESP, CPC or CFS!\n");
    exit(-1);
  }
  
  fcst_yr = atoi(argv[4]);
  fcst_mn = atoi(argv[5]);
  fcst_dy = atoi(argv[6]);
  if ((argc == 8) && (strcmp(argv[7], "YES") == 0)) op_read_data = 2; // Shrad changed the input to fcst_sflow.c 
  else op_read_data = 1;
  //printf () 
  if ((fcst_mn > 4) && (fcst_mn < 7)) mon0 = 4;  // set first fcst month to april during apr-sep
  else mon0 = fcst_mn;
  total_mon += fcst_mn - mon0;               // set total fcst month      
  cur_fcst = fcst_yr * 10000L + fcst_mn * 100 + fcst_dy;
  printf ("Current forecast is %ld\n", cur_fcst);
}

// --------- get fcst and bas information ---------
void get_common_para(char *esp_file_bas) // Shrad made this change. Now this function get the address of ESPsflow.ctr as input
{
  FILE *fp;

  fp = fopen(esp_file_bas, "rt");      // Shrad changes this
  fscanf(fp, "%*s %d", &metyr0);
  fscanf(fp, "%*s %s", file_enso_pdo);
  fscanf(fp, "%*s %d %d", &idx_enso, &idx_pdo);
  // pnnl
  fprintf(stdout,"check idx_pdo %d\n",idx_pdo);
  fclose(fp);

  if (mon0 <= 4) MN_IS_APR = 4 - mon0;   // determine the location of April
  else MN_IS_APR = 16 - mon0;            // (16 - mon0) for first month after April

  switch (idx_enso) {
    case -1 ... 1: str_enso = name_enso[idx_enso + 1]; break;
    default: printf("enso index wrong, should be -1/0/1 (here %d). exit!\n", idx_enso); exit(-1);
  }

  printf("current:      %d %d %d\n", fcst_yr, fcst_mn, fcst_dy);
  printf("first EPS yr: %d\n.....months:  %d\n", metyr0, total_mon);
  printf("enso:         %s\n", str_enso);
}

void get_bas_info(char *file_bas)
{
  FILE *fp; int stn, op;
  char file_stn_info[MAX_CHAR], str[MAX_CHAR];

  //if (strchr(file_bas, '.') == NULL) strcat(file_bas, ".ctr");

  fp = fopen(file_bas, "rt");
  
  printf("open BAS ctrl file: %s.\n", file_bas); 
  
  if (fp == NULL) {printf("cannot open BAS ctrl file: %s. exit!\n", file_bas); exit(-1);}
  fscanf(fp, "%*s %s", name_bas);
  fscanf(fp, "%*s %s", path_clim);
  fscanf(fp, "%*s %d", &idx_stats_type);
  fscanf(fp, "%*s %s", file_stn_info);
  fscanf(fp, "%*s %s", path_spinup);
  fscanf(fp, "%*s %s", file_trace_year);  

  // find the namelist for ESP/CPC/CFS job in the ctrl file
  fgets(str, MAX_CHAR, fp);
  while ((str[0] != '#') || (strstr(str, str_fcst) == NULL)) fgets(str, MAX_CHAR, fp); 

  fscanf(fp, "%*s %s", path_work);
  fscanf(fp, "%*s %s", path_route);
//  fscanf(fp, "%*s %d", &op_read_data); // determined from arguments
//  fscanf(fp, "%*s %d", &op_calc_diff); // determined by date
  fclose(fp);

  // read station information
  memset((void *)&name_stn[0][0], 0, sizeof(name_stn));
  printf("\nreading station info of basin %s from %s.\n", name_bas, file_stn_info);
  fp = fopen(file_stn_info, "r");
  if (fp == NULL) {printf("cannot open station info file: %s. exit!\n", file_stn_info); exit(-1);}
  stn = 0;
  while (!feof(fp)) {
    fscanf(fp, "%d %s %[ -z] ", &op, name_stn[stn], name_stn_full[stn]);
    if (op == 1) stn ++;
  }
  fclose(fp);
  total_stn = stn;

  switch (idx_stats_type) {
    case 1: total_mon_cum = 6; break;
    case 2: total_mon_cum = 4; break;
    default: printf("cum period wrong, should be 1 or 2 (here %d). exit!\n", idx_stats_type); exit(-1);
  }
  str_cum_period = name_cum_period[idx_stats_type]; 

  printf("basin:      %s\n", name_bas);
  printf("work path:  %s\n", path_work);
  printf("route path: %s\n", path_route);
  if (fcst_mn != mon0) printf("spinup path: %s\n", path_spinup);
  printf("clim path:  %s\n", path_clim);
  printf("cum period: %s\n", str_cum_period);
  printf("\ntotal stations: %d\n", total_stn);
  for (stn = 0; stn < total_stn; stn ++) printf(".....(%2d) %s     %s\n", stn, name_stn[stn], name_stn_full[stn]);

  memset(stn_idx, -1, sizeof(stn_idx)); // set initial value of stn_idx to be -1
}

// --------- read data ---------
void read_enso_pdo_index(int metyr0, int metyr1, int mn)
{
  FILE *fp; int yr, metyr, ke, kp;
  char str[MAX_CHAR];

  printf("\nreading history enso pdo information...\n\n");
  //PNNL do not know why  but idx_enso initialized to -1 and linked here, but idx_pdo reset to 0 causing erros
  idx_pdo = 1;
  
  fp = fopen(file_enso_pdo, "rt");
  if (fp == NULL) {printf("cannot read %s. exit!\n", file_enso_pdo); exit(-1);}

  if (mn > 8) {metyr0 ++; metyr1 ++;} // if first forecast month is later than August, use next year's ENSO index

  // search for the year metyr0 in enso_pdo index
  fgets(str, MAX_CHAR, fp);
  do {
    fscanf(fp, "%d %d %d", &metyr, &ke, &kp);
  } while (metyr < metyr0);
  
  memset((void *)idx_metyr_enso, 0, sizeof(idx_metyr_enso));
  memset((void *)idx_metyr_enso_pdo, 0, sizeof(idx_metyr_enso_pdo));

  // read enso_pdo index, set the idx_metyr_enso and idx_metyr_enso_pdo, and calculate the total enso and enso_pdo years 
  yr = 0; total_yr_enso = total_yr_enso_pdo = 0;
  while (metyr < metyr1) {
    if (ke == idx_enso) {
      idx_metyr_enso[yr] = 1;
      total_yr_enso ++;
      if (kp == idx_pdo) {total_yr_enso_pdo ++; idx_metyr_enso_pdo[yr] = 1;}
      fprintf(stdout,"%d %d %d %d %d\n",metyr,ke,kp,total_yr_enso,total_yr_enso_pdo);
    }
    fscanf(fp, "%d %d %d", &metyr, &ke, &kp);
    yr ++;
  }
  fclose(fp);
  //PNNL
  fprintf(stdout,"get enso pdo ysr from %d to %d not incl.\n",metyr0,metyr1);
  fprintf(stdout,"yrs with cold enso pdo %d, cold enso %d, idx_pdo %d, idx_enso %d\n",total_yr_enso_pdo,total_yr_enso,idx_pdo,idx_enso);
}

void read_hydro_trace_years(int metyr0, int metyr1, int mn)
{
  FILE *fp; int yr, metyr, n; float wgt, sum_wgt;
  char str[MAX_CHAR];

  printf("\nreading hydro trace year information...\n\n");
  
  fp = fopen(file_trace_year, "rt");
  if (fp == NULL) {printf("cannot read %s. skip statistics on trace year\n", file_trace_year); return;}

  if (mn > 8) {metyr0 ++; metyr1 ++;} // if first forecast month is later than August, use next year's index

  // read hydro trace years
  fgets(str, MAX_CHAR, fp);           // skip first line
  n = 0; sum_wgt = 0;
  memset((void *)&wgt_trace_year[0], 0, sizeof(wgt_trace_year));
  while (!feof(fp)) {
    if (fscanf(fp, "%d %f ", &metyr, &wgt) == 2) {
      printf("%d %f ", metyr, wgt);
      if ((metyr >= metyr0) && (metyr < metyr1)) {
        metyr -= metyr0;
        wgt_trace_year[metyr] = wgt;
        sum_wgt += wgt;
        printf("\n");
      }
      else {
        printf("....skipped\n");
      }
    }
  }
  fclose(fp);
  printf("sum of trace years weights: %.4f\n", sum_wgt);
  
  if (((sum_wgt - 1.0) > ERR) || ((sum_wgt - 1.0) < -ERR)) {
    printf("sum of weights is not 1.0. weights rescaled\n");
    for (yr = 0; yr < MAX_METYR; yr ++) {wgt_trace_year[yr] /= sum_wgt; printf("%d: %f\n", yr + metyr0, wgt_trace_year[yr]);}
  }
  op_trace_year = 1;
}

void read_clim_stat(int total_stn)
{
  int stn, mon;
  char file_stn[MAX_CHAR];
  FILE *fp;

  printf("reading clim stat information...\n\n");
  
  // read the stats (avg and median) of sflow climatology for each station
  for (stn = 0; stn < total_stn; stn ++) {
    sprintf(file_stn, "%s/%s.cum.stat", path_clim, name_stn[stn]);
    fp = fopen(file_stn, "rt");
    for (mon = 0; mon < 13; mon ++) fscanf(fp, "%f %f", &stn_clim_stat[stn][mon][0], &stn_clim_stat[stn][mon][1]);
    fclose(fp);
  }
}

void read_fcst_sflow(int total_stn, int total_mon, int fcst_mn, int fcst_dy, int metyr0)
{
  int stn, yr, yr0, mon, smn, tmn, day; float tmp_flow, sum;
  char file_sflow[MAX_STN][MAX_CHAR];
  char file_sflow_daily[MAX_STN][MAX_CHAR];
  char file_spinup[MAX_CHAR];
  char file_gz[MAX_CHAR];
  char cmd[MAX_CHAR];
  char op_ave = 0;
  FILE *fp;
  // set input routed files
  for (stn = 0; stn < total_stn; stn ++) {
    //sprintf(file_sflow[stn], "./sflow/%s/%s.month", name_bas, name_stn[stn]);
    //sprintf(file_sflow_daily[stn], "./sflow/%s/%s.day", name_bas, name_stn[stn]);
    sprintf(file_sflow[stn], "./SFLOW.%s.%d/%s.month", name_bas, metyr0, name_stn[stn]);
    sprintf(file_sflow_daily[stn], "./SFLOW.%s.%d/%s.day", name_bas, metyr0, name_stn[stn]);
    }

  // read spinup data if fcst_mn > mon0
  smn = fcst_mn - mon0;
  if (smn > 0) {
    for (stn = 0; stn < total_stn; stn ++) {
      sprintf(file_spinup, "%s/%s.month", path_spinup, name_stn[stn]);
      fprintf(stdout,"opening %s for spinup PNNL\n",file_spinup);
      fp = fopen(file_spinup, "rt");
      if (fp == NULL) {
        printf("cannot open spinupdata %s! skip station.\n", file_spinup);
        strcpy((void *)name_stn[stn], "     "); 
        stn_idx[stn] = -2;  // mark station as missing in current forecast
      }
      else {
        for (mon = 0; mon < smn; mon ++) {
          fscanf(fp, "%*d %*d %f", &tmp_flow);
          for (yr = 0; yr < MAX_METYR; yr ++) flow[stn][mon][yr] = tmp_flow;
        }
        fclose(fp);
      }
    } // end of stn
  }
  
  // unzip archive and read monthly sflow data
  if (fcst_type < 3) yr0 = metyr0;      // ESP and CPC ensemble starts with metyr0
  else               yr0 = 1;           // CFS ensemble starts with 1
  
    
  for (yr = 0; yr < max_ens; yr ++) {
        
  for (stn = 0; stn < total_stn; stn ++) {
    //sprintf(file_sflow[stn], "./sflow/%s/%s.month", name_bas, name_stn[stn]);
    //sprintf(file_sflow_daily[stn], "./sflow/%s/%s.day", name_bas, name_stn[stn]);
    sprintf(file_sflow[stn], "./SFLOW.%s.%d/%s.month", name_bas,  yr + yr0, name_stn[stn]);
    sprintf(file_sflow_daily[stn], "./SFLOW.%s.%d/%s.day", name_bas,  yr + yr0, name_stn[stn]);
    }
    printf("working on run %d out of %d\n", yr + 1, max_ens);
    sprintf(file_gz, "%s/sflow.%d.tar.gz", path_route, yr + yr0);
    fp = fopen(file_gz, "rb");   // check whether data file exist.
    fclose(fp);
    /*if (fp == NULL) {  // try old name style
      sprintf(file_gz, "%s/%8ld/sflow.%4d.%02d.%02d.%s.tar.gz", path_route, cur_fcst, yr + yr0, fcst_mn, fcst_dy, name_bas);
      fp = fopen(file_gz, "rb");
      if (fp == NULL) {
        printf("cannot open data %s. exit!\n", file_gz);
        exit(-1);
      }
    }*/
     
    printf("unzipping & untarring... %s\n", file_gz);
    getcwd(CURR_PATH, MAX_CHAR);

    sprintf(cmd, "tar -xzf %s", file_gz);
    system(cmd); 
    for (stn = 0; stn < total_stn; stn ++) {
      if (stn_idx[stn] == -2) continue;
      
      // read monthly data
      fp = fopen(file_sflow[stn], "rt");
      if (fp == NULL) {
        printf("cannot open %s! skip station.\n", file_sflow[stn]);
        strcpy((void *)name_stn[stn], "     "); 
        stn_idx[stn] = -2;  // mark station as missing in current forecast
      }
      else {
        printf("opening %s.\n", file_sflow[stn]);
        for (mon = smn; mon < total_mon; mon ++) {
          fscanf(fp, "%*d %*d %f", &flow[stn][mon][yr]);
        }
        fclose(fp);
      }

      // read daily data
      if (stn_idx[stn] == -2) continue;
      fp = fopen(file_sflow_daily[stn], "rt");
      if (fp == NULL) {
        printf("cannot open %s! skip station.\n", file_sflow_daily[stn]);
        strcpy((void *)name_stn[stn], "     "); 
        stn_idx[stn] = -2;  // mark station as missing in current forecast
      }
      else {
        sum = 0; op_ave = 0; tmn = total_mon;
        while (!feof(fp)) {
          fscanf(fp, "%*d %d %d %f ", &mon, &day, &tmp_flow);
          if ((day == 1) && ((mon == 4) || (mon == 8))) op_ave = 1;
          if (op_ave) {
            sum += tmp_flow;
            if (day == 15) { // calc average sflow for day 1-15 and save
              flow[stn][tmn][yr] = sum / 15.0; tmn ++;
              op_ave = 0; sum = 0;
            }
          }
        }
        fclose(fp);
      }

    } // end of stn
  
    sprintf(cmd, "rm -rf ./SFLOW*");
    system(cmd); 
  } // end of metyr
}

void read_fcst_last(int total_stn)
{
// read bas ESP/CPC/CFSstats of last forecast from BAS.sav file (binary)
// see the notes in subroutine "write_stats" for the organization of BAS.sav file
  int stn, stn1, total_stn_last, max_metyr, max_mon, max_stat, *pd; 
  long last_fcst;
  char file_bas[MAX_CHAR];
  SAV_HDR sav_hdr;
  FILE *fp;

  printf("\nreading stats data of last forecast...\n\n");
  if (idx_cur_fcst == 0) {
    printf("cannot read previous forecast. skip calculation of fcst change.\n", file_bas); 
    op_calc_diff = 0;
    return;
  }
  last_fcst = bas_fcst_hist[idx_cur_fcst - 1];
  sprintf(file_bas, "%8ld.%s/%s.sav", last_fcst, str_fcst, name_bas);
  fp = fopen(file_bas, "rb");
  if (fp == NULL) {
    printf("cannot read last fcst: %s. skip calculation of fcst change.\n", file_bas); 
    op_calc_diff = 0;
    return;
  }

  // read total_stn, name_stn[][], and stn_cum_stat[][] of last forecast; skip flow[][][] 
  fread(&sav_hdr, sizeof(SAV_HDR), 1, fp);
  total_stn_last = sav_hdr.total_stn;
  max_metyr = sav_hdr.idx[0];
  max_mon = sav_hdr.idx[1];
  max_stat = sav_hdr.idx[2];
  if (max_metyr < 20) max_metyr = MAX_METYR;
  if (max_mon < 6) max_mon = MAX_MON;
  if (max_stat < 1) max_stat = 7;  // old stat has only 7 items

  fread((void *)&name_stn_last[0][0], NAME_STN, total_stn_last, fp);
  fseek(fp, sizeof(float) * max_metyr * max_mon * total_stn_last, SEEK_CUR);  // skip the flow data
//  fread((void *)&stn_cum_stat_last[0][0], sizeof(int) * MAX_STAT, total_stn_last, fp);
  for (stn = 0; stn < total_stn_last; stn ++) {
    fread((void *)&stn_cum_stat_last[stn][0], sizeof(int), max_stat, fp);
  }
  fclose(fp);

/*  for (stn = 0; stn < total_stn_last; stn ++) {  // show data of last fcst, for debug only
    pd = &stn_cum_stat_last[stn][0];
    printf("%s %d %d %d %d %d %d %d\n", name_stn_last[stn], pd[0], pd[1], pd[2], pd[3], pd[4], pd[5], pd[6]);
  }*/

  // searching whether the stations in current forecast occurs in the last forecast, and its number
  for (stn = 0; stn < total_stn; stn ++) {
    if (stn_idx[stn] == -2) continue; // no need to search if the station is missing in current forecast
    if (strcmp(name_stn[stn], name_stn_last[stn]) == 0) {
      stn_idx[stn] = stn;
    }
    else {
      for (stn1 = 0; stn1 < total_stn_last; stn1 ++) {
        if (strcmp(name_stn[stn], name_stn_last[stn1]) == 0) {
          stn_idx[stn] = stn1; break;
        }
      }
    }
  }
}

void read_sav_data(int total_stn, long cur_fcst)
{
// read bas ESP/CPC/CFS sflow data from BAS.sav file (binary)
  char file_bas[MAX_CHAR], file_spinup[MAX_CHAR];
  int stn, smn, yr, mon, max_metyr, max_mon; float tmp_flow;
  FILE *fp; SAV_HDR sav_hdr; 

  printf("\nreading stats data from BAS.sav...\n\n");
  sprintf(file_bas, "%s/%8ld.%s/%s.sav", path_work, cur_fcst, str_fcst, name_bas);
  fp = fopen(file_bas, "rb");
  if (fp == NULL) {printf("cannot read %s. exit! \n", file_bas); exit(-1);}

  fread(&sav_hdr, sizeof(SAV_HDR), 1, fp);
  fread((void *)&name_stn[0][0], NAME_STN, total_stn, fp);                            // read name_stn[][]
  
//  fread((void *)&flow[0][0][0], sizeof(float) * MAX_METYR, total_stn * MAX_MON, fp);  // read flow[][][]
  // now read flow[][][]
  max_metyr = sav_hdr.idx[0];
  max_mon = sav_hdr.idx[1];
  if (max_metyr < 20) max_metyr = MAX_METYR;
  if (max_mon < 6) max_mon = MAX_MON;      
  for (stn = 0; stn < total_stn; stn ++) {
    if (name_stn[stn][0] != ' ') {
      for (mon = 0; mon < max_mon; mon ++) {
        fread((void *)&flow[stn][mon][0], sizeof(float), max_metyr, fp); 
      }
    }
    else {   // missing stn has name "     "
      fseek(fp, sizeof(float) * max_mon * max_metyr, SEEK_CUR); 
      stn_idx[stn] = -2;  // mark as missing
    }
  }
  fclose(fp);

/*
  // search for missing station and set stn_idx
  for (stn = 0; stn < total_stn; stn ++) {
    if (name_stn[stn][0] == ' ') stn_idx[stn] = -2;   // missing stn has name "     "
  }
*/

  // read spinup data if fcst_mn > mon0
  smn = fcst_mn - mon0;
  if (smn > 0) {
    for (stn = 0; stn < total_stn; stn ++) {
      sprintf(file_spinup, "%s/%s.month", path_spinup, name_stn[stn]);
      fp = fopen(file_spinup, "rt");
      //printf("%s\n", name_stn[stn]);
      printf("open spinupdata %s\n",file_spinup);
      if (fp == NULL) {
        printf("cannot open spinupdata %s! skip station.\n", file_spinup);
        strcpy((void *)name_stn[stn], "     ");
        stn_idx[stn] = -2;  // mark station as missing in current forecast
      }
      else {
        for (mon = 0; mon < smn; mon ++) {
          fscanf(fp, "%*d %*d %f", &tmp_flow);
          for (yr = 0; yr < max_ens; yr ++) flow[stn][mon][yr] = tmp_flow;
        }
        fclose(fp);
      }
    } // end of stn
  }															
}

void update_bas_fcst_hist(long cur_fcst)
{
  char file_hist[MAX_CHAR], *str_fcst_type[4] = {"", "esp", "cpc", "cfs"}; int no, n; 
  FILE *fp;

  sprintf(file_hist, "%s/%s.%3s.hist", path_work, name_bas, str_fcst_type[fcst_type]);
  
  fp = fopen(file_hist, "rt");
  if (fp == NULL) { // BAS.fcst.hist not found; set cur fcst as the first one
    num_fcst_hist = 1; idx_cur_fcst = 0; bas_fcst_hist[0] = cur_fcst;
  }
  else {
    fscanf(fp, "%*s %d ", &num_fcst_hist);
    for (no = 0; no < num_fcst_hist; no ++) fscanf(fp, "%ld ", &bas_fcst_hist[no]);
    fclose(fp);
    for (no = num_fcst_hist - 1; no > -1; no --) {
      if (cur_fcst > bas_fcst_hist[no]) break;
      if (cur_fcst == bas_fcst_hist[no]) {idx_cur_fcst = no; return;} // cur fcst appeared in hist. donot change the hist file 
    }
    idx_cur_fcst = no + 1; 
    for (n = num_fcst_hist; n > idx_cur_fcst; n ++) bas_fcst_hist[n] = bas_fcst_hist[n - 1];
    bas_fcst_hist[idx_cur_fcst] = cur_fcst;
    num_fcst_hist ++;
  }

  fp = fopen(file_hist, "wt");
  fprintf(fp, "total_fcst: %ld\n", num_fcst_hist);
  for (no = 0; no < num_fcst_hist; no ++) fprintf(fp, "%8ld\n", bas_fcst_hist[no]);
  fclose(fp);

  if ((fcst_mn == 10) && (fcst_dy == 1)) op_calc_diff = 0; // donot calc forecast change for oct. 1.
}

// --------- calculation ---------
void srt_quart_fcst(int total_stn, int total_mon)
{
  int stn, mon;
  float tmp_srt[MAX_METYR];

  printf("\nmark sorted and quatiles fcst data...\n");
  for (stn = 0; stn < total_stn; stn ++) {
    printf("...sorting %s\n", name_stn[stn]);

    for (mon = 0; mon < total_mon; mon ++) {
      tools_sort(max_ens, &flow[stn][mon][0], &tmp_srt[0]);
      tools_quart(max_ens, &tmp_srt[0], &flow_quart[stn][mon][0]);
    }
  }
}

void srt_quart_ESP_ENSO_PDO(int total_stn, int total_mon)
{
  int stn, mon, n;
  float tmp_srt[MAX_METYR];

  printf("\nmark sorted and quatiles ESP ENSO data...\n");
  for (stn = 0; stn < total_stn; stn ++) {
    printf("...sorting %s\n", name_stn[stn]);

    for (mon = 0; mon < total_mon; mon ++) {
      n = tools_sort_idx(max_ens, &flow[stn][mon][0], &tmp_srt[0], &idx_metyr_enso[0]);
      tools_quart(n, &tmp_srt[0], &flow_ENSO_quart[stn][mon][0]);
      n = tools_sort_idx(max_ens, &flow[stn][mon][0], &tmp_srt[0], &idx_metyr_enso_pdo[0]);
      //PNNL
      //fprintf(stderr,"has %d values for cold ENSO cold PDO for mon %d\n",n, mon);
      if (n<5) {
        fprintf(stderr,"need more ENSO-PDO event for stats\n"); 
        exit(-1);
      }
      tools_quart(n, &tmp_srt[0], &flow_ENSO_PDO_quart[stn][mon][0]);
    }
  }
}

void calc_cum_flow(int total_stn, int mn0, int total_mon, int clim_sts_mn, int stat[][MAX_STAT])
{
// clim_sts_mn: 0 for summer stats, 1-12 for 6-mons stats
  int stn, yr, yr_enso, mn, n, *pd;
  float sum, avg, avg_enso, avg_trace, clim_avg_100;
  float tmp_cum_flow[MAX_METYR], tmp_srt[MAX_METYR];

  for (stn = 0; stn < total_stn; stn ++) {
    // calc period cum for each year, and then calc cum average
    printf("...cumulating %s\n", name_stn[stn]);
    avg = avg_enso = avg_trace = 0;
    for (yr = 0, yr_enso = 0; yr < max_ens; yr ++) {
      for (mn = 0, sum = 0; mn < total_mon; mn ++) sum += flow[stn][mn + mn0][yr];
      sum /= total_mon;
      tmp_cum_flow[yr] = sum;
      avg += sum;
      if (idx_metyr_enso[yr] == 1) avg_enso += sum; 
      avg_trace += sum * wgt_trace_year[yr];
    }
    // sort cum and find stat
    clim_avg_100 = 100.0 / stn_clim_stat[stn][clim_sts_mn][0];
    tools_sort(max_ens, &tmp_cum_flow[0], &tmp_srt[0]);
    sum = tools_calc_percentile(max_ens, &tmp_srt[0], 0.5);
    pd = &stat[stn][0];
    pd[0] = tools_calc_percentile(max_ens, &tmp_srt[0], 0.1) * clim_avg_100;
    pd[1] = sum * clim_avg_100;
    pd[2] = tools_calc_percentile(max_ens, &tmp_srt[0], 0.9) * clim_avg_100;
    pd[3] = sum * 100.0 / stn_clim_stat[stn][clim_sts_mn][1];
    pd[4] = (avg / max_ens) * clim_avg_100;

    if (fcst_type == 1) {  // do ENSO and trace year statistics for ESP forecast
      n = tools_sort_idx(max_ens, &tmp_cum_flow[0], &tmp_srt[0], &idx_metyr_enso[0]);
      pd[5] = tools_calc_percentile(n, &tmp_srt[0], 0.5) * clim_avg_100;
      pd[6] = (avg_enso / n) * clim_avg_100;
      pd[7] = avg_trace * clim_avg_100;
    }
  }  
}

// --------- write data ---------
void write_stats(int total_stn)
{
  int stn, yr, mn, tmn, dy, mon, op, *pd, *pd6, *pdl; float *p;
  char file_bas[MAX_CHAR], file_stn[MAX_CHAR], str_tmp[MAX_CHAR];
  char met_mon[MAX_MON], new_dir[9];
  char *str_mon[13] = {"", "January", "February", "March", "April"," May"," June",
                       "July", "August", "September", "October", "November", "December"};
//  char *str_mon_abv[13] = {"", "Jan", "Feb", "Mar", "Apr"," May"," Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
  SAV_HDR sav_hdr;
  FILE *fp, *fp2, *fp_stn;
  
  // change directory to YYYYMMDD if exist, otherwise create it
  sprintf(new_dir, "%s/%8ld.%.3s", path_work, cur_fcst, str_fcst);  // path fmt: YYYYMMDD.ESP/CPC/CFS
  //op = //*chdir(new_dir);
  if (op == -1) {
    sprintf(str_tmp, "mkdir %s", new_dir);
    system(str_tmp);
    //*chdir(new_dir);
  }

  printf("\nwriting data to path: %s/%s\n", path_work, new_dir);
  
  // generate the array to hold the actual month series in each fcst run
  for (mn = 0, mon = mon0; mn < total_mon; mn ++) {
    met_mon[mn] = mon;
    mon ++; if (mon > 12) mon = 1;
  }

  if (op_calc_cum) {
    printf("...writing bas stats and forweb.\n", str_fcst);
    sprintf(file_bas, "%s/%s.%3sstats", path_work, name_bas, str_fcst);
    fp = fopen(file_bas, "wt");
    fprintf(fp, "%s %d, %d\n", str_mon[fcst_mn], fcst_dy, fcst_yr);
    for (stn = 0; stn < total_stn; stn ++) {
      if (stn_idx[stn] == -2) continue; // skip the missing station
      pd = &stn_cum_stat[stn][0];
      if (fcst_type == 1) {  // for ESP forecast
        fprintf(fp, "%-56s %7s %7d %7d %7d %9d %7d %9d %7d\n", 
                name_stn_full[stn], str_cum_period, pd[0], pd[1], pd[2], pd[3], pd[4], pd[5], pd[6]);
      }
      else {                // for CPC forecast. note that we donot print for CFS
        fprintf(fp, "%-56s %7s %7d %7d %7d %9d %7d\n", 
                name_stn_full[stn], str_cum_period, pd[0], pd[1], pd[2], pd[3], pd[4]);
      }
    }
    fclose(fp);
  }

  if (op_trace_year) {
    printf("...writing trace year stats.\n", str_fcst);
    sprintf(file_bas, "%s/%s.%3sstats_trace", path_work, name_bas, str_fcst);
    fp = fopen(file_bas, "wt");
    fprintf(fp, "%-56s %7s %7s %7s\n", "station", "ESP", "enso", "trace"); 
    for (stn = 0; stn < total_stn; stn ++) {
      if (stn_idx[stn] == -2) continue; // skip the missing station
      pd = &stn_cum_stat[stn][0];
      fprintf(fp, "%-56s %7d %7d %7d\n", name_stn_full[stn], pd[4], pd[6], pd[7]);
    }
    fclose(fp);
  }

  printf("...writing forweb file.\n");
  sprintf(file_bas, "%s/%s.forweb2", path_work, name_bas);
  fp = fopen(file_bas, "wt");
  for (stn = 0; stn < total_stn; stn ++) {
    if (stn_idx[stn] == -2) continue; // skip the missing station
    pd = &stn_cum_stat[stn][0];
    pd6 = &stn_6mon_cum[stn][0];
    fprintf(fp, "%s  %5d %5d %5d   %5d %5d %5d\n", 
            name_stn[stn], pd[1], pd[3], pd[4], pd6[1], pd6[3], pd6[4]);
  }
  fclose(fp);

  printf("...writing bas flowdata and stn sflow quart files.\n");
  strcpy(str_tmp, name_bas);
  upstr(str_tmp);
  sprintf(file_bas, "%s/%3s_flowdata_%s.txt", path_work, str_fcst, str_tmp);
  fp = fopen(file_bas, "wt");
  write_flowdata_header(fp, str_fcst, "");
  sprintf(file_bas, "%s/%3s_flowdata_%s_split.txt", path_work, str_fcst, str_tmp);
  fp2 = fopen(file_bas, "wt");
  write_flowdata_header(fp2, str_fcst, " (Apr and Aug are splitted)");

  for (stn = 0; stn < total_stn; stn ++) {
    if (stn_idx[stn] == -2) continue; // skip the missing station

    sprintf(file_stn, "%s/sflow.%s.all", path_work, name_stn[stn]);
    fp_stn = fopen(file_stn, "wt");
    
    // write station sflow data to clim info file
    printf("......writing %s.\n", name_stn[stn]);
    fprintf(fp, "%s\n", name_stn_full[stn]);
    fprintf(fp2, "%s\n", name_stn_full[stn]);
    for (mn = 0; mn < total_mon; mn ++) {
      mon = met_mon[mn];
      switch (mon) {
        case 4: 
          fprintf(fp2, "%19s ", "Apr(1-15) (16-30)");
          break;
        case 8: 
          fprintf(fp2, "%19s ", "Aug(1-15) (16-31)");
          break;
        default:
          fprintf(fp2, "%9s ", str_mon[mon]);   
      }
    }
    fprintf(fp2, "\n");

    for (yr = 0; yr < max_ens; yr ++) {
      tmn = total_mon;
      for (mn = 0; mn < total_mon; mn ++) {
        fprintf(fp, "%9.1f ", flow[stn][mn][yr]);
        fprintf(fp_stn, "%9.1f ", flow[stn][mn][yr]);
        mon = met_mon[mn];
        switch (mon) {
          case 4: 
            fprintf(fp2, "%9.1f %9.1f ", flow[stn][tmn][yr], (flow[stn][mn][yr] * 30.0 - flow[stn][tmn][yr] * 15.0) / 15.0 );
            tmn ++;
            break;
          case 8: 
            fprintf(fp2, "%9.1f %9.1f ", flow[stn][tmn][yr], (flow[stn][mn][yr] * 31.0 - flow[stn][tmn][yr] * 15.0) / 16.0 );
            tmn ++;
            break;
          default:
            fprintf(fp2, "%9.1f ", flow[stn][mn][yr]);
        }
      }
      fprintf(fp, "\n");
      fprintf(fp2, "\n");
      fprintf(fp_stn, "\n");
    }
    fprintf(fp, "---------------------------------------------\n\n");
    fprintf(fp2, "---------------------------------------------\n\n");
    fclose(fp_stn);

    // write station sflow fcst quart file
    sprintf(file_stn, "%s/sflow.%s.quart", path_work, name_stn[stn]);
    fp_stn = fopen(file_stn, "wt");

    printf ("Writing station sflow check !");

    for (mn = 0; mn < total_mon; mn ++) {
      p = &flow_quart[stn][mn][0];
      fprintf(fp_stn, "%d %.2f %.2f %.2f %.2f %.2f\n", met_mon[mn], p[0], p[1], p[2], p[3], p[4]);
    }
    fclose(fp_stn);

    if (fcst_type == 1) {  // write station ENSO quart files for ESP forecast
      // write station sflow ESP_ENSO quart file
      sprintf(file_stn, "%s/sflow.%s.E%s.quart", path_work, name_stn[stn], str_enso);
      fp_stn = fopen(file_stn, "wt");
      for (mn = 0; mn < total_mon; mn ++) {
        p = &flow_ENSO_quart[stn][mn][0];
        fprintf(fp_stn, "%d %.2f %.2f %.2f %.2f %.2f\n", met_mon[mn], p[0], p[1], p[2], p[3], p[4]);
      }
      fclose(fp_stn);

      // write station sflow ESP PDO quart file
      sprintf(file_stn, "%s/sflow.%s.E%s_Ppos.quart", path_work, name_stn[stn], str_enso);
      fp_stn = fopen(file_stn, "wt");
      for (mn = 0; mn < total_mon; mn ++) {
        p = &flow_ENSO_PDO_quart[stn][mn][0];
        fprintf(fp_stn, "%d %.2f %.2f %.2f %.2f %.2f\n", met_mon[mn], p[0], p[1], p[2], p[3], p[4]);
      }
      fclose(fp_stn);
    } // end if for (str_fcst == 1)
  }
  fclose(fp); fclose(fp2);

  // write BAS.sav file (binary) for later use
  // order of data in the file:
  // sav_hdr      (32 bytes)
  // name_stn     (char * NAME_STN * total_stn)
  // flow         (float * MAX_METYR * MAX_MON * total_stn
  // stn_cum_stat (int * MAX_STAT * total_stn)
  sav_hdr.total_stn = total_stn;
  sav_hdr.idx[0] = MAX_METYR; sav_hdr.idx[1] = MAX_MON; sav_hdr.idx[2] = MAX_STAT;
  sav_hdr.p[0] = mon0; sav_hdr.p[1] = total_mon;
  sprintf(file_bas, "%s/%s.sav", path_work, name_bas);
  printf("...now writing the binary data file %s.\n", file_bas);
  fp = fopen(file_bas, "wb");
  fwrite(&sav_hdr, sizeof(SAV_HDR), 1, fp);
  fwrite((void *)&name_stn[0][0], NAME_STN, total_stn, fp);
  fwrite((void *)&flow[0][0][0], sizeof(float) * MAX_METYR, total_stn * MAX_MON, fp);
  fwrite((void *)&stn_cum_stat[0][0], sizeof(int) * MAX_STAT, total_stn, fp);
  fclose(fp);

  // write fcst change file if applicable
  if (op_calc_diff) {
    printf("...now writing %s change since last forecast.\n", str_fcst);
    sprintf(file_bas, "%s/%s.%sstats_DIFF", path_work, name_bas, str_fcst);
    fp = fopen(file_bas, "wt");
    dy = bas_fcst_hist[idx_cur_fcst - 1];
    yr = dy / 10000; dy -= yr * 10000L; 
    mn = dy / 100; dy -= mn * 100;
    fprintf(fp, "%s %d, %d vs %s %d, %d\n", str_mon[fcst_mn], fcst_dy, fcst_yr, str_mon[mn], dy, yr);
 
    for (stn = 0; stn < total_stn; stn ++) {
      switch (stn_idx[stn]) {
        case -1:        // station does not occur in last forecast
          if (fcst_type == 1) {  // for ESP forecast
            fprintf(fp, "%-56s %7s %7s %7s %7s %9s %7s %9s %7s\n", 
                    name_stn_full[stn], str_cum_period, "---", "---", "---", "---", "---", "---", "---");
          }
          else {        // for CPC forecast
            fprintf(fp, "%-56s %7s %7s %7s %7s %9s %7s\n", 
                    name_stn_full[stn], str_cum_period, "---", "---", "---", "---", "---");
          }
          break;
        case -2: break; // skip the missing station
        default:
          pd = &stn_cum_stat[stn][0];
          pdl = &stn_cum_stat_last[stn_idx[stn]][0];
          if (fcst_type == 1) {  // for ESP forecast
            fprintf(fp, "%-56s %7s %7d %7d %7d %9d %7d %9d %7d\n", 
                    name_stn_full[stn], str_cum_period, 
                    pd[0] - pdl[0], pd[1] - pdl[1], pd[2] - pdl[2], pd[3] - pdl[3], 
                    pd[4] - pdl[4], pd[5] - pdl[5], pd[6] - pdl[6]);
          }
          else {        // for CPC forecast
            fprintf(fp, "%-56s %7s %7d %7d %7d %9d %7d\n", 
                    name_stn_full[stn], str_cum_period, 
                    pd[0] - pdl[0], pd[1] - pdl[1], pd[2] - pdl[2], pd[3] - pdl[3], pd[4] - pdl[4]);
          }
      }
    }
    fclose(fp);
  }
}

void write_flowdata_header(FILE *fp, char *fcst_type, char *str1)
{
  fprintf(fp, "Monthly Average %s Streamflows (cfs) for start date: %8ld\n", fcst_type, cur_fcst);
  fprintf(fp, "Format: columns are sequential months starting with: %02d-%4d%s", mon0, fcst_yr, str1);
  if (fcst_mn == mon0) fprintf(fp, ". \n");
  else fprintf(fp, " (note, %02d-%4d is first full forecast month)\n", fcst_mn, fcst_yr);
  fprintf(fp, "        rows, for each location, are ordered by fcst. met. years, 1960-1999\n");
  fprintf(fp, "        signifying the met. data applying to the summer runoff period\n");
  fprintf(fp, "NOTE:  all forecast simulations contain model bias; please interpret w.r.t. simulated climatology\n");
  fprintf(fp, "for questions, please email:  Andy Wood, aww@hydro.washington.edu\n\n");
}
