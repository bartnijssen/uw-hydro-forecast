/* RCS Id String
 * $Id: vicNl.h,v 4.4.2.14 2007/04/23 19:30:26 vicadmin Exp $
 */
/************************************************************************
  Modifications:
  2006-Sep-11 Implemented flexible output configuration; uses the new
              out_data and out_data_files structures.			TJB
              Added the following new functions:
                create_output_list
                free_out_data_files
                init_output_list
                parse_output_info
                set_output_defaults
                set_output_var
                zero_output_list
  2006-Sep-14 Implemented ALMA-compliant input and output; several functions
	      now take the save_data structure as an argument.		TJB
  2006-Sep-26 Added 2 arguments to solve_snow(), to track out_rain and
	      out_snow.							TJB
  2006-Oct-26 Merged infiles and outfiles structs into filep_struct.	TJB
  2007-Jan-15 Added PRT_HEADER option; added function write_header.	TJB
  2007-Apr-21 Added functions:						TJB
		free_dmy
		free_out_data
		free_veglib

************************************************************************/

#include <math.h>
#include <vicNl_def.h>

/*** SubRoutine Prototypes ***/

void alloc_atmos(int, atmos_data_struct **);
double arno_evap(layer_data_struct *, layer_data_struct *, double, double, 
		 double, double, double, double, double, double, double, 
		 double, double, double, double, double, double, double);
unsigned char average_moisture_for_storm(double *, double *, double, double);

void CalcAerodynamic(char, int, int, double, double, double, double,
		     double *, double *, double *, double, double *,
		     double *);
void   calc_cloud_cover_fraction(atmos_data_struct *, dmy_struct *, int,
				 int, int, double *);
void   calc_energy_balance_error(int, double, double, double, double, double);
void   calc_longwave(double *, double, double, double);
void   calc_netlongwave(double *, double, double, double);
double calc_netshort(double, int, double, double *);
double calc_rainonly(double,double,double,double,double);
void   calc_root_fractions(veg_con_struct *, soil_con_struct *);
double calc_snow_ground_flux(int, int, int, int, double, double, double, 
			     double, double, double *, double *, double *, 
			     double *, energy_bal_struct *, 
			     snow_data_struct *, layer_data_struct *,
                             layer_data_struct *, soil_con_struct *, char *);
#if QUICK_FS
int    calc_soil_thermal_fluxes(int, double *, double *, double *, double *, 
				double *, double *, double *, double *, 
				double *, double *, double *, double *, 
				double *, double *, double ***, char);
#else
int    calc_soil_thermal_fluxes(int, double *, double *, double *, double *, 
				double *, double *, double *, double *, 
				double *, double *, double *, double *, 
				double *, double *, char);
#endif
double CalcSnowPackEnergyBalance(double Tsurf, ...);
double calc_surf_energy_bal(int, int, int, int, int, int, int, int, int, 
			    double, double, double, double, double, double, 
			    double, double, double, double, double, double, 
			    double, double, double, double, double, double *,
			    double *, double *, double *, double *, float *,
			    atmos_data_struct *, veg_var_struct *, 
			    veg_var_struct *, energy_bal_struct *, 
			    snow_data_struct *,
			    layer_data_struct *, layer_data_struct *, 
			    soil_con_struct *, dmy_struct *);
double calc_trans(double, double);
double calc_veg_displacement(double);
double calc_veg_height(double);
double calc_veg_roughness(double);
void   calc_water_balance_error(int, double, double, double);
double canopy_evap(layer_data_struct *, layer_data_struct *,
		   veg_var_struct *, veg_var_struct *, char, int, int, 
		   double, double *, double, double, double, double, 
		   double, double,  double, double, double, double, 
		   double *, double *, double *, double *, float *);
void   check_files(filep_struct *, filenames_struct *);
FILE  *check_state_file(char *, dmy_struct *, global_param_struct *, int, int, 
                        int *);
void   close_files(filep_struct *, out_data_file_struct *, filenames_struct *);
filenames_struct cmd_proc(int argc, char *argv[]);
void   compress_files(char string[]);
void   compute_dz(double *, double *, int, double);
void   compute_penman_constants(double, double, double, double, double, 
				double, double, float, float, double *, 
				double *, double *, double *, double *);

void   correct_precip(double *, double, double, double, double);
void   compute_soil_layer_thermal_properties(layer_data_struct *, double *,
					     double *, double *, double *, 
					     int);
void   compute_treeline(atmos_data_struct *, dmy_struct *, double, double *, char *);
out_data_struct *create_output_list();

void   display_current_settings(int, filenames_struct *, global_param_struct *);
void   dist_prec(atmos_data_struct *,dist_prcp_struct *,soil_con_struct *,
		 veg_con_struct *,dmy_struct *,global_param_struct *,
		 filep_struct *, out_data_file_struct *, out_data_struct *,
		 save_data_struct *, int,int,char,char, char, int);
#if QUICK_FS
void distribute_node_moisture_properties(double *, double *, double *,
					 double *, double *, double *,
					 double *, double ***, 
					 double *, double *, double *,
					 double *, double *, int, int, char);
#else
void distribute_node_moisture_properties(double *, double *, double *,
					 double *, double *, double *,
					 double *, double *, double *,
					 double *, double *, double *,
					 double *, double *, int, int, char);
#endif
void   distribute_soil_property(double *,double,double,
				double **l_param,
				int, int, double *, double *);

double error_calc_snow_ground_flux(double Tsurf, ...);
double error_calc_surf_energy_bal(double Tsurf, ...);
double ErrorSnowPackEnergyBalance(double Tsurf, ...);
double error_print_snow_ground_flux(double, va_list);
double ErrorPrintSnowPackEnergyBalance(double, va_list);
double error_print_solve_T_profile(double, va_list);
double error_print_surf_energy_bal(double, va_list);
double error_solve_T_profile(double Tsurf, ...);
double estimate_dew_point(double, double, double, double, double);
#if QUICK_FS
void estimate_layer_ice_content(layer_data_struct *, double *, double *,
				double *, double ***, double *,
				double *, double ***, double *,
				double *, double *, float **, int, int, char);
#else
void estimate_layer_ice_content(layer_data_struct *, double *, double *,
				double *, double *, double *, double *,
				double *, double *, double *, double *,
				double *, double *, float **, int, int, char);
#endif
double estimate_T1(double, double, double, double, double, double, double, 
		   double, double, double, double);
double exp_interp(double,double,double,double,double);

double f(double, double, double, double, double, double, double, double,
         double, double, int, double *, double, double, double, double *,
         double *, double *, double *, double *, double *);
void   find_0_degree_fronts(energy_bal_struct *,double *, double *, int);
layer_data_struct find_average_layer(layer_data_struct *, layer_data_struct *,
				     double, double);
void   find_sublayer_temperatures(layer_data_struct *, double *, double *,
				  double *, double, double, int, int);
void   finish_frozen_soil_calcs(energy_bal_struct *, layer_data_struct *,
				layer_data_struct *, layer_data_struct *,
				soil_con_struct *, int, int, double, 
				double *, double *, double *, double *);
void   free_atmos(int nrecs, atmos_data_struct **atmos);
void   free_dist_prcp(dist_prcp_struct *, int);
void   free_dmy(dmy_struct **dmy);
void   free_vegcon(veg_con_struct **);
void   free_veglib(veg_lib_struct **);
void   free_out_data_files(out_data_file_struct **);
void   free_out_data(out_data_struct **);

void   full_energy(int, atmos_data_struct *, soil_con_struct *,
		   veg_con_struct *, dist_prcp_struct *,
		   dmy_struct *,global_param_struct *,int,char);
double func_aero_resist(double,double,double,double,double);
double func_snow_ground_flux(double, va_list);
double func_surf_energy_bal(double, va_list);

double get_avg_temp(double, double, double *, double *, int);
void   get_force_type(char *, int, int *);
global_param_struct get_global_param(filenames_struct *, FILE *);
void   get_next_time_step(int *, int *, int *, int *, int *, int);

double hermint(double, int, double *, double *, double *, double *, double *);
void   hermite(int, double *, double *, double *, double *, double *);
void   HourlyT(int, int, int *, double *, int *, double *, double *);

void   init_output_list(out_data_struct *, int, char *, int, float);
void   initialize_atmos(atmos_data_struct *, dmy_struct *, FILE **, double, 
			double, double, double, double, double, double, 
			double, double *, 
#if OUTPUT_FORCE
			char *, out_data_file_struct *, out_data_struct *);
#else
			char *);
#endif

void   initialize_global();
void   initialize_model_state(dist_prcp_struct *, dmy_struct,
			      global_param_struct *, filep_struct,
			      int, int, int, int, double,
			      soil_con_struct *, veg_con_struct *,
			      char *, int *, save_data_struct *);
void   initialize_new_storm(cell_data_struct ***, veg_var_struct ***,
			    int, int, int, double, double);
void   initialize_snow(snow_data_struct **,int,int);
void   initialize_soil(cell_data_struct **, soil_con_struct *, int);
void   initialize_veg( veg_var_struct **, veg_con_struct *,
		       global_param_struct *);

double linear_interp(double,double,double,double,double);

cell_data_struct **make_cell_data(int, int);
dist_prcp_struct make_dist_prcp(int);
dmy_struct *make_dmy(global_param_struct *);
energy_bal_struct **make_energy_bal(int);
void make_in_and_outfiles(filep_struct *, filenames_struct *, 
			  soil_con_struct *, out_data_file_struct *);
snow_data_struct **make_snow_data(int);
veg_var_struct **make_veg_var(int);
void   MassRelease(double *,double *,double *,double *);
double maximum_unfrozen_water(double, double, double, double);
#if QUICK_FS
double maximum_unfrozen_water_quick(double, double, double **);
#endif
double modify_Ksat(double);
void mtclim42_wrapper(int, int, double, double, double, double, 
		      global_param_struct *, dmy_struct *, double *, 
		      double *, double *, double *, double *, double *);

double new_snow_density(double);
void   nrerror(char *);

void   open_debug();
FILE  *open_file(char string[], char type[]);
FILE  *open_state_file(global_param_struct *, filenames_struct, int, int);

void parse_output_info(filenames_struct *, FILE *, out_data_file_struct **, out_data_struct *);
double penman(double, double, double, double, double, double, double, 
	      double, double, float, float);
void   prepare_full_energy(int, int, int, dist_prcp_struct *,
			   soil_con_struct *, double *, double *);
double priestley(double, double);
void   put_data(dist_prcp_struct *, atmos_data_struct *, veg_con_struct *, 
		out_data_file_struct *, out_data_struct *, save_data_struct *,
		double *, double *, double, double *, char *, dmy_struct *,
		int, int, int, int); 

double quick_penman(double, double, double, double, double, double, 
		    double, double);

double read_arcinfo_value(char *, double, double);
int    read_arcinfo_info(char *, double **, double **, int **);
void   read_atmos_data(FILE *, global_param_struct, int, int, double **);
double **read_forcing_data(FILE **, global_param_struct);
void   read_initial_model_state(FILE *, dist_prcp_struct *, 
				global_param_struct *, int, int, int, 
				soil_con_struct *, int, char *, int *);
void   read_PILPS2c(atmos_data_struct *, FILE *, int *, int, int, int);
void   read_rosemount(atmos_data_struct *, FILE *, int *, int, int, int, int);
void   read_sawd(atmos_data_struct *, FILE *, int *, int, int, int);
void   read_sawd_binary(atmos_data_struct *, FILE *, int *, int, int, int);
void   read_snowband(FILE *, int, double, double **, double **, double **, 
                     char **);
void   read_snowmodel(atmos_data_struct *, FILE *, int, int, int, int);
soil_con_struct read_soilparam(FILE *, int);
soil_con_struct read_soilparam_arc(FILE *, char *, int *, int *, int);
veg_lib_struct *read_veglib(FILE *, int *);
veg_con_struct *read_vegparam(FILE *, int, int);
void   redistribute_during_storm(cell_data_struct ***, veg_var_struct ***,
				 int, int, int, double, double, double, 
				 double *);
void   redistribute_moisture(layer_data_struct *, double *, double *,
			     double *, double *, double *, int);
unsigned char redistribute_moisture_for_storm(double *, double *, double, 
					      double, double);
double root_brent(double, double, char *, double (*Function)(double, va_list), ...);
void   runoff(layer_data_struct *, layer_data_struct *, energy_bal_struct *, 
	      soil_con_struct *, double *, double *, double *, double *, 
	      double *, double, int, int, int, int, int);

void set_max_min_hour(double *, int, int *, int *);
void set_node_parameters(double *, double *, double *, double *, double *,
			 double *, double *, double *, double *, double *,
			 double *, double *, float **,
#if QUICK_FS
			 double ***,
#endif
			 int, int, char);
out_data_file_struct *set_output_defaults(out_data_struct *);
int set_output_var(out_data_file_struct *, int, int, out_data_struct *, char *, int, char *, int, float);
void   setup_frozen_soil(soil_con_struct *, layer_data_struct  *,
			 layer_data_struct *, layer_data_struct *,
			 energy_bal_struct, int, int, int, double,
			 double *, double *, double *);
double shrad(double,double,double,double,double,int,double);
double snow_albedo(double, double, double, double, int, char);
double snow_density(int, double, double, double, double, double, double, 
		    double);
void   snow_intercept(double, double, double, double, double, double *, double, double,
		      double, double, double, double, double, double, double,
		      double *, double *, double *, double *, double *, 
		      double *, double *, double *, int, int, int);
void   snow_melt(soil_con_struct *, int, int, double, double, double *, double,
		 snow_data_struct *, double, double, double, double, double, 
		 double, double, double, double, double, double, double, 
		 double, double, double, double *, double *, double *,
		 double *, double *, double *, double *, double *);
double SnowPackEnergyBalance(double, va_list);
double soil_conductivity(double, double, double, double, double);
void   soil_thermal_calc(soil_con_struct *, layer_data_struct *,
			 energy_bal_struct, double *, double *, double *,
			 int, int);
double soil_thermal_eqn(double, va_list);
double solve_snow(snow_data_struct *, layer_data_struct *, 
		  layer_data_struct *, veg_var_struct *, veg_var_struct *, 
		  int, int, energy_bal_struct *, soil_con_struct *, 
		  char, int, int, int, int, int, int, int, int, double, 
		  double, double, double, double, double, double, double, 
		  double, double, double, double, double, double, double, 
		  double, double, double, double, double, double *, double *,
		  double *, double *, double *, double *, double *, double *,
		  double *, double *, double *, double *, double *, double *, 
		  double *, double *, double *, float *);
double solve_snow_ground_flux(double Tsurf, ...);
double solve_surf_energy_bal(double Tsurf, ...);
#if QUICK_FS
void   solve_T_profile(double *, double *, double *, double *,double *,
		       double *, double, double *, double *, double *,
		       double *, double *, double *, double *, double ***, 
		       int, char *, char, int);
#else
void   solve_T_profile(double *, double *, double *, double *,double *,
		       double *, double, double *, double *, double *,
		       double *, double *, double *, double *, int, char *, 
		       char, int);
#endif
double StabilityCorrection(double, double, double, double, double, double);
void   store_moisture_for_debug(int,int,double *,cell_data_struct ***,
				veg_var_struct ***,snow_data_struct **,
				soil_con_struct *);
void   surface_fluxes(char, int, int, int, int, int, int, int, int, int, 
		      double, double, double, double, double, double, 
		      double, double, double, double *, double *, double *, 
		      double *, double *, double *, double *, double *, double *,
		      double *, double *, double *, double *, double *, double *,
		      double *, double *, float *, atmos_data_struct *, 
		      soil_con_struct *, dmy_struct *, global_param_struct *,
		      energy_bal_struct *, snow_data_struct *, 
		      layer_data_struct *, layer_data_struct *, 
		      veg_var_struct *, veg_var_struct *);
double svp(double);
double svp_slope(double);

void transpiration(layer_data_struct *, int, int, double, double, double, 
		   double, double, double, double, double, double, double, 
		   double *, double *, double *, double *, double *, 
		   double *, float *);
void tridag(double *,double *,double *,double *,double *,int);

void usage(char *);

void   vicerror(char *);
double volumetric_heat_capacity(double,double,double);

void write_atmosdata(atmos_data_struct *, int);
void write_data(out_data_file_struct *, out_data_struct *, dmy_struct *, int);
void write_debug(atmos_data_struct *, soil_con_struct *, cell_data_struct *,
                 energy_bal_struct *, snow_data_struct *, veg_var_struct *,
                 dmy_struct *, global_param_struct *,
                 double, double, int, int, int, int, int, char);
void write_dist_prcp(dist_prcp_struct *);
#if OUTPUT_FORCE
void write_forcing_file(atmos_data_struct *, int nrecs, out_data_file_struct *, out_data_struct *);
#endif
void write_header(out_data_file_struct *, out_data_struct *, dmy_struct *, global_param_struct);
void write_layer(layer_data_struct *, int, int, double *);
void write_model_state(dist_prcp_struct *, global_param_struct *, int, 
		       int, filep_struct *, soil_con_struct *, char, int);
void write_soilparam(soil_con_struct *);
void write_vegparam(veg_con_struct *);
void write_vegvar(veg_var_struct *, int);

void zero_output_list(out_data_struct *);

