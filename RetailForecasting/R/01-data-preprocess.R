####################################################################################################
## This R script will do the following:
## 1. Raw data uploading into SQL tables;
## 2. Data is processed to contain the full date range
## 3. The processed data is saved into the SQL table
## Input : The csv files of the raw data
## Output: The SQL table "forecasting" with the complete date range
####################################################################################################
file_path <- "../Data"
####################################################################################################
## Compute context
####################################################################################################
connection_string <- "Driver=SQL Server;
                      Server=[SQL Server Name];
                      Database=[Database Name];
                      UID=[User ID];
                      PWD=[User Password]"
sql_share_directory <- paste("c:\\AllShare\\", Sys.getenv("USERNAME"), sep = "")
dir.create(sql_share_directory, recursive = TRUE)
sql <- RxInSqlServer(connectionString = connection_string, 
                     shareDir = sql_share_directory)
local <- RxLocalSeq()
####################################################################################################
## Forecasting metadata
####################################################################################################
forecasting_columns <- c(ID1 = "integer",
                         ID2 = "integer",
                         time = "character",
                         value = "integer")
####################################################################################################
## Forecasting file info
####################################################################################################
forecasting_file <- "ForecastingInput.csv"
forecasting_file_path <- file.path(file_path, forecasting_file)

forecasting_data_text <- RxTextData(file = forecasting_file_path,
                                    colClasses = forecasting_columns)
####################################################################################################
## Load forecasting data into SQL table
####################################################################################################
rxSetComputeContext(local)
table_name <- strsplit(basename(forecasting_file), "\\.")[[1]][1]
table_name <- tolower(table_name)
forecasting_data_table <- RxSqlServerData(table = table_name,
                                          connectionString = connection_string,
                                          colClasses = forecasting_columns)
rxDataStep(inData = forecasting_data_text,
           outFile = forecasting_data_table,
           overwrite = TRUE)
####################################################################################################
## Modeling parameters
####################################################################################################
test.length <- 52
seasonality <- 52
observation.freq <- "week"
timeformat <- "%m/%d/%Y"
####################################################################################################
## Select eligible time series based on business rules
####################################################################################################
data <- rxImport(forecasting_data_table)
## ------- User-Defined Parameters ------ ##
min.length <- 2*seasonality
value.threshold <- 20
## ----------------------------------------- ##
# Date format clean-up

data$time <- as.POSIXct(as.numeric(as.POSIXct(data$time, 
                                              format = timeformat,
                                              tz = "UTC", 
                                              origin = "1970-01-01"), 
                                   tz = "UTC"), 
                        tz = "UTC", 
                        origin = "1970-01-01")

library(plyr)
# apply business rules
businessrule <- function(data){  
  tsvalues <- data$value
  # Select Eligible Time Series:
  # Rule 1: if a time series has no more than <min.length> non-NA values, discard
  if (sum(!is.na(tsvalues)) < min.length) 
    return(c(judge = 1))
  # Rule 2: if a time series has any sales quantity <= value.threshold , discard
  if (length(tsvalues[tsvalues > value.threshold]) != length(tsvalues)) return(c(judge = 2))
    return(c(judge = 0))
}
  
unique.ID12 <- unique(data[, 1:2])
judge.all <- ddply(data, .(ID1, ID2), businessrule)
judge.good <- judge.all[judge.all$judge == 0, c("ID1", "ID2")]
data <- join(data, judge.good, by = c("ID1", "ID2"), type = "inner")
  
min.time <- min(data$time)
max.time <- max(data$time)
  
unique.time <- seq(from = min.time, to = max.time, by = observation.freq)
  
res <- merge(unique.ID12, unique.time)
rr <-  res[order(res$ID1, res$ID2),]
names(rr) <- c("ID1", "ID2", "time")
# For every (ID1, ID2) pair, create (ID1, ID2, time) combination
data <- join(rr, data, by = c("ID1", "ID2", "time"), type = "left")
  
# apply business rules
businessrule <- function(data){
  # Train and test split
  data.length <- dim(data)[1]
  train.length <- data.length - test.length
    
  tsvalues <- data$value
    
  # Select Eligible Time Series based on training and testing principals:
  # Rule 3: if the last 6 values in trainning set are all NA, discard
  if (sum(is.na(tsvalues[(train.length - 5) : train.length])) == 6) 
    return(c(judge = 3))
    
  # Rule 4: if test data has more than a half NA, discard
  if (test.length > 0 && sum(is.na(tsvalues[(train.length+1):data.length])) > test.length / 2) 
    return(c(judge = 4))
    
  return(c(judge = 0))
}
  
judge.all <- ddply(data, .(ID1, ID2), businessrule, .progress = "win")
judge.good <- judge.all[judge.all$judge == 0, c("ID1", "ID2")]
data <- join(data, judge.good, by = c("ID1", "ID2"), type = "inner")
data$time <- as.character(data$time)
forecasting_table <- RxSqlServerData(table = "forecasting",
                                     connectionString = connection_string)
rxDataStep(inData = data,
           outFile = forecasting_table,
           overwrite = TRUE)

####################################################################################################
## Cleanup
####################################################################################################
#rm(list = ls())