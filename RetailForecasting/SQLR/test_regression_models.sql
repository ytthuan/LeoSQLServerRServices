SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS test_regression_models
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [test_regression_models] @connectionString varchar(300)

AS
BEGIN
  declare @inquery NVARCHAR(max) = N'SELECT * FROM test';
  declare @model_rf varbinary(max) = (select top 1 model from [RetailForecasting_models_rf]);
  declare @model_btree varbinary(max) = (select top 1 model from [RetailForecasting_models_btree]);
  
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
## Import test into data frame for faster prediction and model evaluation
####################################################################################################
test_table <- RxSqlServerData(table = "test",
                              connectionString = connection_string)
prediction_df <- InputDataSet
####################################################################################################
## Regression model evaluation metrics
####################################################################################################
evaluate_model <- function(data, observed, predicted, model_name) {
  data <- data[, c(observed, predicted)]
  data <- data[complete.cases(data), ]
  mean_observed <- mean(data[[observed]])
  data$se <- (data[[observed]] - data[[predicted]])^2
  data$ae <- abs(data[[observed]] - data[[predicted]])
  data$sem <- (data[[observed]] - mean(data[[observed]]))^2
  data$aem <- abs(data[[observed]] - mean(data[[observed]]))
  mae <- mean(data$ae)
  rmse <- sqrt(mean(data$se))
  rae <- sum(data$ae) / sum(data$aem)
  rse <- sum(data$se) / sum(data$sem)
  rsq <- 1 - rse
  metrics <- c("Model Name" = model_name,
               "Mean Absolute Error" = mae,
               "Root Mean Squared Error" = rmse,
               "Relative Absolute Error" = rae,
               "Relative Squared Error" = rse,
               "Coefficient of Determination" = rsq)
  return(metrics)
}
####################################################################################################
## Boosted tree modeling
####################################################################################################
boosted_model <- unserialize(boosted_model)
predictions <- rxPredict(modelObject = boosted_model,
                         data = prediction_df,
                         predVarNames = "forecast.BstDecTree",
                         overwrite = TRUE)
prediction_df <- cbind(prediction_df, predictions)
boosted_metrics <- evaluate_model(data = prediction_df,
                                  observed = "value",
                                  predicted = "forecast.BstDecTree",
                                  "boosted tree")
prediction_df$forecast.BstDecTree <- exp(prediction_df$forecast.BstDecTree)
####################################################################################################
## Decision forest modeling
####################################################################################################
forest_model <- unserialize(forest_model)
predictions <- rxPredict(modelObject = forest_model,
                         data = prediction_df,
                         predVarNames = "forecast.DecFore",
                         overwrite = TRUE)
prediction_df <- cbind(prediction_df, predictions)
forest_metrics <- evaluate_model(data = prediction_df,
                                  observed = "value",
                                  predicted = "forecast.DecFore",
                                  "decision forest")
prediction_df$forecast.DecFore <- exp(prediction_df$forecast.DecFore)
####################################################################################################
## Write test predictions and metrics to SQL
####################################################################################################
rxSetComputeContext(local)
metrics_df <- as.data.frame(rbind(boosted_metrics, forest_metrics))
metrics_table <- RxSqlServerData(table = "regression_forecasts_metrics",
                                 connectionString = connection_string)
rxDataStep(inData = metrics_df,
           outFile = metrics_table,
           overwrite = TRUE)

prediction_df <- prediction_df[, c("ID1", "ID2", "time", "forecast.BstDecTree", "forecast.DecFore")]

prediction_table <- RxSqlServerData(table = "regression_forecasts",
                                    connectionString = connection_string)
rxDataStep(inData = prediction_df,
           outFile = prediction_table,
           overwrite = TRUE)'
, @input_data_1 = @inquery
, @params = N'@forest_model varbinary(max), @boosted_model varbinary(max), @connection_string varchar(300)'
, @forest_model = @model_rf
, @boosted_model = @model_btree
, @connection_string = @connectionString  
                    
END
GO