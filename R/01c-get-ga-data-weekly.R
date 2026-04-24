# Purpose: Weekly Update. Download raw data from GA4 and save it locally (caching)

# Purpose: Weekly incremental GA4 raw-data update into *_master.rds
source("R/00-setup.R")

# set end date to yesterday by default to avoid partial data for the current day
end_date <- as.character(Sys.Date() - 1)

append_distinct <- function(existing, new_data, key_cols) {
  bind_rows(existing, new_data) |>
    distinct(across(all_of(key_cols)), .keep_all = TRUE) |>
    arrange(date)
}

# read current base data from 01a-get-ga-data.R
daily_usage_raw <- readRDS(file.path(DATA_RAW, "daily_usage_raw.rds"))
geo_data_raw <- readRDS(file.path(DATA_RAW, "geo_data_raw.rds"))
tech_data_raw <- readRDS(file.path(DATA_RAW, "tech_data_raw.rds"))
download_data_raw <- readRDS(file.path(DATA_RAW, "download_data_raw.rds"))

# record number of rows before adding new data
old_daily_rows <- nrow(daily_usage_raw)
old_geo_rows <- nrow(geo_data_raw)
old_tech_rows <- nrow(tech_data_raw)
old_download_rows <- nrow(download_data_raw)

# compute next start date directly
daily_start <- as.character(
  max(as.Date(daily_usage_raw$date), na.rm = TRUE) + 1
)
geo_start <- as.character(max(as.Date(geo_data_raw$date), na.rm = TRUE) + 1)
tech_start <- as.character(max(as.Date(tech_data_raw$date), na.rm = TRUE) + 1)
download_start <- as.character(
  max(as.Date(download_data_raw$date), na.rm = TRUE) + 1
)

# DAILY
daily_new <- if (as.Date(daily_start) <= as.Date(end_date)) {
  ga_data(
    propertyId = GA_PROPERTY_ID,
    date_range = c(daily_start, end_date),
    metrics = c(
      "totalUsers",
      "sessions",
      "averageSessionDuration",
      "userEngagementDuration"
    ),
    dimensions = c("date", "pageTitle", "pagePath"),
    limit = -1
  )
} else {
  daily_usage_raw[0, ]
}

daily_usage_raw <- append_distinct(
  daily_usage_raw,
  daily_new,
  key_cols = c("date", "pageTitle", "pagePath")
)

# GEO
geo_new <- if (as.Date(geo_start) <= as.Date(end_date)) {
  ga_data(
    propertyId = GA_PROPERTY_ID,
    date_range = c(geo_start, end_date),
    metrics = c("totalUsers"),
    dimensions = c(
      "date",
      "pageTitle",
      "pagePath",
      "country",
      "city",
      "region"
    ),
    limit = -1
  )
} else {
  geo_data_raw[0, ]
}

geo_data_raw <- append_distinct(
  geo_data_raw,
  geo_new,
  key_cols = c("date", "pageTitle", "pagePath", "country", "city", "region")
)

# TECH
tech_new <- if (as.Date(tech_start) <= as.Date(end_date)) {
  ga_data(
    propertyId = GA_PROPERTY_ID,
    date_range = c(tech_start, end_date),
    metrics = c("totalUsers"),
    dimensions = c(
      "date",
      "pageTitle",
      "pagePath",
      "deviceCategory",
      "operatingSystem",
      "browser",
      "screenResolution"
    ),
    limit = -1
  )
} else {
  tech_data_raw[0, ]
}

tech_data_raw <- append_distinct(
  tech_data_raw,
  tech_new,
  key_cols = c(
    "date",
    "pageTitle",
    "pagePath",
    "deviceCategory",
    "operatingSystem",
    "browser",
    "screenResolution"
  )
)

# DOWNLOAD
download_new <- if (as.Date(download_start) <= as.Date(end_date)) {
  ga_data(
    propertyId = GA_PROPERTY_ID,
    date_range = c(download_start, end_date),
    metrics = c("eventCount"),
    dimensions = c(
      "date",
      "pageTitle",
      "pagePath",
      "eventName",
      "fileName",
      "customEvent:event_label"
    ),
    dim_filters = ga_data_filter(eventName == "file_download"),
    limit = -1
  ) |>
    rename(event_label = `customEvent:event_label`) |>
    mutate(file_label = coalesce(na_if(fileName, ""), na_if(event_label, "")))
} else {
  download_data_raw[0, ]
}

download_data_raw <- append_distinct(
  download_data_raw,
  download_new,
  key_cols = c("date", "pageTitle", "pagePath", "eventName", "file_label")
)

# overwrite 01a raw files with updated data
saveRDS(daily_usage_raw, file = file.path(DATA_RAW, "daily_usage_raw.rds"))
saveRDS(geo_data_raw, file = file.path(DATA_RAW, "geo_data_raw.rds"))
saveRDS(tech_data_raw, file = file.path(DATA_RAW, "tech_data_raw.rds"))
saveRDS(download_data_raw, file = file.path(DATA_RAW, "download_data_raw.rds"))

# keep combined RData file in sync
save(
  daily_usage_raw,
  geo_data_raw,
  tech_data_raw,
  download_data_raw,
  file = file.path(DATA_RAW, "ga_raw_data.RData")
)

# run summary, check how many new rows were added for each dataset, and print a summary table
tibble(
  dataset = c("daily", "geo", "tech", "download"),
  start_date = c(daily_start, geo_start, tech_start, download_start),
  end_date = end_date,
  fetched_rows = c(
    nrow(daily_new),
    nrow(geo_new),
    nrow(tech_new),
    nrow(download_new)
  ),
  final_rows = c(
    nrow(daily_usage_raw),
    nrow(geo_data_raw),
    nrow(tech_data_raw),
    nrow(download_data_raw)
  )
)
