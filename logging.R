# Logging setup and helpers for the API. Every log record is a single line of
# JSON so that CloudWatch (or any other log consumer) can parse its fields.
# The app uploads records to CloudWatch itself instead of using Docker's
# awslogs driver, since that driver needs AWS creds on the Docker daemon

# CloudWatch log group to upload logs to, set per environment in
# docker-compose.yaml. Logs are only uploaded if this is set
cloudwatch_log_group <- Sys.getenv("CLOUDWATCH_LOG_GROUP_NAME")

# Uploader state. The client is created on first upload, since api.R reads
# the AWS creds after sourcing this file. Each container start gets its own
# log stream (stream names can't contain colons)
cloudwatch <- new.env()
cloudwatch$client <- NULL
cloudwatch$stream_created <- FALSE
cloudwatch$uploading <- FALSE
cloudwatch$stream <- paste0(
  "plumber-", format(Sys.time(), "%Y-%m-%d_%H-%M-%S", tz = "UTC")
)

# Upload log records to CloudWatch as they're written. Uploads block the API
# from serving requests while they run, so a failed upload is logged and
# dropped instead of retried
cloudwatch_upload <- function(lines) {
  # Skip records logged during an upload, i.e. the warning about a failed
  # upload, which would otherwise try to upload itself in an endless loop
  if (!nzchar(cloudwatch_log_group) || cloudwatch$uploading) {
    return(invisible(NULL))
  }
  cloudwatch$uploading <- TRUE
  on.exit(cloudwatch$uploading <- FALSE)
  timestamp <- round(as.numeric(Sys.time()) * 1000)
  tryCatch(
    # Don't retry or wait long on a request. paws only limits the time to
    # connect, so also limit the total time with httr
    httr::with_config(httr::timeout(3), {
      if (is.null(cloudwatch$client)) {
        cloudwatch$client <- paws.management::cloudwatchlogs(
          config = list(max_retries = 0, connect_timeout = 2),
          region = "us-east-1"
        )
      }
      if (!cloudwatch$stream_created) {
        # The stream can already exist if an earlier request to create it
        # succeeded but its response never arrived
        tryCatch(
          cloudwatch$client$create_log_stream(
            logGroupName = cloudwatch_log_group,
            logStreamName = cloudwatch$stream
          ),
          error = function(err) {
            if (!grepl("ResourceAlreadyExists", conditionMessage(err))) {
              stop(err)
            }
          }
        )
        cloudwatch$stream_created <- TRUE
      }
      cloudwatch$client$put_log_events(
        logGroupName = cloudwatch_log_group,
        logStreamName = cloudwatch$stream,
        logEvents = lapply(lines, function(line) {
          list(timestamp = timestamp, message = line)
        })
      )
    }),
    error = function(err) {
      logger::log_warn(
        msg = "Failed to upload logs to CloudWatch",
        error = conditionMessage(err)
      )
    }
  )
  invisible(NULL)
}

# Print each record to stdout and, if enabled, upload it to CloudWatch.
# logger's default appender writes to stderr
appender_stdout_cloudwatch <- function(lines) {
  cat(lines, sep = "\n")
  cloudwatch_upload(lines)
}

# Define formatter, layout, and appender
logger::log_formatter(logger::formatter_json)
logger::log_layout(logger::layout_json_parser(fields = "level"))
logger::log_appender(appender_stdout_cloudwatch)

# Log uncaught errors outside of request handling (e.g. a model failing to
# load at startup) before exiting. Without the explicit q(), Rscript would
# carry on to the next expression after running this handler. Skipped in
# interactive sessions, where quitting on every error would be disruptive
if (!interactive()) {
  options(error = function() {
    logger::log_error(msg = trimws(geterrmessage()))
    q(save = "no", status = 1)
  })
}

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

# Build a traceback string for the log. Prefer the full rlang backtrace when
# the error has one, fall back to the call that raised it, otherwise NA
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
