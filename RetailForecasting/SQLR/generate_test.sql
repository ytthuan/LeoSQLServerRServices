SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS generate_test 
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [generate_test] @connectionString varchar(300),
                                 @testlength int
AS
BEGIN
  DECLARE @inquery NVARCHAR(max) = N'SELECT * from features'
  EXEC sp_execute_external_script @language = N'R',
                                  @script = N'
####################################################################################################
## Create train data
####################################################################################################
## ------- User-Defined Parameters ------ ##
lags <- 1:26
ratio <- 1 
horizon <- testlength   
data <- InputDataSet
 
library(zoo)
library(plyr)			 
####################################################################################################
## Create test data
####################################################################################################
test.addlags <- function(df, var, lags){
  data.length <- nrow(df)
  train.length <- data.length - testlength
  test  <- df[(train.length+1):data.length, , drop = FALSE]
  train  <- df[1:train.length, , drop = FALSE]
    
  # Missing data: replace NA with average
  train$value[is.na(train$value)] <- mean(train$value, na.rm = TRUE)
    
  # Create lag features
  test$horizon <- as.factor(1:testlength)
    
  test.lags <- df[train.length - lags + 1, var]
  test.lags <- matrix(rep(test.lags, testlength), nrow = testlength, byrow = TRUE)
  colnames(test.lags) <- paste("lag", lags, sep = "")
  res <- cbind(test, test.lags)
    
  return(res)
}
  
test_data <- ddply(data, .variables = .(ID1, ID2), .fun = test.addlags, var = "value", lags = lags)
  
if(ratio < 1){
  downsample <- function(data, ratio){ data[sample(nrow(data), size = ratio*nrow(data)),]}
  test_data <- ddply(test_data, .variables = .(ID1, ID2), .fun = downsample, ratio = ratio)
}

test_data$time <- as.character(test_data$time)
test_table <- RxSqlServerData(table = "test",
                              connectionString = connection_string)

rxDataStep(inData = test_data,
           outFile = test_table,
           overwrite = TRUE)'
, @input_data_1 = @inquery
, @params = N'@connection_string varchar(300), @testlength int'
, @connection_string = @connectionString  
, @testlength = @testlength                     
END

;
GO