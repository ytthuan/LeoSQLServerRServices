SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS generate_dataset 
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [generate_dataset] @testlength int
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
## ----------------------------------------- ##
  
horizon <- testlength 
  
data <- InputDataSet
  
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
rm(list = ls())'