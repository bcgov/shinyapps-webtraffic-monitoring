# Purpose: Analyze shinyapps.io concurrency metrics

source("R/00-setup.R")

# Load data
all_concurrency <- readRDS(file.path(DATA_RAW, "shinyapps_concurrency.rds"))

# showMetrics interval meanings:
# "1m" = one-minute buckets, "5m" = five-minute buckets, "1h" = hourly buckets.
# The API returns already-aggregated counts for that time bucket; we do not sum
# within the bucket here, we only summarize across buckets (max/min/mean).

# Summary stats per app + interval
concurrency_summary <- all_concurrency |>
  summarize(
    max_concurrent = max(concurrent_users, na.rm = TRUE),
    min_concurrent = min(concurrent_users, na.rm = TRUE),
    avg_concurrent = mean(concurrent_users, na.rm = TRUE),
    busy_time = time[which.max(concurrent_users)],
    .by = c(app_name, interval)
  ) |>
  group_by(interval) |>
  arrange(desc(max_concurrent), .by_group = TRUE) |>
  ungroup()


#  WRITE SUMMARY CSVs
write_csv(concurrency_summary, file.path(OUTPUT_TABLES, "concurrency_summary.csv"))




