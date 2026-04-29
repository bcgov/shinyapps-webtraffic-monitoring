# Purpose: Weekly Update. Download raw data from GA4 and save it locally (caching)

# Purpose: Weekly incremental GA4 raw-data update into raw data files.
source("R/00-setup.R")

# set end date to yesterday by default to avoid partial data for the current day
end_date <- as.character(Sys.Date() - 1)

# set weekly end date to the last completed Sunday (ISO week default: Mon-Sun)
day_of_week_iso <- as.integer(format(as.Date(end_date), "%u")) # 1=Mon ... 7=Sun
end_date_weekly <- as.character(as.Date(end_date) - day_of_week_iso)

# Helper function to append and deduplicate rows
append_distinct <- function(existing, new_data, key_cols) {
  bind_rows(existing, new_data) |>
    distinct(across(all_of(key_cols)), .keep_all = TRUE) |>
    arrange(across(any_of(c("date", "isoYearIsoWeek"))))
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
      "activeUsers",
      "sessions",
      "engagedSessions",
      "engagementRate",
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

# WEEKLY
weekly_usage_raw <- readRDS(file.path(DATA_RAW, "weekly_usage_raw.rds"))
old_weekly_rows <- nrow(weekly_usage_raw)

# Note: Because 'daily_start' could land mid-week, sending it directly to the API
# would result in GA4 calculating distinct users for only a partial week.
# Subtracting 7 days ensures the date range perfectly swallows the target Monday-Sunday
# period, forcing GA4 to calculate a true 7-day unique user count.
weekly_start <- as.character(as.Date(daily_start) - 7)

weekly_new <- if (as.Date(weekly_start) <= as.Date(end_date_weekly)) {
  ga_data(
    propertyId = GA_PROPERTY_ID,
    date_range = c(weekly_start, end_date_weekly),
    metrics = c(
      "totalUsers",
      "activeUsers",
      "sessions",
      "engagedSessions",
      "engagementRate",
      "averageSessionDuration",
      "userEngagementDuration"
    ),
    dimensions = c("isoYearIsoWeek", "pageTitle", "pagePath"),
    limit = -1
  )
} else {
  weekly_usage_raw[0, ]
}

weekly_usage_raw <- append_distinct(
  weekly_usage_raw,
  weekly_new,
  key_cols = c("isoYearIsoWeek", "pageTitle", "pagePath") # Use isoYearIsoWeek as the key
)

# GEO
geo_new <- if (as.Date(geo_start) <= as.Date(end_date)) {
  ga_data(
    propertyId = GA_PROPERTY_ID,
    date_range = c(geo_start, end_date),
    metrics = c("totalUsers", "activeUsers"),
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
    metrics = c("totalUsers", "activeUsers"),
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
saveRDS(weekly_usage_raw, file = file.path(DATA_RAW, "weekly_usage_raw.rds"))
saveRDS(geo_data_raw, file = file.path(DATA_RAW, "geo_data_raw.rds"))
saveRDS(tech_data_raw, file = file.path(DATA_RAW, "tech_data_raw.rds"))
saveRDS(download_data_raw, file = file.path(DATA_RAW, "download_data_raw.rds"))

# # keep combined RData file in sync
# save(
#   daily_usage_raw,
#   weekly_usage_raw,
#   geo_data_raw,
#   tech_data_raw,
#   download_data_raw,
#   file = file.path(DATA_RAW, "ga_raw_data.RData")
# )

# run summary, check how many new rows were added for each dataset, and print a summary table
tibble(
  dataset = c("daily", "weekly", "geo", "tech", "download"),
  start_date = c(
    daily_start,
    weekly_start,
    geo_start,
    tech_start,
    download_start
  ),
  end_date = c(end_date, end_date_weekly, end_date, end_date, end_date),
  existing_rows = c(
    old_daily_rows,
    old_weekly_rows,
    old_geo_rows,
    old_tech_rows,
    old_download_rows
  ),
  rows_downloaded = c(
    nrow(daily_new),
    nrow(weekly_new),
    nrow(geo_new),
    nrow(tech_new),
    nrow(download_new)
  ),
  final_rows = c(
    nrow(daily_usage_raw),
    nrow(weekly_usage_raw),
    nrow(geo_data_raw),
    nrow(tech_data_raw),
    nrow(download_data_raw)
  )
)
