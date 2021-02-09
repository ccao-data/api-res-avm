library(treesnip)
library(zip)
library(lightgbm)
library(ccao)
library(tidyverse)
library(magrittr)
library(recipes)
library(tidymodels)
library(arrow)

# Load list of variables used as predictors + their dtypes
reg_vars <- ccao::vars_dict %>%
  filter(var_is_predictor, var_name_standard != "ind_large_lot")
reg_classes <- ccao::class_dict %>%
  filter(as.logical(regression_class))

# Get a list of variables and their types used in the model
vars <- list(id = c("meta_pin", "meta_multi_code", "meta_document_num"))
for (type in c("categorical", "numeric", "logical", "character")) {
  vars[[type]] <- reg_vars %>%
    filter(var_data_type == type) %>%
    pull(var_name_standard) %>% unique()
}

# Load the model objects necessary to run the API
lgbm_final_full_recipe <- readRDS("lgbm_recipe.rds")
lgbm_final_full_fit <- ccao::model_lgbm_load("lgbm_model.zip")
pv_model <- readRDS("postval_model.rds")


# Check that all modeling vars are present
check_completeness <- function(inputs, all_var_names) {
  var_names <- names(inputs)
  miss_vars <- setdiff(all_var_names, var_names)
  if (length(miss_vars) == 0) {
    list(complete = TRUE, missing_vars = "None")
  } else {
    list(complete = FALSE, missing_vars = miss_vars)
  }
}


# Check class of a vector
valid_class <- function(class) {
  if (!all(class %in% reg_classes$class_code)) {
    list(
      status = FALSE,
      message = list(
        variable_name = "class",
        valid_options = paste0(
          "Class must be one of: ",
          paste0(reg_classes$class_code, collapse = ", ")
        )
      )
    )
  } else {
    list(
      status = TRUE,
      message = "Valid regression class"
    )
  }
}


# Check if categorical var has a value listed in the dictionary
valid_categorical <- function(variable_name, value) {
  possible_values <- reg_vars %>%
    filter(variable_name == var_name_standard) %>%
    pull(var_code)
  
  if (all(value %in% possible_values | is.na(value))) {
    list(
      status = TRUE,
      message = "Valid input"
    )
  } else {
    list(
      status = FALSE,
      message = list(
        variable_name = variable_name,
        valid_options = paste0(
          "Variable must be one of the following values: ",
          paste0(possible_values, collapse = ", ")
        )
      )
    )
  }
}


# Check if numeric var is actually a numeric
valid_numeric <- function(variable_name, value) {
  value <- as.numeric(value)
  if (all(!is.na(value))) {
    if (value >= 0) {
      list(
        status = TRUE,
        message = "Valid input"
      )
    } else {
      list(
        status = FALSE,
        message = list(
          variable_name = variable_name,
          valid_options = "Variable must be a valid non-negative number!"
        )
      )
    }
  } else {
    list(
      status = TRUE,
      message = "Valid input"
    )
  }
}


# Check if variable is a valid boolean
valid_logical <- function(variable_name, value) {
  if (all(!is.na(as.logical(value)) | as.numeric(value) %in% c(0, 1))) {
    list(
      status = TRUE,
      message = "Valid input"
    )
  } else {
    list(
      status = FALSE,
      message = list(
        variable_name = variable_name,
        valid_options = "Variable must be either TRUE or FALSE!"
      )
    )
  }
}


# Assign a modeling group based on class
assign_modeling_group <- function(class) {
  tibble(class) %>%
    left_join(
      reg_classes %>%
        mutate(cls = recode(
          reporting_class,
          "Single-Family" = "SF",
          "Multi-Family" = "MF"
        )),
      by = c("class" = "class_code")
    ) %>%
    pull(cls)
}


# Combine the above functions to check inputs and query the model
get_result <- function(inputs) {
  
  inputs <- as_tibble(inputs)
  # Fill in vars which are "required" for modeling, but aren't actually used
  for (var in vars$id) inputs[[var]] <- "0"
  
  # Check that all necessary variables are present
  all_var_names <- c(unname(unlist(vars)), "meta_class")
  if (!check_completeness(inputs, all_var_names)$complete) {
    return(check_completeness(inputs, all_var_names))
  }

  # Validate class column
  if (!valid_class(inputs$meta_class)$status) {
    return(valid_class(inputs$meta_class))
  }
 
  # Convert inputs to dataframe and coerce to expected col types
  inputs <- inputs %>%
    mutate(
      across(all_of(c(vars$character, vars$categorical)), as.character),
      across(all_of(vars$numeric), as.numeric),
      across(
        all_of(vars$logical),
        ~ ifelse(.x %in% c("0", "1"), as.numeric(.x), as.logical(.x))
      ),
      meta_modeling_group = assign_modeling_group(meta_class)
    )


  # Validate categorical inputs
  for (var in vars$categorical) {
    if (!valid_categorical(var, inputs[[var]])$status) {
      return(valid_categorical(var, inputs[[var]]))
    }
  }

  # # Validate numeric inputs
  for (var in vars$numeric) {
    if (!valid_numeric(var, inputs[[var]])$status) {
      return(valid_numeric(var, inputs[[var]]))
    }
  }
  
  # # Validate logical inputs
  for (var in vars$logical) {
    if (!valid_logical(var, inputs[[var]])$status) {
      return(valid_logical(var, inputs[[var]]))
    }
  }

  # Calculate and return prediction value from the model
  inputs <- inputs %>%
    mutate(
      lgbm = model_predict(
        spec = lgbm_final_full_fit,
        recipe = lgbm_final_full_recipe,
        data = .
      ),
      adjusted = predict(
        object = pv_model,
        new_data = .,
        truth = meta_sale_price,
        estimate = lgbm
      )
    )

  output <- list(
    initial_prediction = inputs$lgbm,
    final_prediction = inputs$adjusted
  )
  
  return(output)
}

#* Return the prediction value
#* @param pin PIN
#* @param char_age Age - Numeric
#* @param char_air Central Air Conditioning - 1 : Central A/C, 2 : No Central A/C
#* @param char_apts Apartments - 1 : Two, 2 : Three, 3 : Four, 4 : Five, 5 : Six, 6 : None
#* @param char_attic_fnsh Attic Finish - 1 : Living Area, 2 : Partial, 3 : None
#* @param char_attic_type Attic Type - 1 : Full, 2 : Partial, 3 : None
#* @param char_beds Number of bedrooms in the property, defined based on building square footage and the judgement of the person in the field.
#* @param char_bldg_sf As measured from the exterior of the building. - Numeric
#* @param char_bsmt Basement - 1 : Full, 2 : Slab, 3 : Partial, 4 : Crawl
#* @param char_bsmt_fin Basement Finish - 1 : Formal Rec Room, 2 : Apartment, 3 : Unfinished
#* @param char_ext_wall Wall Material - 1 : Frame, 2 : Masonry, 3 : Frame + Masonry, 4 : Stucco
#* @param char_fbath Number of full bathrooms, defined as having a bath or shower. If this value is missing, the default value is set to 1. - Numeric
#* @param char_frpl Number of fireplaces, counted as the number of flues one can see from the outside of the building. - Numeric
#* @param char_gar1_area Is Garage 1 physically including within the building area? If yes, the garage area is subtracted from the building square feet calculation by the field agent. - 1 : Yes, 2 : No
#* @param char_gar1_att Garage 1 Attached - 1 : Yes, 2 : No
#* @param char_gar1_cnst Garage 1 Material - 1 : Frame, 2 : Masonry, 3 : Frame + Masonry, 4 : Stucco
#* @param char_gar1_size Garage 1 Size - 1 : 1 cars, 2 : 1.5 cars, 3 : 2 cars, 4 : 2.5 cars, 5 : 3 cars, 6 : 3.5 cars, 7 : 0 cars, 8 : 4 cars
#* @param char_hbath Number of half baths, defined as bathrooms without a shower or bathtub. - Numeric
#* @param char_hd_sf Square feet of the land (not just the building) of the property. Note that land is divided into 'plots' and 'parcels' - this field applies to parcels, identified by PIN. - numeric
#* @param char_heat Central Heating - 1 : Warm Air Furnace, 2 : Hot Water Steam, 3 : Electric Heater, 4 : None
#* @param char_oheat Other Heating - 1 : Floor Furnace, 2 : Unit Heater, 3 : Stove, 4 : Solar, 5 : None
#* @param char_porch Porch - 1 : Frame Enclosed, 2 : Masonry Enclosed, 3 : None
#* @param char_roof_cnst Roof Material - 1 : Shingle + Asphalt, 2 : Tar + Gravel, 3 : Slate, 4 : Shake, 5 : Tile, 6 : Other
#* @param char_rooms Number of rooms in the property (excluding baths). Not to be confused with bedrooms. - Numeric
#* @param char_tp_dsgn This field name comes from a variable that is no longer used, but the field name was not changed to reflect Cathedral Ceiling. - 1 : Yes, 2 : No
#* @param char_tp_plan Design Plan - 1 : Architect, 2 : Stock Plan
#* @param char_type_resd Residences with 1.5 - 1.9 stories are one story and have partial livable attics and are classified based on the square footage of the attic compared to the first floor of the house. So, 1.5 story houses have an attic that is 50% of the area of the first floor, 1.6 story houses are 60%, 1.7 are 70%, etc. However, what is recorded on the field card differs from what is in the database. All 1.5 - 1.9 story houses are coded as 5. - 1 : 1 Story, 2 : 2 Story, 3 : 3 Story +, 4 : Split Level, 5 : 1.5 Story, 6 : 1.6 Story, 7 : 1.7 Story, 8 : 1.8 Story, 9 : 1.9 Story
#* @param char_use Use - 1 : Single-Family, 2 : Multi-Family
#* @param econ_midincome Median income of the census tract containing the property centroid. - numeric
#* @param econ_tax_rate Tax rate paid by the property owner. Taken from Cook County Treasurer's Office. - numeric
#* @param geo_floodplain Indicator for whether property lies within a FEMA-defined floodplain. - TRUE/FALSE
#* @param geo_fs_flood_factor Flood risk data provided by First Street and academics at UPenn. - numeric
#* @param geo_fs_flood_risk_direction Flood risk data provided by First Street and academics at UPenn. - numeric
#* @param geo_ohare_noise O'Hare Noise - TRUE/FALSE
#* @param geo_school_elem_district Elementary and middle school district boundaries for Cook County and CPS.- numeric
#* @param geo_school_hs_district High school district boundaries for Cook County and CPS. - numeric
#* @param geo_withinmr100 Indicates whether the property is within 100 feet of a major road. - TRUE/FALSE
#* @param geo_withinmr101300 Indicates whether the property is between 101 and 300 feet of a major road.- TRUE/FALSE
#* @param ind_garage Indicates presence of a garage of any size.- TRUE/FALSE
#* @param ind_large_home If true, property class is either 208 or 209. - numeric
#* @param meta_nbhd Assessor neighborhood. First 2 digits are township code, last 3 digits are neighborhood code.
#* @param meta_sale_price Market price of sale.- numeric
#* @param meta_town_code Township Code - numeric
#* @param time_sale_day_of_year Numeric encoding of day of year (1 - 365). - numeric
#* @param time_sale_during_holidays Indicator for whether sale occurred during holiday season (November - January). - TRUE/FALSE
#* @param time_sale_during_school_year Indicator for whether sale occurred during usual school year (September - May). - TRUE/FALSE
#* @param time_sale_month_of_year Character encoding of month of year (Jan - Dec). - numeric
#* @param time_sale_quarter_of_year Character encoding of quarter of year (Q1 - Q4).- numeric
#* @param time_sale_week Sale week calculated as the number of weeks since January 1st, 1997. - numeric
#* @param time_sale_week_of_year Numeric encoding of week of year (1 - 52). - numeric
#* @param time_sale_year Sale year - numeric
#* @param time_sale_quarter Sale quarter - numeric
#* @param meta_class Meta Class - 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 234, 278, 295
#* @serializer json
#* @get /predict
#* @post /predict
function(req, res, ...) {
  inputs <- list(...)
  get_result(inputs)
}
