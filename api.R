# Setup ------------------------------------------------------------------------
library(arrow)
library(assertthat)
library(aws.s3)
library(ccao)
library(dplyr)
library(lightsnip)
library(tibble)
library(plumber)
library(purrr)
library(rapidoc)
library(vetiver)
source("generics.R")

# Define constants
dvc_bucket_pre_2024 <- "s3://ccao-data-dvc-us-east-1"
dvc_bucket_post_2024 <- "s3://ccao-data-dvc-us-east-1/files/md5"
base_url_prefix <- "/predict"

# Read AWS creds from Docker secrets
if (file.exists("/run/secrets/ENV_FILE")) {
  readRenviron("/run/secrets/ENV_FILE")
} else if (file.exists("secrets/ENV_FILE")) {
  readRenviron("secrets/ENV_FILE")
}

# Get the model run attributes at runtime from env vars
run_bucket <- Sys.getenv("AWS_S3_MODEL_BUCKET")
api_port <- as.numeric(Sys.getenv("API_PORT", unset = "3636"))
default_run_id_var_name <- "AWS_S3_DEFAULT_MODEL_RUN_ID"
default_run_id <- Sys.getenv(default_run_id_var_name)

# The list of runs that will be deployed as possible model endpoints
valid_runs <- rbind(
  c(
    run_id = "2022-04-27-keen-gabe",
    year = "2022",
    dvc_bucket = dvc_bucket_pre_2024,
    predictors_only = FALSE
  ),
  c(
    run_id = "2023-03-14-clever-damani",
    year = "2023",
    dvc_bucket = dvc_bucket_pre_2024,
    predictors_only = FALSE
  ),
  c(
    run_id = "2024-02-06-relaxed-tristan",
    year = "2024",
    dvc_bucket = dvc_bucket_post_2024,
    predictors_only = TRUE
  ),
  c(
    run_id = "2024-03-17-stupefied-maya",
    year = "2024",
    dvc_bucket = dvc_bucket_post_2024,
    predictors_only = TRUE
  ),
  c(
    run_id = "2025-02-11-charming-eric",
    year = "2025",
    dvc_bucket = dvc_bucket_post_2024,
    predictors_only = TRUE
  ),
  c(
    run_id = "2026-02-11-recursing-rob",
    year = "2026",
    dvc_bucket = dvc_bucket_post_2024,
    predictors_only = TRUE
  )
) %>%
  as_tibble()

assert_that(
  default_run_id %in% valid_runs$run_id,
  msg = sprintf(
    "%s must be a valid run_id - got '%s', expected one of: %s",
    default_run_id_var_name,
    default_run_id,
    paste(valid_runs$run_id, collapse = ", ")
  )
)

# Given a run ID and year, return a model object that can be used to power a
# Plumber/vetiver API endpoint
get_model_from_run <- function(run_id, year, dvc_bucket, predictors_only) {
  # Download Files -------------------------------------------------------------

  # Grab model fit and recipe objects
  temp_file_fit <- tempfile(fileext = ".zip")
  aws.s3::save_object(
    object = file.path(
      run_bucket, "workflow/fit",
      paste0("year=", year),
      paste0(run_id, ".zip")
    ),
    file = temp_file_fit
  )

  temp_file_recipe <- tempfile(fileext = ".rds")
  aws.s3::save_object(
    object = file.path(
      run_bucket, "workflow/recipe",
      paste0("year=", year),
      paste0(run_id, ".rds")
    ),
    file = temp_file_recipe
  )

  # Grab metadata file for the specified run
  metadata <- read_parquet(
    file.path(
      run_bucket, "metadata",
      paste0("year=", year),
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

  # Extract a sample row of data to use for the API docs
  ptype_tbl <- training_data %>%
    filter(meta_pin == "15251030220000")

  # If the model recipe is configured to allow it, strip all chars except
  # for the predictors from the example row
  if (predictors_only) {
    predictors <- recipe$var_info %>%
      filter(role == "predictor") %>%
      pull(variable)
    ptype_tbl <- ptype_tbl %>%
      filter(meta_pin == "15251030220000") %>%
      select(all_of(predictors))
  }

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

# Filter the valid runs for the run marked as default
default_run <- valid_runs %>%
  dplyr::filter(run_id == default_run_id) %>%
  dplyr::slice_head()

# Retrieve paths and model objects for all endpoints to be deployed
all_endpoints <- list()
for (i in seq_len(nrow(valid_runs))) {
  run <- valid_runs[i, ]
  model <- get_model_from_run(
    run$run_id, run$year, run$dvc_bucket, run$predictors_only
  )
  all_endpoints <- append(all_endpoints, list(list(
    path = glue::glue("{base_url_prefix}/{run$run_id}"),
    model = model
  )))
  # If this is the default endpoint, add an extra entry for it
  if (run$run_id == default_run$run_id) {
    all_endpoints <- append(all_endpoints, list(list(
      path = glue::glue("{base_url_prefix}"),
      model = model
    )))
  }
}

# Instantiate a Plumber router for the API. Note that we have to use direct
# Plumber calls instead of using vetiver to define the API since vetiver
# currently has bad support for deploying multiple models on the same API
router <- pr() %>%
  plumber::pr_set_debug(rlang::is_interactive()) %>%
  plumber::pr_set_serializer(plumber::serializer_unboxed_json(null = "null"))

# Add Plumber POST enpdoints for each model
for (i in seq_along(all_endpoints)) {
  endpoint <- all_endpoints[[i]]
  router <- plumber::pr_post(
    router, endpoint$path, handler_predict(endpoint$model)
  )
}

# Define a function to override the openapi spec for the API, using
# each model's prototype for docs and examples
modify_spec <- function(spec) {
  spec$info$title <- "CCAO Residential AVM API"
  spec$info$description <- (
    "API for returning predicted values using CCAO residential AVMs"
  )

  for (i in seq_along(all_endpoints)) {
    endpoint <- all_endpoints[[i]]
    ptype <- endpoint$model$prototype
    path <- endpoint$path
    orig_post <- pluck(spec, "paths", path, "post")
    spec$paths[[path]]$post <- list(
      summary = glue_spec_summary(ptype),
      requestBody = map_request_body(ptype),
      responses = orig_post$responses
    )
  }

  return(spec)
}

router <- plumber::pr_set_api_spec(router, api = modify_spec) %>%
  plumber::pr_set_docs(
    "rapidoc",
    header_color = "#F2C6AC",
    primary_color = "#8C2D2D",
    use_path_in_nav_bar = TRUE,
    show_method_in_nav_bar = "as-plain-text"
  )

# Start API
pr_run(
  router,
  host = "0.0.0.0",
  port = api_port
)
