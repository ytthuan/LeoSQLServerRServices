SET ANSI_NULLS ON
GO

/****** Create the Stored Procedure for PM Template ******/

SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS data_preprocess
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [data_preprocess] @testlength int,
				                   @connectionString varchar(300)
AS
BEGIN

  DECLARE @inquery NVARCHAR(max) = N'SELECT * FROM forecastinginput'
  
  EXEC sp_execute_external_script @language = N'R',
                                  @script = N'

####################################################################################################
## Modeling parameters
####################################################################################################
observation.freq <- "week"
timeformat <- "%m/%d/%Y"
####################################################################################################
## Select eligible time series based on business rules
####################################################################################################
data <- InputDataSet
## ------- User-Defined Parameters ------ ##
min.length <- 2*testlength
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
  train.length <- data.length - testlength
    
  tsvalues <- data$value
    
  # Select Eligible Time Series based on training and testing principals:
  # Rule 3: if the last 6 values in trainning set are all NA, discard
  if (sum(is.na(tsvalues[(train.length - 5) : train.length])) == 6) 
    return(c(judge = 3))
    
  # Rule 4: if test data has more than a half NA, discard
  if (testlength > 0 && sum(is.na(tsvalues[(train.length+1):data.length])) > testlength / 2) 
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
           overwrite = TRUE)'
, @input_data_1 = @inquery
, @params = N'@testlength int, @connection_string varchar(300)'
, @testlength = @testlength 
, @connection_string = @connectionString                     
END
;
GO

