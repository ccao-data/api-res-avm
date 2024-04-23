# Setup ------------------------------------------------------------------------
library(arrow)
library(assertthat)
library(aws.s3)
library(ccao)
library(dplyr)
library(lightsnip)
library(plumber)
library(vetiver)
source("generics.R")

# Read AWS creds from Docker secrets
if (file.exists("/run/secrets/ENV_FILE")) {
  readRenviron("/run/secrets/ENV_FILE")
} else if (file.exists("secrets/ENV_FILE")) {
  readRenviron("secrets/ENV_FILE")
} else {
  readRenviron(".env")
}

# Get the model run attributes at runtime from env vars
dvc_bucket <- Sys.getenv("AWS_S3_DVC_BUCKET")
run_bucket <- Sys.getenv("AWS_S3_MODEL_BUCKET")
api_port <- as.numeric(Sys.getenv("API_PORT", unset = "3636"))
default_run_id_var_name <- "AWS_S3_MODEL_RUN_ID"
default_run_id <- Sys.getenv(default_run_id_var_name)

# The list of run IDs that will be deployed as possible model endpoints
valid_run_ids <- c(
  "2024-02-06-relaxed-tristan",
  "2024-03-17-stupefied-maya"
)

assert_that(
  default_run_id %in% valid_run_ids,
  msg = sprintf(
    "%s must be a valid run_id - got '%s', expected one of: %s",
    default_run_id_var_name,
    default_run_id,
    paste(valid_run_ids, collapse = ", ")
  )
)

# Given a run ID, return a model object that can be used to power a
# vetiver API endpoint
get_model_from_run_id <- function(run_id) {
  run_year = substr(run_id, 1, 4)

  # Download Files -------------------------------------------------------------

  # Grab model fit and recipe objects
  temp_file_fit <- tempfile(fileext = ".zip")
  aws.s3::save_object(
    object = file.path(
      run_bucket, "workflow/fit",
      paste0("year=", run_year),
      paste0(run_id, ".zip")
    ),
    file = temp_file_fit
  )

  temp_file_recipe <- tempfile(fileext = ".rds")
  aws.s3::save_object(
    object = file.path(
      run_bucket, "workflow/recipe",
      paste0("year=", run_year),
      paste0(run_id, ".rds")
    ),
    file = temp_file_recipe
  )

  # Grab metadata file for the specified run
  metadata <- read_parquet(
    file.path(
      run_bucket, "metadata",
      paste0("year=", run_year),
      paste0(run_id, ".parquet")
    )
  )

  # Load the training data used for this model
  training_data_md5 <- metadata$dvc_md5_training_data
  training_data <- read_parquet(
    file.path(
      dvc_bucket,
      substr(training_data_md5, 1, 2),
      substr(training_data_md5, 3, nchar(training_data_md5))
    )
  )


  # Load Model -----------------------------------------------------------------

  # Load fit and recipe from file
  fit <- lightsnip::lgbm_load(temp_file_fit)
  recipe <- readRDS(temp_file_recipe)

  # Extract a sample row of predictors to use for the API docs
  predictors <- recipe$var_info %>%
    filter(role == "predictor") %>%
    pull(variable)
  ptype_tbl <- training_data %>%
    filter(meta_pin == "15251030220000") %>%
    select(all_of(predictors))
  ptype <- vetiver_create_ptype(model = fit, save_prototype = ptype_tbl)


  # Create API -----------------------------------------------------------------

  # Create model object and populate metadata
  model <- vetiver_model(fit, "LightGBM", save_prototype = ptype)
  model$recipe <- recipe
  model$pv$round_type <- metadata$pv_round_type
  model$pv$round_break <- metadata$pv_round_break[[1]]
  model$pv$round_to_nearest <- metadata$pv_round_to_nearest[[1]]

  return(model)
}

default_model <- get_model_from_run_id(default_run_id)

router <- pr() %>%
  # Point the /predict endpoint to the default model
  vetiver_api(default_model)

# Create endpoints for each model based on run ID and add them to the router
for (run_id in valid_run_ids) {
  model <- get_model_from_run_id(run_id)
  vetiver_api(
    router,
    model,
    path = sprintf("/predict/%s", run_id)
  )
}

# Start API
pr_run(
  router,
  host = "0.0.0.0",
  port = api_port
)
