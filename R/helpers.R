

updateLineOpts <- function(fig, opts) {
    if(is.numeric(opts$line_dash)) {
    if(length(opts$line_dash) == 1) {
      opts$line_dash <- as.character(opts$line_dash)
    }
  }
  if(is.character(opts$line_dash)) {
    if(!opts$line_dash %in% names(ltyDict))
      stop("'line_join' should be one of: ", paste(names(ltyDict), collapse = ", "), call. = FALSE)
    opts$line_dash <- ltyDict[[opts$line_dash]]$line_dash
  }

  if(is.numeric(opts$line_cap))
    opts$line_cap <- ljoinDict[[as.character(opts$line_cap)]]

  if(is.null(opts$line_color))
    opts$line_color <- getNextColor(fig)

  opts
}

validateFig <- function(fig, fct) {
  if(!inherits(fig, "BokehFigure"))
    stop("Error in ", fct, ": first argument must be of type 'BokehFigure'", call. = FALSE)
}

## some things like rainbow(), etc., give hex with alpha
## Bokeh doesn't like alpha, so get rid of it
validateColors <- function(opts) {
  colFields <- c("line_color", "fill_color", "text_color")

  for(fld in colFields) {
    if(!is.null(opts[[fld]])) {
      ind <- which(grepl("^#", opts[[fld]]) & nchar(opts[[fld]]) == 9)
      if(length(ind) > 0) {
        message("note - ", fld, " has hex colors with with alpha information - removing alpha")
        opts[[fld]][ind] <- substr(opts[[fld]][ind], 1 , 7)
      }
    }
  }
  opts
}

getNextColor <- function(fig) {
  nLayers <- length(fig$glyphSpecs)
  nextColorIdx <- (nLayers + 1) %% length(fig$theme$glyph)
  fig$theme$glyph[nextColorIdx]
}

checkArcDirection <- function(direction) {
  if(!direction %in% c("clock", "anticlock"))
    stop("'direction' must be 'clock' or 'anticlock'", call. = FALSE)
}

## take a set of glyph specification names
## and come up with the next increment of 'glyph[int]'
genGlyphName <- function(specNames) {
  # specNames <- c("asdf", "glyph1", "glyph23", "qwert", "aglyph7", "glyph12b")
  if(length(specNames) == 0) {
    name <- "glyph1"
  } else {
    glyphNames <- specNames[grepl("^glyph([0-9]+)$", specNames)]
    if(length(glyphNames) == 0) {
      name <- "glyph1"
    } else {
      nn <- as.integer(gsub("glyph", "", glyphNames))
      name <- paste("glyph", max(nn) + 1, sep = "")
    }
  }
  name
}

## get the axis type and range for x and y axes
getGlyphAxisTypeRange <- function(x, y, assertX = NULL, assertY = NULL, glyph = "") {
  xAxisType <- getGlyphAxisType(x)
  yAxisType <- getGlyphAxisType(y)

  if(glyph != "")
    glyphText <- paste("'", glyph, "' ")

  if(!is.null(assertX)) {
    if(xAxisType != assertX)
      stop("Glyph ", glyph, " expects a ", assertX, " x axis", call. = FALSE)
  }
  if(!is.null(assertY)) {
    if(yAxisType != assertY)
      stop("Glyph ", glyph, "expects a ", assertY, " y axis", call. = FALSE)
  }

  list(
    xAxisType = xAxisType,
    yAxisType = yAxisType,
    xRange = getGlyphRange(x, xAxisType),
    yRange = getGlyphRange(y, yAxisType)
  )
}

## determine whether axis is "numeric" or "categorical"
getGlyphAxisType <- function(a) {
  # this will surely get more complex...
  ifelse(is.character(a), "categorical", "numeric")
}

## determine the range of an axis for a glyph
getGlyphRange <- function(a, axisType = NULL, ...) {
  if(is.null(axisType))
    axisType <- getGlyphAxisType(a)
  ## ... can be size, etc. attributes
  if(axisType == "numeric") {
    range(a, na.rm = TRUE)
  } else {
    # gsub removes suffixes like ":0.6"
    unique(gsub("(.*):(-*[0-9]*\\.*)*([0-9]+)*$", "\\1", a))
  }
}

validateAxisType <- function(figType, curType, which) {
  if(length(figType) > 0) {
    # make this more informative...
    if(figType != curType)
      stop(which, " axis type (numerical / categorical) does not match that of other elements in this figure", call. = FALSE)
  }
}

## take a collection of glyph ranges (x or y axis)
## and find the global range across all glyphs
getAllGlyphRange <- function(ranges, padding_factor, axisType = "numeric") {
  if(axisType == "numeric") {
    rangeMat <- do.call(rbind, ranges)
    hardRange <- c(min(rangeMat[,1], na.rm = TRUE), 
      max(rangeMat[,2], na.rm = TRUE))
    hardRange <- hardRange + c(-1, 1) * padding_factor * diff(hardRange)
    if(hardRange[1] == hardRange[2])
      hardRange <- hardRange + c(-0.5, 0.5)
    hardRange
  } else {
    sort(unique(do.call(c, ranges)))
  }
}

## give a little warning if any options are specified that won't be used
checkOpts <- function(opts, type) {
  curGlyphProps <- glyphProps[[type]]

  validOpts <- NULL
  if(curGlyphProps$lp)
    validOpts <- c(validOpts, linePropNames)
  if(curGlyphProps$fp)
    validOpts <- c(validOpts, fillPropNames)
  if(curGlyphProps$tp)
    validOpts <- c(validOpts, textPropNames)

  if(length(opts) > 0) {
    # only get names of opts that are not NULL
    idx <- which(sapply(opts, function(x) !is.null(x)))
    if(length(idx) > 0) {
      notUsed <- setdiff(names(opts)[idx], validOpts)
      if(length(notUsed) > 0)
        message("note - arguments not used: ", paste(notUsed, collapse = ", "))    
    }    
  }
}

## take a hex color and reduce its saturation by a factor
## (used to get fill for pch=21:25)
reduceSaturation <- function(col, factor = 0.5) {
  col2 <- do.call(rgb2hsv, structure(as.list(col2rgb(col)[,1]), names = c("r", "g", "b")))
  col2['s', ] <- col2['s', ] * factor  
  do.call(hsv, as.list(col2[,1]))
}

## get variables when specified as names of a data frame
## and need to be deparsed and extracted
getVarData <- function(data, var) {
  tmp <- data[[paste(deparse(var), collapse = "")]]
  if(is.null(tmp))
    tmp <- eval(var)
  tmp
}

## handle different x, y input types
## this should be more "class"-y
## but this will suffice
getXYData <- function(x, y) {
  if(is.null(y)) {
    if(is.list(x)) {
      return(list(x = x[[1]], y = x[[2]]))
    } else if(is.vector(x)) {
      return(list(x = seq_along(x), y = x))
    }
  }
  list(x = x, y = y)        
}

## take output of map() and convert it to a data frame
map2df <- function(a) {
  dd <- data.frame(lon = a$x, lat = a$y, 
    group = cumsum(is.na(a$x) & is.na(a$y)) + 1)
  dd[complete.cases(dd$lon, dd$lat), ]
}
