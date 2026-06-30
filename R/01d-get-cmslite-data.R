# Copyright 2026 Province of British Columbia
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

source("R/00-setup.R")

library(aws.s3)

# Step 1: Read required environment variables once
env_keys <- c(
  "AWS_ACCESS_KEY_ID",
  "AWS_SECRET_ACCESS_KEY",
  "AWS_DEFAULT_REGION",
  "BCSTATS_S3_BUCKET",
  "BCSTATS_S3_PREFIX"
)

env_values <- Sys.getenv(env_keys, unset = NA_character_)
names(env_values) <- env_keys

# Step 2: Validate missing values
missing_env <- names(env_values)[is.na(env_values) | env_values == ""]
if (length(missing_env) > 0) {
  stop(
    sprintf(
      "Missing environment variables: %s",
      paste(missing_env, collapse = ", ")
    ),
    call. = FALSE
  )
}

# Step 3: Assign name variables from environment values for easier reference.
bucket <- env_values[["BCSTATS_S3_BUCKET"]]
prefix <- env_values[["BCSTATS_S3_PREFIX"]]
region <- env_values[["AWS_DEFAULT_REGION"]]

# Step 4: Ensure raw-data directory for cms_lite is available for this stage.
dir.create(
  file.path(DATA_RAW, "cms_lite"),
  recursive = TRUE,
  showWarnings = FALSE
)

# Step 5: List objects from the target S3 prefix.
objects <- get_bucket(
  bucket = bucket,
  prefix = prefix,
  region = region
)

# Step 6: Convert S3 object metadata to a table and keep only CSV data files.
file_index <- data.frame(
  key = vapply(objects, function(x) as.character(x$Key), character(1)),
  size = vapply(objects, function(x) as.numeric(x$Size), numeric(1)),
  last_modified = as.POSIXct(
    vapply(objects, function(x) as.character(x$LastModified), character(1)),
    format = "%Y-%m-%dT%H:%M:%OSZ",
    tz = "UTC"
  ),
  stringsAsFactors = FALSE
)

data_files <- file_index |>
  filter(
    !is.na(key),
    size > 0,
    str_starts(key, prefix),
    str_detect(key, "\\.csv$")
  )

if (nrow(data_files) == 0) {
  stop("No CSV files found in S3 prefix.", call. = FALSE)
}

# Step 7: Download all CSVs into DATA_RAW/cms_lite.
walk(data_files$key, \(key) {
  save_object(
    object = key,
    bucket = bucket,
    file = file.path(file.path(DATA_RAW, "cms_lite"), basename(key)),
    region = region
  )
})

message(sprintf(
  "Downloaded %s CSV file(s) to: %s",
  nrow(data_files),
  file.path(DATA_RAW, "cms_lite")
))
