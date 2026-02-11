<!-- badges: start -->
[![Lifecycle:Experimental](https://img.shields.io/badge/Lifecycle-Experimental-339999)](https://github.com/bcgov/repomountie/blob/master/doc/lifecycle-badges.md)
[![License:Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/license/apache-2-0/)
<!-- badges: end -->

## Project Description

R code to produce web analytics summaries for BC Stats ShinyApps in production.

This repository contains **code only**. Data and outputs live on secure LAN storage and are accessed via [`safepaths`](https://github.com/bcgov/safepaths).

## Prerequisites

- **R**: 4.0.0+ (recommended: match your team’s standard)
- **Network access**: VPN connection required to access LAN storage
- **Access/credentials**:
  - Google Analytics (GA4) API access may require credentials (API keys / OAuth)
  - Shiny metrics rely on `rsconnect` access where applicable

## Secure Access & Credentials

Secrets must never be committed. Use a **local-only** configuration file for credentials.

- Store credentials locally in `~/.Renviron` (see `.Renviron.example`)
- Ensure the file is listed in `.gitignore`
- Raw API pulls are saved locally (e.g., as `.RData`) to avoid repeatedly calling APIs during development

### Required environment variables

```
SAFEPATHS_NETWORK_PATH
GA_PROPERTY_ID
GA_SERVICE_EMAIL
GA_SERVICE_KEY
SHINY_ACC_NAME
SHINY_TOKEN
SHINY_SECRET
```

### Optional environment variables

```
GA_DATE_START
GA_DATE_END
```

## Data Sources

- **Google Analytics (GA4) API**
- **Shiny `rsconnect::showMetrics()` API**

## Data Storage Structure (LAN)

All data is stored in a hierarchical network folder structure accessed through `safepaths`.

```
{LAN_FOLDER}/0. Misc/Data Science Tooling/web-hosting-and-dashboards/shinyapps_webtraffic_monitoring/
├── data/
│   └──                  # Raw API pulls / raw exports
└── outputs/
    ├── tables/          # Output tables (CSV / Excel)
    └── visuals/         # Output charts / figures
```

## Installation

Install required packages:

```r
install.packages(c(
  "googleAnalyticsR",
  "tidyverse",
  "lubridate",
  "zoo",
  "janitor",
  "slider",
  "rsconnect",
  "safepaths",
  "glue"
))

remotes::install_github("bcgov/safepaths")
```

### Configure safepaths

Follow the `safepaths` documentation: https://github.com/bcgov/safepaths

You will need the project’s specific LAN path key from the maintainers.

## Quick start (typical workflow)

1. Connect to VPN.
2. Configure `safepaths` (one-time setup).
3. Set up local credentials (GA4 / rsconnect) using the local config approach above.
4. Run the pipeline scripts:
   - Download raw data (GA4 / rsconnect)
   - Save cached raw data (e.g., `.RData`)
   - Build processed datasets
   - Produce tables and visuals in `outputs/`

## Outputs

Typical outputs include:

- Tables (CSV / Excel)
  - weekly/monthly active users (or sessions, depending on availability)
  - rolling averages
  - recent week/month snapshots
  - geography breakdowns
  - device/OS/browser breakdowns
  - download event counts
  - concurrent use

- Visuals
  - trend charts
  - app-to-app comparison charts
  - concurrency plots (time series + distributions)

## Guiding Principles

1. This GitHub repository stores only code. All data resides on secure LAN storage accessed via `safepaths`.
2. The analysis uses data containing no Personal Information (PI) or other sensitive information.
3. The analytic code is developed openly to promote transparency and reproducibility.

## Contributing

See [CONTRIBUTING](CONTRIBUTING.md).

This project follows the [Contributor Code of Conduct](CODE_OF_CONDUCT.md).

## Contact

For access questions or the `safepaths` configuration key, contact:
- Zhijia Ju: https://github.com/Anakin2009
- Or open an issue in this repository

## License

Copyright 2026 Province of British Columbia

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
