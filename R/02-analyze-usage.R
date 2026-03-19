# Purpose: Generate the "Snapshot" report for Business Owners

source("R/00-setup.R")

# Load the data we fetched in 01a-get-ga-data.R
load(file.path(DATA_RAW, "ga_raw_data.RData"))

# load rds files if you want to work with individual tables:
# daily_usage_raw <- readRDS(file.path(DATA_RAW, "daily_usage_raw.rds"))
# geo_data_raw <- readRDS(file.path(DATA_RAW, "geo_data_raw.rds"))
# tech_data_raw <- readRDS(file.path(DATA_RAW, "tech_data_raw.rds"))
# download_data_raw <- readRDS(file.path(DATA_RAW, "download_data_raw.rds"))

# Only 11 apps are kept since other apps are archived or private
apps_keep <- c(
  "LAEP",
  "Student Outcomes",
  "popApp",
  "BC Small Business",
  "LFS app",
  "Economic-Indicators",
  "BCDS-DIP Linkage Rates",
  "Household Projections",
  "Country Trade Profiles",
  "Interprovincial Migration",
  "BC Retail Sales"
)

# Filter raw data to only include these apps, add column details
daily_usage_raw <- daily_usage_raw |>
  filter(pageTitle %in% apps_keep)
# column definitions:
# - date: Reporting date (YYYY-MM-DD). Each row is one app on one day.
# - pageTitle: App name
# - totalUsers: Unique users for that app on that date (device/cookie-based).
#              Caution: do NOT sum across days to get weekly/monthly unique users.
#              Summing across days yields “total daily uniques,” which can double-count.
# - sessions: Number of sessions (visits) for that app on that date.
#            A session ends after ~30 minutes of inactivity; returning later counts again.
# - averageSessionDuration: Mean session length in seconds.
#                           GA4 can include background time; may overstate active use.
# - userEngagementDuration: Total engaged time in seconds for that app on that date.
#                           This is a SUM, not an average. It counts foreground time.
#                           To estimate average engaged time per user:
#                           avg_engaged_seconds = userEngagementDuration / totalUsers

geo_data_raw <- geo_data_raw |>
  filter(pageTitle %in% apps_keep)

tech_data_raw <- tech_data_raw |>
  filter(pageTitle %in% apps_keep)

download_data_raw <- download_data_raw |>
  filter(pageTitle %in% apps_keep)


# 1. CLEANING
# Add week/month buckets for rollups; keep original daily granularity
daily_usage_clean <- daily_usage_raw |>
  mutate(
    date = as.Date(date),
    week = floor_date(date, unit = "week", week_start = 1),
    month = floor_date(date, unit = "month")
  )

# Rolling average windows (adjust as needed)
rolling_week_window <- 4
rolling_month_window <- 3

# 2. WEEKLY + MONTHLY ROLLUPS
# Weekly: totals for usage, weighted durations per app-week
weekly_usage <- daily_usage_clean |>
  summarize(
    total_daily_users = sum(totalUsers, na.rm = TRUE),
    total_sessions = sum(sessions, na.rm = TRUE),

    avg_session_duration = weighted.mean(
      averageSessionDuration,
      w = sessions,
      na.rm = TRUE
    ),

    # Avg engaged seconds per user (weekly)
    avg_engaged_seconds_per_user = sum(userEngagementDuration, na.rm = TRUE) /
      pmax(sum(totalUsers, na.rm = TRUE), 1),

    .by = c(pageTitle, week)
  ) |>
  arrange(pageTitle, week) |>
  group_by(pageTitle) |>
  mutate(
    rolling_users_week = slide_dbl(
      total_daily_users,
      mean,
      .before = rolling_week_window - 1,
      .complete = TRUE
    ),
    rolling_sessions_week = slide_dbl(
      total_sessions,
      mean,
      .before = rolling_week_window - 1,
      .complete = TRUE
    )
  ) |>
  ungroup()

# Monthly: totals for usage, weighted durations per app-month
monthly_usage <- daily_usage_clean |>
  summarize(
    total_daily_users = sum(totalUsers, na.rm = TRUE),
    total_sessions = sum(sessions, na.rm = TRUE),

    avg_session_duration = weighted.mean(
      averageSessionDuration,
      w = sessions,
      na.rm = TRUE
    ),

    # Avg engaged seconds per user (monthly)
    avg_engaged_seconds_per_user = sum(userEngagementDuration, na.rm = TRUE) /
      pmax(sum(totalUsers, na.rm = TRUE), 1),

    .by = c(pageTitle, month)
  ) |>
  arrange(pageTitle, month) |>
  group_by(pageTitle) |>
  mutate(
    rolling_users_month = slide_dbl(
      total_daily_users,
      mean,
      .before = rolling_month_window - 1,
      .complete = TRUE
    ),
    rolling_sessions_month = slide_dbl(
      total_sessions,
      mean,
      .before = rolling_month_window - 1,
      .complete = TRUE
    )
  ) |>
  ungroup()

# 3. SUMMARY TABLES (per app)
# Latest week/month stats + rolling averages in one row per app
usage_summary <- weekly_usage |>
  filter(week == max(week), .by = pageTitle) |>
  select(
    pageTitle,
    recent_week_users = total_daily_users,
    recent_week_sessions = total_sessions,
    rolling_users_week,
    rolling_sessions_week,
    avg_session_duration,
    avg_engaged_seconds_per_user
  ) |>
  left_join(
    monthly_usage |>
      filter(month == max(month), .by = pageTitle) |>
      select(
        pageTitle,
        recent_month_users = total_daily_users,
        recent_month_sessions = total_sessions,
        rolling_users_month,
        rolling_sessions_month
      ),
    by = "pageTitle"
  )

# Top 10 locations per app by total users
location_summary <- geo_data_raw |>
  summarize(
    total_users = sum(totalUsers, na.rm = TRUE),
    .by = c(pageTitle, country, region, city)
  ) |>
  arrange(pageTitle, desc(total_users)) |>
  group_by(pageTitle) |>
  slice_head(n = 10) |>
  ungroup()

# Tech profile per app (device/OS/browser)
tech_summary <- tech_data_raw |>
  summarize(
    total_users = sum(totalUsers, na.rm = TRUE),
    .by = c(pageTitle, deviceCategory, operatingSystem, browser)
  ) |>
  arrange(pageTitle, desc(total_users))

# Tech profile summaries (per app) with percentages
device_summary <- tech_data_raw |>
  summarize(
    total_users = sum(totalUsers, na.rm = TRUE),
    .by = c(pageTitle, deviceCategory)
  ) |>
  mutate(
    pct_users = total_users / sum(total_users),
    .by = pageTitle
  ) |>
  arrange(pageTitle, desc(total_users))

os_summary <- tech_data_raw |>
  summarize(
    total_users = sum(totalUsers, na.rm = TRUE),
    .by = c(pageTitle, operatingSystem)
  ) |>
  mutate(
    pct_users = total_users / sum(total_users),
    .by = pageTitle
  ) |>
  arrange(pageTitle, desc(total_users))

browser_summary <- tech_data_raw |>
  summarize(
    total_users = sum(totalUsers, na.rm = TRUE),
    .by = c(pageTitle, browser)
  ) |>
  mutate(
    pct_users = total_users / sum(total_users),
    .by = pageTitle
  ) |>
  arrange(pageTitle, desc(total_users))


# Downloads per app and file
download_summary <- download_data_raw |>
  select(-fileName, -event_label) |>
  summarize(
    total_downloads = sum(eventCount, na.rm = TRUE),
    .by = c(pageTitle, file_label)
  ) |>
  arrange(desc(total_downloads))


# Compare apps: share of users and rank (based on recent week users)
usage_comparison <- usage_summary |>
  mutate(
    share_recent_week_users = recent_week_users /
      sum(recent_week_users, na.rm = TRUE),
    rank_recent_week_users = min_rank(desc(recent_week_users))
  ) |>
  select(
    pageTitle,
    recent_week_users,
    share_recent_week_users,
    rank_recent_week_users
  ) |>
  arrange(rank_recent_week_users)


#  OUTPUT LISTS
summary_tables <- list(
  usage_summary = usage_summary,
  location_summary = location_summary,
  tech_summary = tech_summary,
  download_summary = download_summary,
  usage_comparison = usage_comparison,
  weekly_usage = weekly_usage
)

tech_breakdowns <- list(
  device_summary = device_summary,
  os_summary = os_summary,
  browser_summary = browser_summary
)

#  WRITE SUMMARY CSVs
# comment out the imap loops below to avoid overwriting CSVs during development

# imap(summary_tables, \(x, name) {
#   if (!is.null(x)) {
#     write_csv(x, file = file.path(OUTPUT_TABLES, paste0(name, ".csv")))
#   }
# })

# imap(tech_breakdowns, \(x, name) {
#   write_csv(x, file = file.path(OUTPUT_TABLES, paste0(name, ".csv")))
# })
