# Generics to support LightGBM model type
handler_predict._lgb.Booster <- function(vetiver_model, ...) {
  ptype <- vetiver_model$ptype

  function(req) {
    new_data <- req$body
    prepped_data <- recipes::bake(
      object = vetiver_model$recipe,
      new_data = new_data,
      recipes::all_predictors()
    )
    pred <- predict(vetiver_model$model, new_data = prepped_data, ...)$.pred
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
  }
}
