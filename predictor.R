library(zip)
library(lightgbm)
library(ccao)
library(tidyverse)
library(recipes)
library(tidymodels)
library(arrow)
library(treesnip)

model_load <- function(zipfile) {
  ex_dir <- tempdir()
  zip::unzip(zipfile, exdir = ex_dir)
  
  model <- readRDS(file.path(ex_dir, "meta.model"))
  model$fit <- lightgbm::lgb.load(file.path(ex_dir, "lgbm.model"))
  
  return(model)
}

lgbm_final_full_fit <- model_load("lgbm_model.zip")

lgbm_final_full_recipe <- readRDS("lgbm_recipe.rds")

boilerplate_df <- readRDS("boilerplate.RDS")

model_predict <- function(spec, recipe, data) {
  exp(predict(spec, new_data = bake(recipe, data, all_predictors()))$.pred)
}