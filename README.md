# bureau-labor-statistics

Ingests U.S. Bureau of Labor Statistics Local Area Unemployment Statistics
(LAUS) county-level annual unemployment rate for [PopHIVE](https://pophive.org).

## Output

`standard/data_county.csv.gz` — `geography` (5-digit county FIPS), `time`
(`YYYY-12-31`, the latest available LAUS annual-average year), and
`bls_pct_unemployment` (proportion, 0-1).

## Setup

Requires a free BLS API key: sign up at
https://data.bls.gov/registrationEngine/ (instant, no approval wait), then
add it to `~/.Renviron`:

```
BLS_API_KEY="your-key-here"
```

An unregistered key works for basic requests but caps out at 25 queries/day
and can't request `annualaverage` data — a full county-level pull needs
~66 batched requests (50 series each), so a registered key (500/day) is
required.

## Usage

```r
source("ingest.R")
```

## Consumed by

[PopHIVE/Ingest](https://github.com/PopHIVE/Ingest)'s
`data/bls_laus/ingest.R` pulls this repo's `standard/data_county.csv.gz`
and `measure_info.json` directly from GitHub, following the same pattern
as `PopHIVE/county_health_rankings`.
