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
## Income metadata
####################################################################################################
income_columns <- c(time = "character",
                    value = "numeric")
####################################################################################################
## Income file info
####################################################################################################
azure_samples_url <- "http://azuremlsampleexperiments.blob.core.windows.net/templatedata"
income_url <- file.path(azure_samples_url, "Forecasting- Personal Income.csv")
income_file <- basename(income_url)
income_file_path <- file.path(tempdir(), income_file)
download.file(url = income_url, 
              destfile = income_file_path,
              quiet = TRUE)
income_data_text <- RxTextData(file = income_file_path,
                               colClasses = income_columns)
####################################################################################################
## Load income data into SQL table
####################################################################################################
rxSetComputeContext(local)
table_name <- strsplit(basename(income_url), "\\.")[[1]][1]
table_name <- gsub(" ", "_", table_name)
table_name <- gsub("-", "", table_name)
table_name <- tolower(table_name)
income_data_table <- RxSqlServerData(table = table_name,
                                     connectionString = connection_string,
                                     colClasses = income_columns)
rxDataStep(inData = income_data_text,
           outFile = income_data_table,
           overwrite = TRUE)

####################################################################################################
## Add economic index and select lags based on max correlation
####################################################################################################
addlag <- function(data) {
  # Train and test split
  data.length <- NROW(data$time)
  train.length <- data.length - test.length
  
  # Preparation
  data.start <- data$time[1]
  data.obs.diff <- as.numeric(data$time[2] - data$time[1])
  idx.start <- idx$time[1]
  
  maxlag <- as.numeric(data.start -idx.start)/data.obs.diff
  idx.cor.startid <- 1 + (maxlag > seasonality) * (maxlag - seasonality)
  
  # Moving average
  data.ma <- rollapply(data$value[1:train.length],
                       width = seasonality,
                       FUN = mean, 
                       fill = NA,
                       na.rm = TRUE)
  
  # Find the lag with maximum correlation using training data
  correlation <- rollapply(idx$value[idx.cor.startid:(idx.cor.startid + maxlag-1 + train.length)],
                           width = train.length,
                           FUN = cor,
                           y = data.ma,
                           use = "complete.obs")
  maxcorr <- which.max(abs(correlation))
  bestlag <- seasonality - maxcorr + 1
  bestidx <- idx$value[maxcorr:(maxcorr+data.length-1)]
  return(bestidx)
}

####################################################################################################
## Modeling parameters
####################################################################################################
test.length <- 52
seasonality <- 52
observation.freq <- "week"
timeformat <- "%m/%d/%Y"

library(forecast)
library(zoo)
library(plyr)

forecasting_table <- RxSqlServerData(table = "forecasting",
                                     connectionString = connection_string)
data <- rxImport(forecasting_table)
idx <- rxImport(income_data_table)
  
# Date format clean-up
data$time <- as.POSIXct(as.numeric(as.POSIXct(data$time, 
                                              format = "%Y-%m-%d",
                                              tz = "UTC", 
                                              origin = "1970-01-01"),
                                    tz = "UTC"), 
                        tz = "UTC", 
                        origin = "1970-01-01")
idx$time <- as.POSIXct(as.numeric(as.POSIXct(idx$time, 
                                              format = timeformat, 
                                              tz = "UTC", 
                                              origin = "1970-01-01"), 
                                  tz = "UTC"), 
                        tz = "UTC", 
                        origin = "1970-01-01")
  
  
  
res <- ddply(data, .(ID1, ID2), addlag)
res <- reshape(res, direction = "long", varying = list(names(res[c(-1, -2)])))
res <- arrange(res, ID1, ID2)
RDPI <- res$V1
data <- cbind(data, RDPI)
#data$time <- as.character(data$time)
####################################################################################################
## Create more features
####################################################################################################
library(zoo)
library(timeDate)
  
# Date Features
data$year <- as.numeric(format(data$time, "%Y"))
data$month <- as.numeric(format(data$time, "%m"))
data$weekofmonth <- ceiling(as.numeric(format(data$time, "%d"))/7)
  
obsdayofweek <- as.numeric(format(data$time[1], "%u"))
adjStartofWeek <- 60*60*24*(7-obsdayofweek)
data$weekofyear <- as.numeric(format(data$time+adjStartofWeek, "%U"))
  
# Holiday Features
# These codes only apply to weekly data
CyberMonday <- function(years) {
  as.timeDate(as.Date(USThanksgivingDay(years))+4)
}
  
years = unique(data$year)
  
adjHolidays <- function(holidays) {
  holidays <- as.Date(holidays)
  hlddayofweek <- as.numeric(format(holidays, "%u"))
  return(as.timeDate(holidays + obsdayofweek - hlddayofweek  + 7*(hlddayofweek > obsdayofweek)))
}
  
data.time <- as.timeDate(data$time)
  
data$USNewYearsDay <- isHoliday(data.time, holidays = adjHolidays(USNewYearsDay(years)), wday = 0:6)
data$USLaborDay <- isHoliday(data.time, holidays = adjHolidays(USLaborDay(years)), wday = 0:6)
data$USThanksgivingDay <- isHoliday(data.time, holidays = adjHolidays(USThanksgivingDay(years)), wday = 0:6)
data$CyberMonday <- isHoliday(data.time, holidays = adjHolidays(CyberMonday(years)), wday = 0:6)
data$ChristmasDay <-  isHoliday(data.time, holidays = adjHolidays(ChristmasDay(years)), wday=0:6)
  
# Another way of adding holiday features.
# Applies to daily/hourly data
# data$holiday <- FALSE
# holidays <- c("2013-08-15", "2013-11-30", "2013-12-01", "2014-04-20", "2014-04-21", 
#              "2014-05-01", "2014-06-08", "2014-06-09", "2014-08-15", "2014-11-30")
# for (i in 1:length(holidays)){
#   data$holiday[as.Date(data$time) == holidays[i]] <- TRUE
# }
  
# Fourier Features
num.ts <- nrow(unique(data[, c("ID1", "ID2")]))
ts.length <- nrow(data)/num.ts
t <- (index(data) - 1) %% ts.length %% seasonality 
  
for (s in 1:4){
  data[[paste("FreqCos", toString(s), sep="")]] = cos(t*2*pi*s/seasonality)
  data[[paste("FreqSin", toString(s), sep="")]] = sin(t*2*pi*s/seasonality)
}

data$time <- as.character(data$time)
####################################################################################################
## Log transform and save the completed feature dataset into SQL table
####################################################################################################
features_table <- RxSqlServerData(table = "features",
                                  connectionString = connection_string)
rxDataStep(inData = data,
           outFile = features_table,
           transforms = list(value = log(value)),
           overwrite = TRUE)
####################################################################################################
## Create train data
####################################################################################################
## ------- User-Defined Parameters ------ ##
lags <- 1:26
ratio <- 1
## ----------------------------------------- ##
  
horizon <- test.length 
  
data <- rxImport(features_table)
  
shift<-function(lag, x){c(rep(NA, lag), head(x,-lag))}
shift<- Vectorize(shift, vectorize.args = "lag")
  
addlags_oneh <- function(h, lags, df, var){
  res <- shift(lags+h-1, x=df[,var])
  colnames(res) <- paste("lag", lags, sep = "")
  return(cbind(df,res))
}
  
addlags <- function(df, var, lags, maxh){
  horizons <- 1:maxh
  res <- adply(horizons, .margin = 1, .fun = addlags_oneh, lags = lags, df = df, var = var)
  res <- rename(res, replace = c("X1" = "horizon"))
  res <- res[complete.cases(res), ]
  return(res)
}
  
train.addlags <- function(df, var, lags, maxh){
  data.length <- nrow(df)
  train.length <- data.length - test.length
  train <- df[1:train.length, , drop = FALSE]
    
  res <- addlags(train, var, lags, maxh)
  return(res)
}
  
train.length <- nrow(data) - test.length
train <- data[1:train.length, , drop = FALSE]
  
train_data <- ddply(train, 
              .variables = .(ID1, ID2),
              .fun = addlags, 
              var = "value", 
              lags = lags, 
              maxh = horizon)
  
if(ratio < 1){
  downsample <- function(data, ratio){ data[sample(nrow(data), size = ratio*nrow(data)),]}
  train_data <- ddply(train_data, .variables = .(ID1, ID2), .fun = downsample, ratio = ratio)
}

train_data$time <- as.character(train_data$time)  

train_table <- RxSqlServerData(table = "train",
                               connectionString = connection_string)  
rxDataStep(inData = train_data,
             outFile = train_table,
             overwrite = TRUE)
####################################################################################################
## Create test data
####################################################################################################
test.addlags <- function(df, var, lags){
  data.length <- nrow(df)
  train.length <- data.length - test.length
  test  <- df[(train.length+1):data.length, , drop = FALSE]
  train  <- df[1:train.length, , drop = FALSE]
    
  # Missing data: replace NA with average
  train$value[is.na(train$value)] <- mean(train$value, na.rm = TRUE)
    
  # Create lag features
  test$horizon <- as.factor(1:test.length)
    
  test.lags <- df[train.length - lags + 1, var]
  test.lags <- matrix(rep(test.lags, test.length), nrow = test.length, byrow = TRUE)
  colnames(test.lags) <- paste("lag", lags, sep = "")
  res <- cbind(test, test.lags)
    
  return(res)
}
  
test_data <- ddply(data, .variables = .(ID1, ID2), .fun = test.addlags, var = "value", lags = lags)
  
#print(dim(output))
#print(ddply(output, .variables = .(ID1, ID2), .fun = nrow))
  
if(ratio < 1){
  downsample <- function(data, ratio){ data[sample(nrow(data), size = ratio*nrow(data)),]}
  test_data <- ddply(test_data, .variables = .(ID1, ID2), .fun = downsample, ratio = ratio)
}

test_data$time <- as.character(test_data$time)
test_table <- RxSqlServerData(table = "test",
                              connectionString = connection_string)

rxDataStep(inData = test_data,
           outFile = test_table,
           overwrite = TRUE)
####################################################################################################
## Cleanup
####################################################################################################
rm(list = ls())