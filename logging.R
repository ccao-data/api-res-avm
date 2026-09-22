# Logging setup and helpers for the API. Every log record is a single line of
# JSON so that CloudWatch (or any other log consumer) can parse its fields.

# Define formatter and layout, local only
logger::log_formatter(logger::formatter_json)
logger::log_layout(logger::layout_json_parser(fields = c("time", "level")))

# Send records at ERROR and above to stderr and everything else to stdout.
appender_split_by_level <- function(lines) {
  is_error <- grepl('^\\{"time":"[^"]*","level":"(ERROR|FATAL)"', lines)
  writeLines(lines[!is_error], con = stdout())
  writeLines(lines[is_error], con = stderr())
}
logger::log_appender(appender_split_by_level)

# Log a record describing a request and its response. Any extra named
# arguments are added to the record as additional fields
log_request <- function(level, msg, req, res, ...) {
  logger::log_level(
    level,
    msg = msg,
    method = req$REQUEST_METHOD,
    path = req$PATH_INFO,
    status = res$status,
    execution_time_secs = round(
      as.numeric(Sys.time() - req$log_start_time, units = "secs"),
      digits = 4
    ),
    ...
  )
}

# Plumber hooks that enable timing
log_hooks <- list(
  preroute = function(req) {
    req$log_start_time <- Sys.time()
  },
  postroute = function(req, res) {
    log_request(logger::INFO, "Request completed", req, res)
  }
)

# Format an error's traceback for logging
format_traceback <- function(err) {
  if (inherits(err$trace, "rlang_trace")) {
    paste(format(err$trace), collapse = "\n")
  } else if (!is.null(conditionCall(err))) {
    paste(deparse(conditionCall(err)), collapse = "\n")
  } else {
    NA
  }
}

# Plumber error handler. Mirrors the response produced by plumber's default
# handler (plumber:::defaultErrorHandler) but replaces its print(err) with a
# structured ERROR log record that includes the request and a traceback
error_handler <- function(req, res, err) {
  res$serializer <- plumber::serializer_unboxed_json()
  if (res$status == 200L) {
    res$status <- 500L
    body <- list(error = "500 - Internal server error")
  } else {
    body <- list(error = "Internal error")
  }
  if (is.function(req$pr$getDebug) && isTRUE(req$pr$getDebug())) {
    body$message <- as.character(err)
  }

  log_request(
    logger::ERROR,
    conditionMessage(err),
    req,
    res,
    traceback = format_traceback(err)
  )

  body
}
