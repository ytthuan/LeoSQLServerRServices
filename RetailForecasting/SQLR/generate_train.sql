SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS generate_train 
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [generate_train] @connectionString varchar(300),               
			                      @num_folds int,
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
  
train.length <- nrow(data) - testlength
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

if (num_folds > 1) {
  train_rows <- seq(1:nrow(train_data))
  train_size <- floor(nrow(train_data) / num_folds)

  for (i in 1:num_folds) {
    rows <- sample(train_rows, train_size)
    train_rows <- train_rows[!train_rows %in% rows]
    fold <- train_data[rows, ]    
    fold_table <- RxSqlServerData(table = paste0("train_fold", i), 
                                  connectionString = connection_string)
    rxDataStep(inData = fold,
               outFile = fold_table,
               overwrite = TRUE)
  }
}'
, @input_data_1 = @inquery
, @params = N'@connection_string varchar(300), @num_folds int, @testlength int'
, @connection_string = @connectionString 
, @num_folds = @num_folds   
, @testlength = @testlength                  
END

;
GO