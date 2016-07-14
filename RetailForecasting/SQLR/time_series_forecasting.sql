SET ANSI_NULLS ON
GO

/****** Create the Stored Procedure for PM Template ******/

SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS time_series_forecasting
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [time_series_forecasting] @testlength int,
					   @modelname varchar(10),
					   @connectionString varchar(300),
                                           @testtype varchar(10)
AS
BEGIN

  DECLARE @inquery NVARCHAR(max) = N'SELECT * FROM forecasting'
  
  EXEC sp_execute_external_script @language = N'R',
                                  @script = N'
library(forecast)
library(plyr)
####################################################################################################
## Compute context
####################################################################################################
sql_share_directory <- paste("c:\\AllShare\\", Sys.getenv("USERNAME"), sep = "")
dir.create(sql_share_directory, recursive = TRUE)
sql <- RxInSqlServer(connectionString = connection_string, 
                     shareDir = sql_share_directory)
local <- RxLocalSeq()
####################################################################################################
## Modeling parameters
####################################################################################################
seasonality <- 52
horizon <- testlength
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
  
data_input <- InputDataSet
 
# Forecasting Function
forecast_func <- function(data, model.name) {
  train.length <- nrow(data) - horizon
  train <- data[1:train.length, ]
  test <- data[(train.length+1):nrow(data), ]	
  test_ts <- test$time
	    
  # Missing data: replace na with average
  train$value[is.na(train$value)] <- mean(train$value, na.rm = TRUE)
    
  # Build forecasting models
  train.ts <- ts(train$value, frequency = seasonality, start = date.info(train))
  if (model.name == "ets") {
    train.stl <- stl(train.ts, s.window="periodic")
    train.model <- forecast(train.stl, h = horizon, method = "ets", ic = "bic", opt.crit="mae")
  } else if (model.name == "snaive") {
    train.model <- snaive(train.ts, h = horizon)
  } else {
    train.model <- stlf(train.ts, h = horizon, method = "arima", s.window = "periodic")
  } 
  
  forecast.value <- train.model$mean
  forecast.lo95 <- train.model$lower[,1]
  forecast.hi95 <- train.model$upper[,1]

  output <- data.frame(time = test_ts, cbind(forecast.value, forecast.lo95, forecast.hi95))
  colnames(output)[-1] <- c("forecast_value", "lo95", "hi95") 
    
  return(output)
}
data_output <- ddply(data_input, .(ID1, ID2), forecast_func, modelname)

# For testing, the metrics will be calculated and save into SQL table
if (test_type == "prod") {
  table_name <- paste("Score_", modelname, sep = "")
} else {
  table_name <- paste("forecasts_test_", modelname, sep = "")
  res <- join(data_output, data_input, by = c("ID1", "ID2", "time"), match = "all")
  accur <- as.data.frame(accuracy(res$value, res$forecast_value))
  metrics <- data.frame(Method = modelname, accur)
  metrics_table <- RxSqlServerData(table = paste("metrics_", modelname, sep = ""),
                                   connectionString = connection_string)
  rxDataStep(inData = metrics,
             outFile = metrics_table,
             overwrite = TRUE)
}

forecast_table <- RxSqlServerData(table = table_name,
                                  connectionString = connection_string)

rxDataStep(inData = data_output,
           outFile = forecast_table,
           overwrite = TRUE)'
, @input_data_1 = @inquery
, @params = N'@testlength int, @modelname varchar(10), @connection_string varchar(300), @test_type varchar(10)'
, @testlength = @testlength 
, @modelname = @modelname
, @connection_string = @connectionString 
, @test_type = @testtype                    
END
;
GO