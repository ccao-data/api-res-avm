# source('predictor.R')
library(treesnip)
library(zip)
library(lightgbm)
library(ccao)
library(tidyverse)
library(recipes)
library(tidymodels)
library(arrow)

# Load variable informations and models
model_vars <- ccao::vars_dict %>% filter(var_is_predictor == TRUE)

vars_names <- unique(model_vars$var_name_standard)

categorical_vars <- model_vars %>% filter(var_data_type == "categorical") %>% 
  group_by(var_name_standard) %>% summarise(n = n())

numerical_vars <- model_vars %>% filter(var_data_type == "numeric") %>% 
  group_by(var_name_standard) %>% summarise(n = n())

boilerplate_df <- readRDS("boilerplate.RDS")

lgbm_final_full_recipe <- readRDS("lgbm_recipe.rds")

lgbm_final_full_fit <- ccao::model_lgbm_load("lgbm_model.zip")

valid_categorical <- function(variable_name, value){
  possible_values <- model_vars %>% filter(var_name_standard == variable_name)
  if (!value %in% possible_values$var_code) {
    return(list(status = FALSE, message =  list(variable_name = variable_name, valid_options = possible_values$var_code)))
  } else {
    return(list(status = TRUE, message = "Valid input"))
  }
}

valid_numeric_char <- function(variable_name, value){
  if(!is.na(as.numeric(value))) {
    return(list(status = TRUE, message = "Valid input"))
  } else {
    return(list(status = FALSE, message = list(variable_name = variable_name, valid_options = "Numeric format")))
  }
}

check_completeness <- function(inputs) {
  input_vars <- names(inputs)
  miss_vars <- setdiff(vars_names, input_vars)
  if (length(miss_vars) ==  0) {
    return(list(TRUE, "Complete"))
  } else {
    return(list(FALSE, missing_vars = miss_vars))
  }
}

get_result <- function(pin, inputs){
  # Check completeness
  if (check_completeness(inputs)[[1]] == FALSE) return(check_completeness(inputs))
  
  # Validate categorical inputs
  for (var in categorical_vars$var_name_standard) {
    if (!valid_categorical(var, inputs[var])[[1]]) return(valid_categorical(var, inputs[var]))
  }
  
  # Validate numerical inputs
  for (var in numerical_vars$var_name_standard) {
    if (valid_numeric_char(var, inputs[var])[[1]] == FALSE) return(valid_numeric_char(var, inputs[var]))
  }
  
  # Assign the inputs to boilerplate
  boilerplate_df$char_age <- as.numeric(inputs$char_age)
  boilerplate_df$char_air <- as.numeric(inputs$char_air) 
  boilerplate_df$char_apts <- as.numeric(inputs$char_apts)
  boilerplate_df$char_attic_fnsh <- as.numeric(inputs$char_attic_fnsh) 
  boilerplate_df$char_attic_type <- as.numeric(inputs$char_attic_type)
  boilerplate_df$char_beds <- as.numeric(inputs$char_beds) 
  boilerplate_df$char_bldg_sf <- as.numeric(inputs$char_bldg_sf)
  boilerplate_df$char_bsmt <- as.numeric(inputs$char_bsmt)
  boilerplate_df$char_bsmt_fin <- as.numeric(inputs$char_bsmt_fin)
  boilerplate_df$char_ext_wall <- as.numeric(inputs$char_ext_wall)
  boilerplate_df$char_fbath <- as.numeric(inputs$char_fbath)
  boilerplate_df$char_frpl <- as.numeric(inputs$char_frpl)
  boilerplate_df$char_gar1_area <- as.numeric(inputs$char_gar1_area)
  boilerplate_df$char_gar1_att <- as.numeric(inputs$char_gar1_att)
  boilerplate_df$char_gar1_cnst <- as.numeric(inputs$char_gar1_cnst)
  boilerplate_df$char_gar1_size <- as.numeric(inputs$char_gar1_size)
  boilerplate_df$char_hbath <- as.numeric(inputs$char_hbath)
  boilerplate_df$char_hd_sf <- as.numeric(inputs$char_hd_sf)
  boilerplate_df$char_heat <- as.numeric(inputs$char_heat)
  boilerplate_df$char_oheat <- as.numeric(inputs$char_oheat)
  boilerplate_df$char_porch <- as.numeric(inputs$char_porch)
  boilerplate_df$char_roof_cnst <- as.numeric(inputs$char_roof_cnst)
  boilerplate_df$char_rooms <- as.numeric(inputs$char_rooms) 
  boilerplate_df$char_tp_dsgn <- as.numeric(inputs$char_tp_dsgn)
  boilerplate_df$char_tp_plan <- as.numeric(inputs$char_tp_plan) 
  boilerplate_df$char_type_resd <- as.numeric(inputs$char_type_resd)
  boilerplate_df$char_use <- as.numeric(inputs$char_use)
  boilerplate_df$econ_midincome <- as.numeric(inputs$econ_midincome)
  boilerplate_df$econ_tax_rate <- as.numeric(inputs$econ_tax_rate)
  boilerplate_df$geo_floodplain <- as.numeric(inputs$geo_floodplain) 
  boilerplate_df$geo_fs_flood_factor <- as.numeric(inputs$geo_fs_flood_factor)
  boilerplate_df$geo_fs_flood_risk_direction <- as.numeric(inputs$geo_fs_flood_risk_direction)
  boilerplate_df$geo_ohare_noise <- as.numeric(inputs$geo_ohare_noise)
  boilerplate_df$geo_school_elem_district <- inputs$geo_school_elem_district
  boilerplate_df$geo_school_hs_district <- inputs$geo_school_hs_district
  boilerplate_df$geo_withinmr100 <- as.numeric(inputs$geo_withinmr100)
  boilerplate_df$geo_withinmr101300 <- as.numeric(inputs$geo_withinmr101300)
  boilerplate_df$ind_garage <- as.logical(inputs$ind_garage)
  boilerplate_df$ind_large_home <- as.logical(inputs$ind_large_home)
  boilerplate_df$meta_nbhd <- as.character(inputs$meta_nbhd) 
  boilerplate_df$meta_sale_price <- as.numeric(inputs$meta_sale_price) 
  boilerplate_df$meta_town_code <- as.character(inputs$meta_town_code) 
  boilerplate_df$time_sale_day_of_year <- as.numeric(inputs$time_sale_day_of_year)
  boilerplate_df$time_sale_during_holidays <- as.logical(inputs$time_sale_during_holidays) 
  boilerplate_df$time_sale_during_school_year <- as.logical(inputs$time_sale_during_school_year)
  boilerplate_df$time_sale_month_of_year <- as.numeric(inputs$time_sale_month_of_year)
  boilerplate_df$time_sale_quarter_of_year <- inputs$time_sale_quarter_of_year 
  boilerplate_df$time_sale_week <- as.numeric(inputs$time_sale_week) 
  boilerplate_df$time_sale_week_of_year <- as.numeric(inputs$time_sale_week_of_year)
  
  model_predict(
    spec = lgbm_final_full_fit,
    recipe = lgbm_final_full_recipe,
    data = boilerplate_df
  )
}

#* Return the prediction value
#* @param pin PIN
#* @param char_apts Apartments
#* @post /predict
#* @get /predict
function(pin, ...) {
  inputs <- list(...)
  get_result(pin, inputs)
}