SET ANSI_NULLS ON
GO

/****** Create the Stored Procedure for retail forecasting Template ******/

SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS data_preprocess_score
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [data_preprocess_score] @testlength int,
                                         @id1value int,
				         @id2value int,
				         @connectionString varchar(300)
AS
BEGIN

  DECLARE @inquery NVARCHAR(max) = N'SELECT * FROM forecastinginput where ID1 = @id1value and ID2 = @id2value'
  
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
seasonality <- 52
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

judge <- businessrule(data) 
if(judge != 0) stop("ineligible time series")
 
min.time <- min(data$time)
max.time <- max(data$time)
  
unique.time <- seq(from = min.time, to = max.time, by = observation.freq)
forecast.time <- seq(from = max.time, by = observation.freq, length.out = testlength + 1)[-1]
all.time <- c(unique.time, forecast.time)
all.time <- data.frame(ID1 = data$ID1[1], ID2 = data$ID2[1], time = all.time)

# Join the combination with original data
data <- join(all.time, data, by = c("ID1", "ID2", "time"), type = "left")

data$time <- as.character(data$time)
forecasting_table <- RxSqlServerData(table = "forecasting",
                                     connectionString = connection_string)
rxDataStep(inData = data,
           outFile = forecasting_table,
           overwrite = TRUE)'
, @input_data_1 = @inquery
, @params = N'@testlength int, @connection_string varchar(300), @id1value int, @id2value int'
, @testlength = @testlength 
, @connection_string = @connectionString 
, @id1value = @id1value
, @id2value = @id2value                    
END
;
GO

