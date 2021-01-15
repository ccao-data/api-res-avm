source('predictor.R')
library(treesnip)
library(zip)
library(lightgbm)
library(ccao)
library(tidyverse)
library(recipes)
library(tidymodels)
library(arrow)

model_vars <- ccao::vars_dict %>% filter(var_is_predictor == TRUE)

valid_categorical <- function(value){
  variable_name <- deparse(substitute(value))
  possible_values <- model_vars %>% filter(var_name_standard == variable_name)
  if (!value %in% possible_values$var_code) {
    return(list(status = FALSE, message =  list(variable_name = variable_name, valid_options = paste(possible_values$var_code, collapse = ", "))))
  } else {
    return(list(status = TRUE, message = "Valid input"))
  }
}

valid_numeric_char <- function(value){
  variable_name <- deparse(substitute(value))
  if(!is.na(as.numeric(value))) {
    return(list(status = TRUE, message = "Valid input"))
  } else {
    return(list(status = FALSE, message = list(variable_name = variable_name, valid_options = "Numeric format")))
  }
}

get_result <- function(pin, char_age, char_air, char_apts, char_attic_fnsh, char_attic_type, 
                       char_beds, char_bldg_sf, char_bsmt, char_bsmt_fin, char_ext_wall, 
                       char_fbath, char_frpl, char_gar1_area, char_gar1_att, char_gar1_cnst, 
                       char_gar1_size, char_hbath, char_hd_sf, char_heat, char_oheat, 
                       char_porch, char_roof_cnst, char_rooms, char_tp_dsgn, char_tp_plan, 
                       char_type_resd, char_use, econ_midincome, econ_tax_rate, geo_floodplain, 
                       geo_fs_flood_factor, geo_fs_flood_risk_direction, geo_ohare_noise, 
                       geo_school_elem_district, geo_school_hs_district, geo_withinmr100, 
                       geo_withinmr101300, ind_garage, ind_large_home, meta_nbhd, 
                       meta_sale_price, meta_town_code, time_sale_day_of_year, time_sale_during_holidays, 
                       time_sale_during_school_year, time_sale_month_of_year, time_sale_quarter_of_year, 
                       time_sale_week, time_sale_week_of_year){
  
  # Validate numeric inputs
  if (!valid_numeric_char(char_age)[[1]]) return(valid_numeric_char(char_age))
  if (!valid_numeric_char(char_beds)[[1]]) return(valid_numeric_char(char_beds))
  if (!valid_numeric_char(char_bldg_sf)[[1]]) return(valid_numeric_char(char_bldg_sf))
  if (!valid_numeric_char(char_fbath)[[1]]) return(valid_numeric_char(char_fbath))
  if (!valid_numeric_char(char_frpl)[[1]]) return(valid_numeric_char(char_frpl))
  if (!valid_numeric_char(char_hbath)[[1]]) return(valid_numeric_char(char_hbath))
  if (!valid_numeric_char(char_hd_sf)[[1]]) return(valid_numeric_char(char_hd_sf))
  if (!valid_numeric_char(char_rooms)[[1]]) return(valid_numeric_char(char_rooms))
  
  # Validate categorical inputs
  if (!valid_categorical(char_air)[[1]]) return(valid_categorical(char_air))
  if (!valid_categorical(char_apts)[[1]]) return(valid_categorical(char_apts))
  if (!valid_categorical(char_attic_fnsh)[[1]]) return(valid_categorical(char_attic_fnsh))
  if (!valid_categorical(char_attic_type)[[1]]) return(valid_categorical(char_attic_type))
  if (!valid_categorical(char_bsmt)[[1]]) return(valid_categorical(char_bsmt))
  if (!valid_categorical(char_bsmt_fin)[[1]]) return(valid_categorical(char_bsmt_fin))
  if (!valid_categorical(char_ext_wall)[[1]]) return(valid_categorical(char_ext_wall))
  if (!valid_categorical(char_gar1_area)[[1]]) return(valid_categorical(char_gar1_area))
  if (!valid_categorical(char_gar1_att)[[1]]) return(valid_categorical(char_gar1_att))
  if (!valid_categorical(char_gar1_cnst)[[1]]) return(valid_categorical(char_gar1_cnst))
  if (!valid_categorical(char_gar1_size)[[1]]) return(valid_categorical(char_gar1_size))
  if (!valid_categorical(char_heat)[[1]]) return(valid_categorical(char_heat))
  if (!valid_categorical(char_oheat)[[1]]) return(valid_categorical(char_oheat))
  if (!valid_categorical(char_porch)[[1]]) return(valid_categorical(char_porch))
  if (!valid_categorical(char_roof_cnst)[[1]]) return(valid_categorical(char_roof_cnst))
  if (!valid_categorical(char_tp_dsgn)[[1]]) return(valid_categorical(char_tp_dsgn))
  if (!valid_categorical(char_tp_plan)[[1]]) return(valid_categorical(char_tp_plan))
  if (!valid_categorical(char_type_resd)[[1]]) return(valid_categorical(char_type_resd))
  if (!valid_categorical(char_use)[[1]]) return(valid_categorical(char_use))
  
  # Assign the inputs to boilerplate
  boilerplate_df$char_age <- as.numeric(char_age)
  boilerplate_df$char_air <- as.numeric(char_air) 
  boilerplate_df$char_apts <- as.numeric(char_apts) 
  boilerplate_df$char_attic_fnsh <- as.numeric(char_attic_fnsh) 
  boilerplate_df$char_attic_type <- as.numeric(char_attic_type)
  boilerplate_df$char_beds <- as.numeric(char_beds) 
  boilerplate_df$char_bldg_sf <- as.numeric(char_bldg_sf)
  boilerplate_df$char_bsmt <- as.numeric(char_bsmt)
  boilerplate_df$char_bsmt_fin <- as.numeric(char_bsmt_fin)
  boilerplate_df$char_ext_wall <- as.numeric(char_ext_wall)
  boilerplate_df$char_fbath <- as.numeric(char_fbath)
  boilerplate_df$char_frpl <- as.numeric(char_frpl)
  boilerplate_df$char_gar1_area <- as.numeric(char_gar1_area)
  boilerplate_df$char_gar1_att <- as.numeric(char_gar1_att)
  boilerplate_df$char_gar1_cnst <- as.numeric(char_gar1_cnst)
  boilerplate_df$char_gar1_size <- as.numeric(char_gar1_size)
  boilerplate_df$char_hbath <- as.numeric(char_hbath)
  boilerplate_df$char_hd_sf <- as.numeric(char_hd_sf)
  boilerplate_df$char_heat <- as.numeric(char_heat)
  boilerplate_df$char_oheat <- as.numeric(char_oheat)
  boilerplate_df$char_porch <- as.numeric(char_porch)
  boilerplate_df$char_roof_cnst <- as.numeric(char_roof_cnst)
  boilerplate_df$char_rooms <- as.numeric(char_rooms) 
  boilerplate_df$char_tp_dsgn <- as.numeric(char_tp_dsgn)
  boilerplate_df$char_tp_plan <- as.numeric(char_tp_plan) 
  boilerplate_df$char_type_resd <- as.numeric(char_type_resd)
  boilerplate_df$char_use <- as.numeric(char_use)
  boilerplate_df$econ_midincome <- as.numeric(econ_midincome)
  boilerplate_df$econ_tax_rate <- as.numeric(econ_tax_rate)
  boilerplate_df$geo_floodplain <- as.numeric(geo_floodplain) 
  boilerplate_df$geo_fs_flood_factor <- as.numeric(geo_fs_flood_factor)
  boilerplate_df$geo_fs_flood_risk_direction <- as.numeric(geo_fs_flood_risk_direction)
  boilerplate_df$geo_ohare_noise <- as.numeric(geo_ohare_noise)
  boilerplate_df$geo_school_elem_district <- geo_school_elem_district
  boilerplate_df$geo_school_hs_district <- geo_school_hs_district
  boilerplate_df$geo_withinmr100 <- as.numeric(geo_withinmr100)
  boilerplate_df$geo_withinmr101300 <- as.numeric(geo_withinmr101300)
  boilerplate_df$ind_garage <- as.logical(ind_garage)
  boilerplate_df$ind_large_home <- as.logical(ind_large_home)
  boilerplate_df$meta_nbhd <- as.character(meta_nbhd) 
  boilerplate_df$meta_sale_price <- as.numeric(meta_sale_price) 
  boilerplate_df$meta_town_code <- as.character(meta_town_code) 
  boilerplate_df$time_sale_day_of_year <- as.numeric(time_sale_day_of_year)
  boilerplate_df$time_sale_during_holidays <- as.logical(time_sale_during_holidays) 
  boilerplate_df$time_sale_during_school_year <- as.logical(time_sale_during_school_year)
  boilerplate_df$time_sale_month_of_year <- as.numeric(time_sale_month_of_year)
  boilerplate_df$time_sale_quarter_of_year <- time_sale_quarter_of_year 
  boilerplate_df$time_sale_week <- as.numeric(time_sale_week) 
  boilerplate_df$time_sale_week_of_year <- as.numeric(time_sale_week_of_year)
  
  model_predict(
    spec = lgbm_final_full_fit,
    recipe = lgbm_final_full_recipe,
    data = boilerplate_df
  )
}

#* Return the prediction value
#* @param pin PIN
#* @param char_age Age
#* @param char_air Central Air Conditioning
#* @param char_apts Apartments
#* @param char_attic_fnsh Attic Finish
#* @param char_attic_type Attic Type
#* @param char_beds Number of bedrooms in the property, defined based on building square footage and the judgement of the person in the field.
#* @param char_bldg_sf As measured from the exterior of the building.
#* @param char_bsmt Basement
#* @param char_bsmt_fin Basement Finish
#* @param char_ext_wall Wall Material
#* @param char_fbath Number of full bathrooms, defined as having a bath or shower. If this value is missing, the default value is set to 1.
#* @param char_frpl Number of fireplaces, counted as the number of flues one can see from the outside of the building.
#* @param char_gar1_area Is Garage 1 physically including within the building area? If yes, the garage area is subtracted from the building square feet calculation by the field agent.
#* @param char_gar1_att Garage 1 Attached
#* @param char_gar1_cnst Garage 1 Material
#* @param char_gar1_size Garage 1 Size
#* @param char_hbath Number of half baths, defined as bathrooms without a shower or bathtub.
#* @param char_hd_sf Square feet of the land (not just the building) of the property. Note that land is divided into 'plots' and 'parcels' - this field applies to parcels, identified by PIN.
#* @param char_heat Central Heating
#* @param char_oheat Other Heating
#* @param char_porch Porch
#* @param char_roof_cnst Roof Material
#* @param char_rooms Number of rooms in the property (excluding baths). Not to be confused with bedrooms.
#* @param char_tp_dsgn This field name comes from a variable that is no longer used, but the field name was not changed to reflect Cathedral Ceiling.
#* @param char_tp_plan Design Plan
#* @param char_type_resd Residences with 1.5 - 1.9 stories are one story and have partial livable attics and are classified based on the square footage of the attic compared to the first floor of the house. So, 1.5 story houses have an attic that is 50% of the area of the first floor, 1.6 story houses are 60%, 1.7 are 70%, etc. However, what is recorded on the field card differs from what is in the database. All 1.5 - 1.9 story houses are coded as 5.
#* @param char_use Use
#* @param econ_midincome Median income of the census tract containing the property centroid.
#* @param econ_tax_rate Tax rate paid by the property owner. Taken from Cook County Treasurer's Office.
#* @param geo_floodplain Indicator for whether property lies within a FEMA-defined floodplain.
#* @param geo_fs_flood_factor Flood risk data provided by First Street and academics at UPenn.
#* @param geo_fs_flood_risk_direction Flood risk data provided by First Street and academics at UPenn.
#* @param geo_ohare_noise O'Hare Noise
#* @param geo_school_elem_district Elementary and middle school district boundaries for Cook County and CPS.
#* @param geo_school_hs_district High school district boundaries for Cook County and CPS.
#* @param geo_withinmr100 Indicates whether the property is within 100 feet of a major road.
#* @param geo_withinmr101300 Indicates whether the property is between 101 and 300 feet of a major road.
#* @param ind_garage Indicates presence of a garage of any size.
#* @param ind_large_home If true, property class is either 208 or 209.
#* @param meta_nbhd Assessor neighborhood. First 2 digits are township code, last 3 digits are neighborhood code.
#* @param meta_sale_price Market price of sale.
#* @param meta_town_code Township Code
#* @param time_sale_day_of_year Numeric encoding of day of year (1 - 365).
#* @param time_sale_during_holidays Indicator for whether sale occurred during holiday season (November - January).
#* @param time_sale_during_school_year Indicator for whether sale occurred during usual school year (September - May).
#* @param time_sale_month_of_year Character encoding of month of year (Jan - Dec).
#* @param time_sale_quarter_of_year Character encoding of quarter of year (Q1 - Q4).
#* @param time_sale_week Sale week calculated as the number of weeks since January 1st, 1997.
#* @param time_sale_week_of_year Numeric encoding of week of year (1 - 52).
#* @post /predict
#* @get /predict
function(pin, char_age, char_air, char_apts = NA, char_attic_fnsh, char_attic_type, 
         char_beds, char_bldg_sf, char_bsmt, char_bsmt_fin, char_ext_wall, 
         char_fbath, char_frpl, char_gar1_area, char_gar1_att, char_gar1_cnst, 
         char_gar1_size, char_hbath, char_hd_sf, char_heat, char_oheat, 
         char_porch, char_roof_cnst, char_rooms, char_tp_dsgn, char_tp_plan, 
         char_type_resd, char_use, econ_midincome, econ_tax_rate, geo_floodplain, 
         geo_fs_flood_factor, geo_fs_flood_risk_direction, geo_ohare_noise, 
         geo_school_elem_district, geo_school_hs_district, geo_withinmr100, 
         geo_withinmr101300, ind_garage, ind_large_home, meta_nbhd, 
         meta_sale_price, meta_town_code, time_sale_day_of_year, time_sale_during_holidays, 
         time_sale_during_school_year, time_sale_month_of_year, time_sale_quarter_of_year, 
         time_sale_week, time_sale_week_of_year) {
  get_result(pin, char_age, char_air, char_apts, char_attic_fnsh, char_attic_type, 
             char_beds, char_bldg_sf, char_bsmt, char_bsmt_fin, char_ext_wall, 
             char_fbath, char_frpl, char_gar1_area, char_gar1_att, char_gar1_cnst, 
             char_gar1_size, char_hbath, char_hd_sf, char_heat, char_oheat, 
             char_porch, char_roof_cnst, char_rooms, char_tp_dsgn, char_tp_plan, 
             char_type_resd, char_use, econ_midincome, econ_tax_rate, geo_floodplain, 
             geo_fs_flood_factor, geo_fs_flood_risk_direction, geo_ohare_noise, 
             geo_school_elem_district, geo_school_hs_district, geo_withinmr100, 
             geo_withinmr101300, ind_garage, ind_large_home, meta_nbhd, 
             meta_sale_price, meta_town_code, time_sale_day_of_year, time_sale_during_holidays, 
             time_sale_during_school_year, time_sale_month_of_year, time_sale_quarter_of_year, 
             time_sale_week, time_sale_week_of_year)
}