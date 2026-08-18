# bureau-labor-statistics

Ingests U.S. Bureau of Labor Statistics Local Area Unemployment Statistics
(LAUS) county- and state-level annual unemployment rate, plus the national
unemployment rate, for [PopHIVE](https://pophive.org).

## Output

`standard/data_county.csv.gz` — `geography` (5-digit county FIPS), `time`
(`YYYY-12-31`, the latest available LAUS annual-average year), and
`bls_pct_unemployment` (proportion, 0-1).

`standard/data_state.csv.gz` — same columns, but `geography` is either a
2-digit state FIPS code or `"00"` for the national row. Covers the 50
states, DC, and Puerto Rico — LAUS's state-equivalent program doesn't
publish estimates for American Samoa, Guam, the Northern Mariana Islands,
the U.S. Virgin Islands, or the Minor Outlying Islands. The national row
comes from BLS's standard CPS-based unemployment rate (series
`LNU04000000`), since LAUS itself has no national series.

## Setup

Requires a free BLS API key: sign up at
https://data.bls.gov/registrationEngine/ (instant, no approval wait), then
add it to `~/.Renviron`:

```
BLS_API_KEY="your-key-here"
```

An unregistered key works for basic requests but caps out at 25 queries/day
and can't request `annualaverage` data — a full pull needs ~69 batched
requests (50 series each: ~66 for counties, 2 for states/territories, 1
for the national series), so a registered key (500/day) is required.

## Usage

```r
source("ingest.R")
```

## Consumed by

[PopHIVE/Ingest](https://github.com/PopHIVE/Ingest)'s
`data/bls_laus/ingest.R` pulls this repo's standard files and
`measure_info.json` directly from GitHub, following the same pattern as
`PopHIVE/county_health_rankings`. As of this writing, Ingest only pulls
`data_county.csv.gz` — wiring up `data_state.csv.gz` downstream (in
Ingest, and then in `PopHIVE/us-rates`) is a separate step.
