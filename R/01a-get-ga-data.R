# Purpose: Download raw data from GA4 and save it locally (caching)

source("R/00-setup.R")


# Get daily usage data (for timeline & rolling averages)
daily_usage_raw <- ga_data(
  propertyId = GA_PROPERTY_ID,
  date_range = c(GA_DATE_START, GA_DATE_END),
  metrics = c(
    "totalUsers",
    "sessions",
    "averageSessionDuration",
    "userEngagementDuration"
  ),
  dimensions = c("date", "pageTitle", "pagePath"),
  limit = -1
)

# getch user location data
geo_data_raw <- ga_data(
  propertyId = GA_PROPERTY_ID,
  date_range = c(GA_DATE_START, GA_DATE_END),
  metrics = c("totalUsers"),
  dimensions = c("pageTitle", "pagePath", "country", "city", "region"),
  limit = -1
)

# get tech specs
tech_data_raw <- ga_data(
  propertyId = GA_PROPERTY_ID,
  date_range = c(GA_DATE_START, GA_DATE_END),
  metrics = c("totalUsers"),
  dimensions = c(
    "pageTitle",
    "pagePath",
    "deviceCategory",
    "operatingSystem",
    "browser",
    "screenResolution"
  ),
  limit = -1
)

# get downloads (file downloads)
download_data_raw <- ga_data(
  propertyId = GA_PROPERTY_ID,
  date_range = c(GA_DATE_START, GA_DATE_END),
  metrics = c("eventCount"),
  dimensions = c("pageTitle", "pagePath", "eventName", "fileName"),
  dim_filters = ga_data_filter(eventName == "file_download"),
  limit = -1
)

# Save raw data to an RData file so we don't have to hit the API repeatedly while coding
save(
  daily_usage_raw,
  geo_data_raw,
  tech_data_raw,
  download_data_raw,
  file = file.path(DATA_RAW, "ga_raw_data.RData")
)

# Also save each table as .rds for simpler reuse
saveRDS(daily_usage_raw, file = file.path(DATA_RAW, "daily_usage_raw.rds"))
saveRDS(geo_data_raw, file = file.path(DATA_RAW, "geo_data_raw.rds"))
saveRDS(tech_data_raw, file = file.path(DATA_RAW, "tech_data_raw.rds"))
saveRDS(download_data_raw, file = file.path(DATA_RAW, "download_data_raw.rds"))

message("Data fetched and saved to 'data/ga_raw_data.RData' and data/*.rds")