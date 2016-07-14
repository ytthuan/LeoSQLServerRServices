library(forecast)
library(plyr)
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
## Modeling parameters
####################################################################################################
test.length <- 52
seasonality <- 52
observation.freq <- "week"
timeformat <- "%m/%d/%Y"
####################################################################################################
## Time Series Model
##   1: Seasonal trend decomposition (STL) +  exponential smoothing (ETS)
##   2: Seasonal naive
##   3: Seasonal trend decomposition (STL) + ARIMA
####################################################################################################
# Helper functions extracting date-related information
weeknum <- function(date) {
  date <- as.Date(date)
  as.numeric(format(date, "%U"))
}
year <- function(date) {
  date <- as.Date(date)
  as.numeric(format(date, "%Y"))
}
date.info <- function(df) { 
  date <- df$time[1]
  c(year(date), weeknum(date))
}

horizon <- test.length

forecasting_table <- RxSqlServerData(table = "forecasting",
                                     connectionString = connection_string)
  
data_input <- rxImport(forecasting_table)
 
# Forecasting Function
forecast_func <- function(data, model.name) {
    
  # Train and test split
  data.length <- nrow(data)
  train.length <- data.length - horizon
  train <- data[1:train.length, ]
  test <- data[(train.length+1):data.length, ]
    
  # Missing data: replace na with average
  train$value[is.na(train$value)] <- mean(train$value, na.rm = TRUE)
    
  # Build forecasting models
  train.ts <- ts(train$value, frequency = seasonality, start = date.info(train))
  if (model.name == "STL_ETS") {
    train.stl <- stl(train.ts, s.window="periodic")
    train.model <- forecast(train.stl, h = horizon, method = 'ets', ic = 'bic', opt.crit='mae')
  } else if (model.name == "snaive") {
    train.model <- snaive(train.ts, h = horizon)
  } else {
    train.model <- stlf(train.ts, h = horizon, method = "arima", s.window = "periodic")
  } 
  
  forecast.value <- train.model$mean
  forecast.lo95 <- train.model$lower[,1]
  forecast.hi95 <- train.model$upper[,1]
  
  output <- data.frame(time = test$time, cbind(forecast.value, forecast.lo95, forecast.hi95))
  colnames(output)[-1] <- paste(c("forecast", "lo95", "hi95"), model.name, sep = ".") 
    
  return(output)
}
data_stlets <- ddply(data_input, .(ID1, ID2), forecast_func, "STL_ETS")
data_snaive <- ddply(data_input, .(ID1, ID2), forecast_func, "snaive")
data_arima <- ddply(data_input, .(ID1, ID2), forecast_func, "STL_ARIMA")
  
data <- join(data_stlets, data_snaive, by = c("ID1", "ID2", "time"), type = "inner")
data <- join(data, data_arima, by = c("ID1", "ID2", "time"), type = "inner")

all_forecasts_table <- RxSqlServerData(table = "all_forecasts",
                                       connectionString = connection_string)
  
rxDataStep(inData = data,
           outFile = all_forecasts_table,
           overwrite = TRUE)

####################################################################################################
## Cleanup
####################################################################################################
rm(list = ls())