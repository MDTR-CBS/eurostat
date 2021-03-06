#' @title Get Data from Eurostat API in JSON
#' @description Retrieve data from Eurostat API in JSON format.
#' @details 
#'   Data to retrieve from
#'   \href{http://ec.europa.eu/eurostat/web/json-and-unicode-web-services}{The
#'   Eurostat Web Services} can be specified with filters. Normally, it is
#'   better to use JSON query through \code{\link{get_eurostat}}, than to use
#'   \code{\link{get_eurostat_json}} directly.
#'   
#'   Queries are limited to 50 sub-indicators at a time. A time can be
#'   filtered with fixed "time" filter or with "sinceTimePeriod" and
#'   "lastTimePeriod" filters. A \code{sinceTimePeriod = 2000} returns
#'   observations from 2000 to a last available. A \code{lastTimePeriod = 10}
#'   returns a 10 last observations.
#'  
#'   To use a proxy to connect, a \code{\link[httr]{use_proxy}} can be
#'   passed to \code{\link[httr]{GET}}. For example 
#'   \code{get_eurostat_json(id, filters, 
#'   config = httr::use_proxy(url, port, username, password))}.
#'    
#' @param id A code name for the dataset of interested. See the table of
#'   contents of eurostat datasets for more details.
#' @param filters A named list of filters. Names of list objects are Eurostat
#'   variable codes and values are vectors of observation codes. If \code{NULL}
#'   (default) the whole dataset is returned. See details for more on filters
#'   and limitations per query.
#' @param lang A language used for metadata (en/fr/de).
#' @param type A type of variables, "code" (default), "label" or "both". The
#'   "both" will return a data_frame with named vectors, labels as values and
#'   codes as names.
#' @param stringsAsFactors if \code{TRUE} (the default) variables are converted
#'   to factors in original Eurostat order. If \code{FALSE} they are returned as
#'   a character.
#' @param ... Other arguments passed on to \code{\link[httr]{GET}}. For example
#'   a proxy parameters, see details.
#'   .
#'
#' @return A dataset as a data_frame.
#' @export
#' @author Przemyslaw Biecek, Leo Lahti, Janne Huovari and Markus Kainu
#'   \email{ropengov-forum@@googlegroups.com}
#'   \url{http://github.com/ropengov/eurostat}
#' @examples
#'  \dontrun{
#'    tmp <- get_eurostat_json("cdh_e_fos")
#'    nama_gdp_c has been discontinued since 2/2018 and this example has ceased working.
#'    yy <- get_eurostat_json(id = "nama_gdp_c", filters = list(geo=c("EU28", "FI"),
#'                                                         unit="EUR_HAB",
#'                                                         indic_na="B1GM"))
#' }
#' @keywords utilities database
get_eurostat_json <- function(id, filters = NULL, 
                              type = c("code", "label", "both"), 
                              lang = c("en", "fr", "de"),
                              stringsAsFactors = default.stringsAsFactors(),
                              ...){
  
  # Check if you have internet connection
  internet_available <- curl::has_internet()
  if (!internet_available) stop("You have no internet connection, please reconnect!")
  
  # get response  
  # url <- try(eurostat_json_url(id = id, filters = filters, lang = lang))
  # if (class(url) == "try-error") { stop(paste("The requested data set cannot be found with the following specifications to get_eurostat_json function: ", "id: ", id, "/ filters: ", filters, "/ lang: ", lang))  }
  url <- eurostat_json_url(id = id, filters = filters, lang = lang)
  
  # resp <- try(httr::GET(url, ...))
  # if (class(resp) == "try-error") { stop(paste("The requested url cannot be found within the get_eurostat_json function:", url))  }
  resp <- httr::GET(url)
  if (httr::http_error(resp)) { 
    stop(paste("The requested url cannot be found within the get_eurostat_json function:", url))
  }
  
  status <- httr::status_code(resp)
  
  # check status and get json
  
  msg <- ". Some datasets are not accessible via the eurostat
          interface. You can try to search the data manually from the comext
  	  database at http://epp.eurostat.ec.europa.eu/newxtweb/ or bulk
  	  download facility at
  	  http://ec.europa.eu/eurostat/estat-navtree-portlet-prod/BulkDownloadListing
  	  or annual Excel files
  	  http://ec.europa.eu/eurostat/web/prodcom/data/excel-files-nace-rev.2"
	  
  if (status == 200){
    jdat <- jsonlite::fromJSON(url)
  } else if (status == 400){
    stop("Failure to get data. Probably invalid dataset id. Status code: ", 
         status, msg)
  } else if (status == 500){
    stop("Failure to get data. Probably filters did not return any data 
         or data exceeded query size limitation. Status code: ", status, msg)
  } else {
    stop("Failure to get data. Status code: ", status, msg)
  }
  
  # get json data
  dims <- jdat[[1]]$dimension
  ids <- dims$id
  
  dims_list <- lapply(dims[rev(ids)], function(x){
    y <- x$category$label
    if (type[1] == "label") {
      y <- unlist(y, use.names = FALSE)
    } else if (type[1] == "code"){
      y <- names(unlist(y))
    } else if (type[1] == "both"){
      y <- unlist(y)
    } else {
      stop("Invalid type ", type)
    }
  })
  
  variables <- expand.grid(dims_list, KEEP.OUT.ATTRS = FALSE, 
                           stringsAsFactors = stringsAsFactors)
  
  dat <- data.frame(variables[rev(names(variables))], values = jdat[[1]]$value)
  
  tibble::as_tibble(dat)
  
}



# Internal function to build json url
eurostat_json_url <- function(id, filters, lang){

  # prepare filters for query
  filters2 <- as.list(unlist(filters))
  names(filters2) <- rep(names(filters), lapply(filters, length))
  
  # prepare url
  url_list <- list(scheme = "http",
                   hostname = "ec.europa.eu",
                   path = file.path("eurostat/wdds/rest/data/v1.1/json", 
                                    lang[1], id),
                   query = filters2)
  class(url_list) <- "url"
  url <- httr::build_url(url_list)
  url
}
