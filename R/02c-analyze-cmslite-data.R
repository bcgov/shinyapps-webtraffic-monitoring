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

# Purpose: Analyze CMS Lite reports by site (in-memory only).

if (!exists("required_packages")) {
  source("R/00-setup.R")
}

library(dplyr)
library(readr)
library(stringr)
library(purrr)

raw_dir <- file.path(DATA_RAW, "cms_lite")

# Shared helper functions
source("R/functions/cmslite-analysis-functions.R")

##### ============================================================
##### PART 1: outcomes.bcstats.gov.bc.ca (5 reports)
##### ============================================================

outcomes_pageview <- load_report(raw_dir, "outcomes", "pageview")
outcomes_click <- load_report(raw_dir, "outcomes", "click")
outcomes_referurl <- load_report(raw_dir, "outcomes", "referurl")
outcomes_platform <- load_report(raw_dir, "outcomes", "platform")
outcomes_geoloc <- load_report(raw_dir, "outcomes", "geoloc")


outcomes_analysis <- list(
  pageview = analyze_pageview(outcomes_pageview),
  click = analyze_click(outcomes_click),
  referurl = analyze_referurl(outcomes_referurl),
  platform = analyze_platform(outcomes_platform),
  geoloc = analyze_geoloc(outcomes_geoloc)
)

##### ============================================================
##### PART 2: antiracism.gov.bc.ca (5 reports)
##### ============================================================

antiracism_pageview <- load_report(raw_dir, "antiracism", "pageview")
antiracism_click <- load_report(raw_dir, "antiracism", "click")
antiracism_referurl <- load_report(raw_dir, "antiracism", "referurl")
antiracism_platform <- load_report(raw_dir, "antiracism", "platform")
antiracism_geoloc <- load_report(raw_dir, "antiracism", "geoloc")


antiracism_analysis <- list(
  pageview = analyze_pageview(antiracism_pageview),
  click = analyze_click(antiracism_click),
  referurl = analyze_referurl(antiracism_referurl),
  platform = analyze_platform(antiracism_platform),
  geoloc = analyze_geoloc(antiracism_geoloc)
)

##### ============================================================
##### PART 3: www2.gov.bc.ca/gov/content/data/statistics (8 reports)
##### ============================================================

govstats_pageview <- load_report(raw_dir, "govstats", "pageview")
govstats_click <- load_report(raw_dir, "govstats", "click")
govstats_referurl <- load_report(raw_dir, "govstats", "referurl")
govstats_platform <- load_report(raw_dir, "govstats", "platform")
govstats_geoloc <- load_report(raw_dir, "govstats", "geoloc")
govstats_asset <- load_report(raw_dir, "govstats", "asset")
govstats_search <- load_report(raw_dir, "govstats", "search")
govstats_google <- load_report(raw_dir, "govstats", "google")

govstats_analysis <- list(
  pageview = analyze_pageview(govstats_pageview),
  click = analyze_click(govstats_click),
  referurl = analyze_referurl(govstats_referurl),
  platform = analyze_platform(govstats_platform),
  geoloc = analyze_geoloc(govstats_geoloc),
  asset = analyze_asset(govstats_asset),
  search = analyze_search(govstats_search),
  google = analyze_google(govstats_google)
)

##### ============================================================
##### FINAL OBJECT (in-memory nested list, for inspection)
##### ============================================================

cmslite_analysis <- list(
  outcomes = outcomes_analysis,
  antiracism = antiracism_analysis,
  govstats = govstats_analysis
)

##### ============================================================
##### DASHBOARD PREP: tidy combined tables (one row-bound table
##### per metric, tagged with a `site` column)
##### ============================================================

# Pull a nested table (e.g. c("pageview", "daily")) from each site's analysis,
# add a `site` column, and row-bind. Sites lacking that path are skipped, so
# govstats-only reports (asset/search/google) bind cleanly.
combine_sites <- function(analysis, path) {
  imap(analysis, \(site_analysis, site) {
    tbl <- purrr::pluck(site_analysis, !!!path)
    if (is.null(tbl)) {
      return(NULL)
    }
    mutate(tbl, site = site, .before = 1)
  }) |>
    list_rbind()
}

cmslite_tables <- list(
  cmslite_daily = combine_sites(cmslite_analysis, c("pageview", "daily")),
  cmslite_top_pages = combine_sites(
    cmslite_analysis,
    c("pageview", "top_pages")
  ),
  cmslite_clicks_daily = combine_sites(cmslite_analysis, c("click", "daily")),
  cmslite_top_targets = combine_sites(
    cmslite_analysis,
    c("click", "top_targets")
  ),
  cmslite_top_referrers = combine_sites(
    cmslite_analysis,
    c("referurl", "top_referrers")
  ),
  cmslite_by_os = combine_sites(cmslite_analysis, c("platform", "by_os")),
  cmslite_by_geo = combine_sites(cmslite_analysis, c("geoloc", "by_geo")),
  cmslite_asset_downloads_daily = combine_sites(
    cmslite_analysis,
    c("asset", "daily")
  ),
  cmslite_top_assets = combine_sites(
    cmslite_analysis,
    c("asset", "top_assets")
  ),
  cmslite_search_terms = combine_sites(
    cmslite_analysis,
    c("search", "top_terms")
  ),
  cmslite_google_queries = combine_sites(
    cmslite_analysis,
    c("google", "top_queries")
  )
)

##### ============================================================
##### WRITE DASHBOARD CSVs
##### Prefixed `cmslite_` to avoid colliding with GA tables in OUTPUT_TABLES.
##### Comment out the loop below to avoid overwriting CSVs during development.
##### ============================================================

imap(cmslite_tables, \(x, name) {
  if (!is.null(x) && nrow(x) > 0) {
    write_csv(x, file = file.path(OUTPUT_TABLES, paste0(name, ".csv")))
  }
})

cmslite_analysis
