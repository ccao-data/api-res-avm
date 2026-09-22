# Generics to support LightGBM model type
vetiver_create_description._lgb.Booster <- function(model) {
  run_id <- Sys.getenv("AWS_S3_MODEL_RUN_ID", unset = "Unknown")
  paste("Run ID:", run_id)
}


vetiver_create_meta._lgb.Booster <- function(model, metadata) {
  vetiver_meta(metadata, required_pkgs = c("lightgbm", "lightsnip"))
}


handler_predict._lgb.Booster <- function(vetiver_model, ...) {
  ptype <- vetiver_model$ptype

  function(req) {
    # Attach a backtrace to any error raised while predicting so that the API
    # error handler can log it (see error_handler() in logging.R)
    handler_frame <- environment()
    withCallingHandlers(
      {
        new_data <- req$body
        prepped_data <- recipes::bake(
          object = vetiver_model$recipe,
          new_data = new_data,
          recipes::all_predictors()
        )
        pred <- predict(vetiver_model$model, new_data = prepped_data, ...)$.pred
        if (isTRUE(vetiver_model$log_transform_enable)) {
          pred <- exp(pred)
        }
        rounded <- ccao::val_round_fmv(
          pred,
          breaks = vetiver_model$pv$round_break,
          round_to = vetiver_model$pv$round_to_nearest,
          type = vetiver_model$pv$round_type
        )
        list(
          initial_prediction = pred,
          rounded_prediction = rounded
        )
      },
      error = function(err) {
        err$trace <- NULL
        err <- rlang::cnd_entrace(err, top = handler_frame)
        rlang::cnd_signal(err)
      }
    )
  }
}
