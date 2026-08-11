# =============================================================================
# BLS Local Area Unemployment Statistics (LAUS) — annual county unemployment
# rate. Source: U.S. Bureau of Labor Statistics, api.bls.gov v2.
#
# Series ID format confirmed live: "LAUCN" + 5-digit county FIPS +
# "00000000" + "03" (measure code 03 = unemployment rate; county series are
# never seasonally adjusted). annualaverage=TRUE + a registered key are
# needed to get period "M13" (annual average) rows -- unregistered access
# truncates to the ~30 most recent months only, with no M13 rows at all.
#
# Validated against County Health Rankings' chr_unemployment: same BLS LAUS
# rate series, same definition (civilian labor force, ages 16+), CHR&R
# applies no further adjustment. The two don't match exactly even at the
# correct vintage-year alignment (corr ~0.97, not ~1.0 like other Census
# sources) because LAUS county estimates get re-benchmarked in later years
# against updated QCEW/population controls -- CHR&R's build reflects a
# snapshot from shortly after each year's data first published, while a
# live pull here always returns BLS's currently revised figure.
# =============================================================================

library(dplyr)
library(httr)
library(jsonlite)
library(vroom)

# Standalone repo -- no dependency on the `dcf` package or Ingest's
# process.json schema, just a plain last-run marker for change detection.
last_bls_year <- if (file.exists("process.json")) {
  jsonlite::fromJSON("process.json")$bls_year
} else {
  NULL
}

api_key <- Sys.getenv("BLS_API_KEY")

all_fips <- vroom("resources/all_fips.csv.gz", col_types = "cccc", show_col_types = FALSE)
county_fips <- all_fips %>% filter(nchar(geography) == 5) %>% pull(geography)

series_for      <- function(fips) paste0("LAUCN", fips, "00000000", "03")
fips_for_series <- function(series_id) substr(series_id, 6, 10)

BLS_ENDPOINT <- "https://api.bls.gov/publicAPI/v2/timeseries/data/"
BATCH_SIZE   <- 50L  # BLS API v2 max series per request with a registered key

fetch_batch <- function(fips_batch, start_year, end_year) {
  resp <- tryCatch(
    httr::POST(
      BLS_ENDPOINT, encode = "json", httr::content_type("application/json"),
      body = list(
        seriesid        = series_for(fips_batch),
        startyear       = as.character(start_year),
        endyear         = as.character(end_year),
        annualaverage   = TRUE,
        registrationkey = api_key
      )
    ),
    error = function(e) NULL
  )
  if (is.null(resp)) {
    message("  [WARN] BLS request failed (network error)")
    return(NULL)
  }
  parsed <- tryCatch(
    jsonlite::fromJSON(httr::content(resp, "text", encoding = "UTF-8"), simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (is.null(parsed) || parsed$status != "REQUEST_SUCCEEDED") {
    message("  [WARN] BLS request not successful: ",
            if (!is.null(parsed)) paste(unlist(parsed$message), collapse = "; ") else "unparseable response")
    return(NULL)
  }

  rows <- lapply(parsed$Results$series, function(s) {
    fips        <- fips_for_series(s$seriesID)
    annual_rows <- Filter(function(r) r$period == "M13", s$data)
    if (length(annual_rows) == 0) return(NULL)
    latest <- annual_rows[[which.max(as.integer(sapply(annual_rows, function(r) r$year)))]]
    data.frame(geography = fips, year = as.integer(latest$year),
               value = as.numeric(latest$value), stringsAsFactors = FALSE)
  })
  bind_rows(rows)
}

current_year   <- as.integer(format(Sys.Date(), "%Y"))
county_batches <- split(county_fips, ceiling(seq_along(county_fips) / BATCH_SIZE))

message("Fetching BLS LAUS for ", length(county_fips), " counties in ",
        length(county_batches), " batches...")

results <- lapply(seq_along(county_batches), function(i) {
  message("  batch ", i, "/", length(county_batches))
  fetch_batch(county_batches[[i]], current_year - 2L, current_year)
})

all_years    <- bind_rows(Filter(Negate(is.null), results))
latest_year  <- max(all_years$year)

if (is.null(last_bls_year) || last_bls_year < latest_year) {

  bls_result <- all_years %>%
    filter(year == latest_year) %>%
    distinct(geography, .keep_all = TRUE) %>%
    transmute(
      geography            = geography,
      time                 = paste0(latest_year, "-12-31"),
      bls_pct_unemployment = value / 100
    )

  vroom::vroom_write(bls_result, "standard/data_county.csv.gz", delim = ",")

  jsonlite::write_json(list(bls_year = latest_year), "process.json", auto_unbox = TRUE)
  message("BLS LAUS data written: ", nrow(bls_result), " counties, year ", latest_year)
} else {
  message("BLS LAUS data is up to date (last year: ", last_bls_year, ")")
}
