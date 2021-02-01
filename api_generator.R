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
  if (all(!is.na(as.numeric(value)) | is.na(value))) {
    list(
      status = TRUE,
      message = "Valid input"
    )
  } else {
    list(
      status = FALSE,
      message = list(
        variable_name = variable_name,
        valid_options = "Variable must be a valid number!"
      )
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
#* @serializer json
#* @get /predict
#* @post /predict
function(req, res, ...) {
  inputs <- list(...)
  get_result(inputs)
}
