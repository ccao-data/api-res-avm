library(treesnip)
library(zip)
library(lightgbm)
library(ccao)
library(tidyverse)
library(recipes)
library(tidymodels)
library(arrow)

# Load variable information and models
model_vars <- ccao::vars_dict %>% filter(var_is_predictor == TRUE)

vars_names <- unique(model_vars$var_name_standard)

categorical_vars <- model_vars %>% filter(var_data_type == "categorical") %>% 
  group_by(var_name_standard) %>% summarise(n = n())

numerical_vars <- model_vars %>% filter(var_data_type == "numeric") %>% 
  group_by(var_name_standard) %>% summarise(n = n())

boilerplate_df <- readRDS("boilerplate.RDS")

lgbm_final_full_recipe <- readRDS("lgbm_recipe.rds")

lgbm_final_full_fit <- ccao::model_lgbm_load("lgbm_model.zip")

pv_model <- readRDS("postval_model.rds")

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
  
  # Assign the numeric inputs to boilerplate
  for (var in numerical_vars$var_name_standard) {
    boilerplate_df[var] <- as.numeric(inputs[var])
  }
  
  # Calculare and return prediction value from the model
  lgbm = model_predict(
    spec = lgbm_final_full_fit,
    recipe = lgbm_final_full_recipe,
    data = boilerplate_df
  )
  
  # pv_model loaded earlier from file
  adjusted <- predict(object = pv_model, new_data = boilerplate_df, truth = boilerplate_df$meta_sale_price, estimate = lgbm)
  
  return(list(prediction = lgbm, adjusted_prediction = adjusted))
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