# Setup ------------------------------------------------------------------------
library(arrow)
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
} else {
  readRenviron("secrets/ENV_FILE")
}
readRenviron(".env")

# Get the model run attributes at runtime from env vars
dvc_bucket <- Sys.getenv("AWS_S3_DVC_BUCKET")
run_bucket <- Sys.getenv("AWS_S3_MODEL_BUCKET")
run_id <- Sys.getenv("AWS_S3_MODEL_RUN_ID")
run_year <- Sys.getenv("AWS_S3_MODEL_YEAR")
api_port <- as.numeric(Sys.getenv("API_PORT", unset = "3636"))


# Download Files ---------------------------------------------------------------

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


# Load Model -------------------------------------------------------------------

# Load fit and recipe from file
fit <- lightsnip::lgbm_load(temp_file_fit)
recipe <- readRDS(temp_file_recipe)

# Extract a sample row of predictors to use for the API docs 
predictors <- recipe$var_info %>%
  filter(role == "predictor") %>%
  pull(variable)
ptype_tbl <- training_data %>%
  filter(meta_pin == "13264290020000") %>%
  select(all_of(predictors))
ptype <- vetiver_create_ptype(fit, save_ptype = ptype_tbl)


# Create API -------------------------------------------------------------------

# Create model object and populate metadata
model <- vetiver_model(fit, "LightGBM", save_ptype = ptype)
model$recipe <- recipe
model$pv$round_type <- metadata$pv_round_type
model$pv$round_break <- metadata$pv_round_break[[1]]
model$pv$round_to_nearest <- metadata$pv_round_to_nearest[[1]]

# Start API
pr() %>%
  vetiver_api(model) %>%
  pr_run(port = api_port)
