SET ANSI_NULLS ON
GO

/****** Create the Stored Procedure for PM Template ******/

SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS feature_engineering 
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [feature_engineering] @connectionString varchar(300),
				       @testLength int
AS
BEGIN
  DECLARE @inquery NVARCHAR(max) = N'SELECT * from forecasting'
  EXEC sp_execute_external_script @language = N'R',
                                  @script = N'

####################################################################################################
## Compute context
####################################################################################################
sql_share_directory <- paste("c:\\AllShare\\", Sys.getenv("USERNAME"), sep = "")
dir.create(sql_share_directory, recursive = TRUE)
sql <- RxInSqlServer(connectionString = connection_string, 
                     shareDir = sql_share_directory)
local <- RxLocalSeq()
####################################################################################################
## Load income data into SQL table
####################################################################################################
rxSetComputeContext(local)

income_data_table <- RxSqlServerData(table = "forecasting_personal_income",
                                     connectionString = connection_string)
data <- InputDataSet
idx <- rxImport(income_data_table)
####################################################################################################
## Add economic index and select lags based on max correlation
####################################################################################################
addlag <- function(data) {
  # Train and test split
  data.length <- NROW(data$time)
  train.length <- data.length - test_length
  
  # Preparation
  data.start <- data$time[1]
  data.obs.diff <- as.numeric(data$time[2] - data$time[1])
  idx.start <- idx$time[1]
  
  maxlag <- as.numeric(data.start -idx.start)/data.obs.diff
  idx.cor.startid <- 1 + (maxlag > seasonality) * (maxlag - seasonality)
  
  # Moving average of one season
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
  # Index with the maximum correlation
  maxcorr <- which.max(abs(correlation))
  bestlag <- seasonality - maxcorr + 1
  # The selected idx 
  bestidx <- idx$value[maxcorr:(maxcorr+data.length-1)]
  return(bestidx)
}

####################################################################################################
## Modeling parameters
####################################################################################################
seasonality <- 52
observation.freq <- "week"
timeformat <- "%m/%d/%Y"

library(forecast)
library(zoo)
library(plyr)
  
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
rxSetComputeContext(local)
features_table <- RxSqlServerData(table = "features",
                                  connectionString = connection_string)
rxDataStep(inData = data,
           outFile = features_table,
           transforms = list(value = log(value)),
           overwrite = TRUE)'
, @input_data_1 = @inquery
, @params = N'@connection_string varchar(300), @test_length int'
, @connection_string = @connectionString  
, @test_length = @testLength                     
END

;
GO