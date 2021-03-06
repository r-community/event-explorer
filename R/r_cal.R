# Wrapper for messages, spotted in googlesheets3
spf <- function(...) stop(sprintf(...), call. = FALSE)
#internals.R from rladies/meetupr package
# This helper function makes a single call, given the full API endpoint URL
# Used as the workhorse function inside .fetch_results() below
.quick_fetch <- function(api_url,
                         event_status = NULL,
                         offset = 0,
                         api_key = NULL,
                         ...) {
  
  # list of parameters
  parameters <- list(status = event_status, # you need to add the status
                     # otherwise it will get only the upcoming event
                     offset = offset,
                     ...                    # other parameters
  )
  # Only need API keys if OAuth is disabled...
  if (!getOption("meetupr.use_oauth")) {
    parameters <- append(parameters, list(key = get_api_key()))
  }
  
  req <- httr::GET(url = api_url,          # the endpoint
                   query = parameters,
                   config = meetup_token()
  )
  
  httr::stop_for_status(req)
  reslist <- httr::content(req, "parsed")
  
  if (length(reslist) == 0) {
    #stop("Zero records match your filter. Nothing to return.\n",
    #     call. = FALSE)
    return(list(result = list(), headers = req$headers))
  }
  
  return(list(result = reslist, headers = req$headers))
}


# Fetch all the results of a query given an API Method
# Will make multiple calls to the API if needed
# API Methods listed here: https://www.meetup.com/meetup_api/docs/
.fetch_results <- function(api_method, api_key = NULL, event_status = NULL, ...) {
  
  # Build the API endpoint URL
  meetup_api_prefix <- "https://api.meetup.com/"
  api_url <- paste0(meetup_api_prefix, api_method)
  
  # Get the API key from MEETUP_KEY environment variable if NULL
  if (is.null(api_key)) api_key <- .get_api_key()
  if (!is.character(api_key)) stop("api_key must be a character string")
  
  # Fetch first set of results (limited to 200 records each call)
  res <- .quick_fetch(api_url = api_url,
                      event_status = event_status,
                      offset = 0,
                      ...)
  
  # Total number of records matching the query
  total_records <- as.integer(res$headers$`x-total-count`)
  if (length(total_records) == 0) total_records <- 1L
  records <- res$result
  cat(paste("Downloading", total_records, "record(s)..."))
  
  if((length(records) < total_records) & !is.null(res$headers$link)){
    
    # calculate number of offsets for records above 200
    offsetn <- ceiling(total_records/length(records))
    all_records <- list(records)
    
    for(i in 1:(offsetn - 1)) {
      res <- .quick_fetch(api_url = api_url,
                          api_key = api_key,
                          event_status = event_status,
                          offset = i,
                          ...)
      all_records[[i + 1]] <- res$result
    }
    records <- unlist(all_records, recursive = FALSE)
    
  }
  
  return(records)
}


# helper function to convert a vector of milliseconds since epoch into POSIXct
.date_helper <- function(time) {
  if (is.character(time)) {
    # if date is character string, try to convert to numeric
    time <- tryCatch(expr = as.numeric(time),
                     error = warning("One or more dates could not be converted properly"))
  }
  if (is.numeric(time)) {
    # divide milliseconds by 1000 to get seconds; convert to POSIXct
    seconds <- time / 1000
    out <- as.POSIXct(seconds, origin = "1970-01-01")
  } else {
    # if no conversion can be done, then return NA
    warning("One or more dates could not be converted properly")
    out <- rep(NA, length(time))
  }
  return(out)
}

# updated function from rladies/meetupr
get_events <- function(urlname, event_status = NULL, fields = NULL, api_key = NULL, ...) {
  if (!is.null(event_status) &&
      !event_status %in% c("cancelled", "draft", "past", "proposed", "suggested", "upcoming")) {
    stop(sprintf("Event status %s not allowed", event_status))
  }
  # If event_status contains multiple statuses, we can pass along a comma sep list
  if (length(event_status) > 1) {
    event_status <- paste(event_status, collapse = ",")
  }
  # If fields is a vector, change it to single string of comma separated values
  if(length(fields) > 1){
    fields <- paste(fields, collapse = ",")
  }
  api_method <- paste0(urlname, "/events")
  res <- .fetch_results(api_method, api_key, event_status, fields = fields, ...)
  tibble::tibble(
    id = purrr::map_chr(res, "id"),  #this is returned as chr (not int)
    group_name = purrr::map_chr(res, c("group", "name"), .null = NA),
    name = purrr::map_chr(res, "name"),
    created = .date_helper(purrr::map_dbl(res, "created", .default = 0)),
    status = purrr::map_chr(res, "status", .default = NA),
    time = .date_helper(purrr::map_dbl(res, "time", .default = 0)),
    local_date = as.Date(purrr::map_chr(res, "local_date", .default = 0)),
    local_time = purrr::map_chr(res, "local_time", .null = NA),
    # TO DO: Add a local_datetime combining the two above?
    waitlist_count = purrr::map_int(res, "waitlist_count", .default = 0),
    yes_rsvp_count = purrr::map_int(res, "yes_rsvp_count", .default = 0),
    venue_id = purrr::map_int(res, c("venue", "id"), .null = NA),
    venue_name = purrr::map_chr(res, c("venue", "name"), .null = NA),
    venue_lat = purrr::map_dbl(res, c("venue", "lat"), .null = NA),
    venue_lon = purrr::map_dbl(res, c("venue", "lon"), .null = NA),
    venue_address_1 = purrr::map_chr(res, c("venue", "address_1"), .null = NA),
    venue_city = purrr::map_chr(res, c("venue", "city"), .null = NA),
    venue_state = purrr::map_chr(res, c("venue", "state"), .null = NA),
    venue_zip = purrr::map_chr(res, c("venue", "zip"), .null = NA),
    venue_country = purrr::map_chr(res, c("venue", "country"), .null = NA),
    venue_country_name = purrr::map_chr(res, c("venue", "localized_country_name"), .null = NA),
    group_country = purrr::map_chr(res, c("group", "country"), .null = NA),
    group_region = purrr::map_chr(res, c("group", "timezone"), .null = NA),
    description = purrr::map_chr(res, c("description"), .null = NA),
    link = purrr::map_chr(res, c("link"), .default = NA),
    #added because of error when res is null
    resource = res
  )
}

# environment to store credentials
.state <- new.env(parent = emptyenv())

#' Authorize \code{meetupr}
#'
#' Authorize \code{meetupr} via the OAuth API. You will be directed to a web
#' browser, asked to sign in to your Meetup account, and to grant \code{meetupr}
#' permission to operate on your behalf. By default, these user credentials are
#' cached in a file named \code{.httr-oauth} in the current working directory,
#' from where they can be automatically refreshed, as necessary.
#'
#' Most users, most of the time, do not need to call this function explicitly --
#' it will be triggered by the first action that requires authorization. Even
#' when called, the default arguments will often suffice. However, when
#' necessary, this function allows the user to
#'
#' \itemize{
#'   \item TODO: force the creation of a new token
#'   \item TODO: retrieve current token as an object, for possible storage to an
#'   \code{.rds} file
#'   \item TODO: read the token from an object or from an \code{.rds} file
#'   \item TODO: provide your own app key and secret -- this requires setting up
#'   a new project in \href{https://console.developers.google.com}{Google Developers Console}
#'   \item TODO: prevent caching of credentials in \code{.httr-oauth}
#' }
#'
#' In a direct call to \code{meetup_auth}, the user can provide the token, app
#' key and secret explicitly and can dictate whether interactively-obtained
#' credentials will be cached in \code{.httr_oauth}. If unspecified, these
#' arguments are controlled via options, which, if undefined at the time
#' \code{meetupr} is loaded, are defined like so:
#'
#' \describe{
#'   \item{key}{Set to option \code{meetupr.client_id}, which defaults to a
#'   client ID that ships with the package}
#'   \item{secret}{Set to option \code{meetupr.client_secret}, which defaults to
#'   a client secret that ships with the package}
#'   \item{cache}{Set to option \code{meetupr.httr_oauth_cache}, which defaults
#'   to \code{TRUE}}
#' }
#'
#' To override these defaults in persistent way, predefine one or more of them
#' with lines like this in a \code{.Rprofile} file:
#' \preformatted{
#' options(meetupr.client_id = "FOO",
#'         meetupr.client_secret = "BAR",
#'         meetupr.httr_oauth_cache = FALSE)
#' }
#' See \code{\link[base]{Startup}} for possible locations for this file and the
#' implications thereof.
#'
#' More detail is available from
#' \href{https://www.meetup.com/meetup_api/auth/#oauth2-resources}{Authenticating
#' with the Meetup API}.
#'
#' @param token optional; an actual token object or the path to a valid token
#'   stored as an \code{.rds} file
#' @param new_user logical, defaults to \code{FALSE}. Set to \code{TRUE} if you
#'   want to wipe the slate clean and re-authenticate with the same or different
#'   Google account. This disables the \code{.httr-oauth} file in current
#'   working directory.
#' @param key,secret the "Client ID" and "Client secret" for the application;
#'   defaults to the ID and secret built into the \code{googlesheets} package
#' @param cache logical indicating if \code{googlesheets} should cache
#'   credentials in the default cache file \code{.httr-oauth}
#' @param verbose logical; do you want informative messages?
#'
#' @examples
#' \dontrun{
#' ## load/refresh existing credentials, if available
#' ## otherwise, go to browser for authentication and authorization
#' gs_auth()
#'
#' ## store token in an object and then to file
#' ttt <- gs_auth()
#' saveRDS(ttt, "ttt.rds")
#'
#' ## load a pre-existing token
#' gs_auth(token = ttt)       # from an object
#' gs_auth(token = "ttt.rds") # from .rds file
#' }
meetup_auth <- function(token = NULL,
                        new_user = FALSE,
                        key = getOption("meetupr.client_id"),
                        secret = getOption("meetupr.client_secret"),
                        cache = getOption("meetupr.httr_oauth_cache"),
                        verbose = TRUE) {
  
  if (new_user) {
    meetup_deauth(clear_cache = TRUE, verbose = verbose)
  }
  
  token = readRDS("meetup_token.rds")
  
  if (is.null(token)) {
    
    message(paste0('Meetup is moving to OAuth *only* as of 2019-08-15. Set\n',
                   '`meetupr.use_oauth = FALSE` in your .Rprofile, to use\nthe ',
                   'legacy `api_key` authorization.'))
    
    meetup_app       <- httr::oauth_app("meetup", key = key, secret = secret)
    meetup_endpoints <- httr::oauth_endpoint(
      authorize = 'https://secure.meetup.com/oauth2/authorize',
      access    = 'https://secure.meetup.com/oauth2/access'
    )
    meetup_token <- httr::oauth2.0_token(meetup_endpoints, meetup_app,
                                         cache = cache)
    
    stopifnot(is_legit_token(meetup_token, verbose = TRUE))
    .state$token <- meetup_token
    
  } else if (inherits(token, "Token2.0")) {
    
    stopifnot(is_legit_token(token, verbose = TRUE))
    .state$token <- token
    
  } else if (inherits(token, "character")) {
    
    meetup_token <- try(suppressWarnings(readRDS(token)), silent = TRUE)
    if (inherits(meetup_token, "try-error")) {
      spf("Cannot read token from alleged .rds file:\n%s", token)
    } else if (!is_legit_token(meetup_token, verbose = TRUE)) {
      spf("File does not contain a proper token:\n%s", token)
    }
    .state$token <- meetup_token
    
  } else {
    spf(paste0("Input provided via 'token' is neither a token,\n",
               "nor a path to an .rds file containing a token."))
  }
  
  invisible(.state$token)
  
}

#' Produce Meetup token
#'
#' If token is not already available, call \code{\link{meetup_auth}} to either
#' load from cache or initiate OAuth2.0 flow. Return the token -- not "bare"
#' but, rather, prepared for inclusion in downstream requests.
#'
#' @return a \code{request} object (an S3 class provided by \code{httr})
#'
#' @keywords internal
meetup_token <- function(verbose = FALSE) {
  if (getOption("meetupr.use_oauth")) {
    if (!token_available(verbose = verbose)) meetup_auth(verbose = verbose)
    httr::config(token = .state$token)
  } else {
    httr::config()
  }
}

#' Check token availability
#'
#' Check if a token is available in \code{\link{meetupr}}'s internal
#' \code{.state} environment.
#'
#' @return logical
#'
#' @keywords internal
token_available <- function(verbose = TRUE) {
  
  if (is.null(.state$token)) {
    if (verbose) {
      if (file.exists(".httr-oauth")) {
        message("A .httr-oauth file exists in current working ",
                "directory.\nWhen/if needed, the credentials cached in ",
                ".httr-oauth will be used for this session.\nOr run ",
                "meetup_auth() for explicit authentication and authorization.")
      } else {
        message("No .httr-oauth file exists in current working directory.\n",
                "When/if needed, 'meetupr' will initiate authentication ",
                "and authorization.\nOr run meetup_auth() to trigger this ",
                "explicitly.")
      }
    }
    return(FALSE)
  }
  
  TRUE
  
}

#' Suspend authorization
#'
#' Suspend \code{\link{meetupr}}'s authorization to place requests to the Meetup
#' APIs on behalf of the authenticated user.
#'
#' @param clear_cache logical indicating whether to disable the
#'   \code{.httr-oauth} file in working directory, if such exists, by renaming
#'   to \code{.httr-oauth-SUSPENDED}
#' @param verbose logical; do you want informative messages?
#' @export
#' @family auth functions
#' @examples
#' \dontrun{
#' gs_deauth()
#' }
meetup_deauth <- function(clear_cache = TRUE, verbose = TRUE) {
  
  if (clear_cache && file.exists(".httr-oauth")) {
    if (verbose) {
      message("Disabling .httr-oauth by renaming to .httr-oauth-SUSPENDED")
    }
    file.rename(".httr-oauth", ".httr-oauth-SUSPENDED")
  }
  
  if (token_available(verbose = FALSE)) {
    if (verbose) {
      message("Removing google token stashed internally in 'meetupr'.")
    }
    rm("token", envir = .state)
  } else {
    message("No token currently in force.")
  }
  
  invisible(NULL)
  
}

#' Check that token appears to be legitimate
#'
#' @keywords internal
is_legit_token <- function(x, verbose = FALSE) {
  
  if (!inherits(x, "Token2.0")) {
    if (verbose) message("Not a Token2.0 object.")
    return(FALSE)
  }
  
  if ("invalid_client" %in% unlist(x$credentials)) {
    # shouldn't happen if id and secret are good
    if (verbose) {
      message("Authorization error. Please check client_id and client_secret.")
    }
    return(FALSE)
  }
  
  if ("invalid_request" %in% unlist(x$credentials)) {
    # in past, this could happen if user clicks "Cancel" or "Deny" instead of
    # "Accept" when OAuth2 flow kicks to browser ... but httr now catches this
    if (verbose) message("Authorization error. No access token obtained.")
    return(FALSE)
  }
  
  TRUE
  
}


#' Store a legacy API key in the .state environment
#'
#' @keywords internal
set_api_key <- function(x = NULL) {
  
  if (is.null(x)) {
    key <- Sys.getenv("MEETUP_KEY")
    if (key == "") {
      spf(paste0("You have not set a MEETUP_KEY environment variable.\nIf you ",
                 "do not yet have a meetup.com API key, use OAuth2\ninstead, ",
                 "as API keys are now deprecated - see here:\n",
                 "* https://www.meetup.com/meetup_api/auth/"))
    }
    .state$legacy_api_key <- key
  } else {
    .state$legacy_api_key <- x
  }
  
  invisible(NULL)
  
}

#' Get the legacy API key from the .state environment
#'
#' @keywords internal
get_api_key <- function() {
  
  if (is.null(.state$legacy_api_key)) {
    set_api_key()
  }
  
  .state$legacy_api_key
  
}




options(meetupr.httr_oauth_cache=TRUE)
options(meetupr.use_oauth = TRUE)


get_upcoming_events <- function(){
  rugs = read.csv("https://raw.githubusercontent.com/r-community/event-explorer/master/docs/data/rugs_list.csv", encoding = "UTF-8")
  rugs_urlnames_full = rugs$rugs_urlnames_full
  s_get_events <- purrr::safely(get_events)
  all_upcoming_revents <- lapply(rugs_urlnames_full, 
                                 function(x) 
                                 {
                                   y <- s_get_events(x, event_status = "upcoming", api_key = "", no_earlier_than = Sys.Date(), no_later_than = Sys.Date() + 90 )
                                   Sys.sleep(0.3)
                                   y
                                 }
  ) 
  all_past_revents <- lapply(rugs_urlnames_full, 
                             function(x) 
                             {
                               y <- s_get_events(x, event_status = "past", api_key = "", no_earlier_than = Sys.Date() - 30, no_later_than = Sys.Date())
                               Sys.sleep(0.3)
                               y
                             }
  )  
  all_upcoming_revents <- purrr::compact(purrr::map(all_upcoming_revents, c("result")))
  all_past_revents <- purrr::compact(purrr::map(all_past_revents, c("result")))
  eventdf <- do.call("rbind", lapply(all_upcoming_revents, '[', c("name","group_name","group_country","group_region","venue_name", "local_date", "description","link")))
  eventdf <- eventdf[!is.na(eventdf$local_date),]
  past_eventdf <- do.call("rbind", lapply(all_past_revents, '[', c("name","group_name","group_country","group_region","venue_name", "local_date", "description","link")))

  past_eventdf$textColor <- "#7171fb"
  eventdf$textColor <- "blue"
  eventdf <- rbind(past_eventdf, eventdf)
  #
  country_code <- eventdf$group_country
  country_name <- countrycode::countrycode(country_code, "iso2c", "country.name")
  eventdf <- tibble::add_column(eventdf, Country = country_name, .after = "group_country")
  
  eventdf[grepl("America",eventdf$group_region),]$group_region <- "Latin America"
  eventdf[grepl("US|Canada",eventdf$group_region),]$group_region <- "US/Canada"
  eventdf[grepl("Europe",eventdf$group_region),]$group_region <- "Europe"
  eventdf[grepl("Africa",eventdf$group_region),]$group_region <- "Africa"
  eventdf[grepl("Asia",eventdf$group_region),]$group_region <- "Asia"
  eventdf[grepl("Australia|Pacific/Auckland",eventdf$group_region),]$group_region <- "Australia"
  
  eventdf[grepl("Online", eventdf$venue_name), ]$name <- paste(eventdf$name[grepl("Online", eventdf$venue_name)], " [Virtual] ")
  
  eventdf$name <- paste(eventdf$name, eventdf$Country, eventdf$group_region, sep = ", ")
  
  eventdf <- eventdf[(c("name","group_name","local_date", "description","link", "textColor"))]
  #
  eventdf$name <- paste(eventdf$group_name, eventdf$name, sep = ": ")
  colnames(eventdf) <- c("title", "group","start", "description", "url", "textColor")
  
  event_json <- jsonlite::toJSON(eventdf, pretty = TRUE )
  writeLines(event_json, "docs/data/rugs_events.json")
}

get_upcoming_events()
