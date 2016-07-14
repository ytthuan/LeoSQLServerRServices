SET ANSI_NULLS ON
GO

/****** Create the Stored Procedure for PM Template ******/

DROP PROCEDURE IF EXISTS [test_regression_models]
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [test_regression_models] @modelrf varchar(20),
                                          @modelbtree varchar(20),
                                          @modelglm varchar(20),
                                          @modelnn varchar(20),
                                          @connectionString varchar(300)   

AS
BEGIN

  declare @inquery NVARCHAR(max) = N'SELECT * FROM test_Features_Normalized';
  declare @model_rf varbinary(max) = (select model from [PM_Models] where model_name = @modelrf);
  declare @model_btree varbinary(max) = (select model from [PM_Models] where model_name = @modelbtree);
  declare @model_glm varbinary(max) = (select model from [PM_Models] where model_name = @modelglm);
  declare @model_nn varbinary(max) = (select model from [PM_Models] where model_name = @modelnn);
  declare @maxrul float = (SELECT MAX(RUL) FROM [train_Features_Normalized]);

  EXEC sp_execute_external_script @language = N'R',
                                  @script = N'
####################################################################################################
## Get test dataset from the input
####################################################################################################
prediction_df <- InputDataSet
####################################################################################################
## Regression model evaluation metrics
####################################################################################################
evaluate_model <- function(observed, predicted) {
  mean_observed <- mean(observed)
  se <- (observed - predicted)^2
  ae <- abs(observed - predicted)
  sem <- (observed - mean_observed)^2
  aem <- abs(observed - mean_observed)
  mae <- mean(ae)
  rmse <- sqrt(mean(se))
  rae <- sum(ae) / sum(aem)
  rse <- sum(se) / sum(sem)
  rsq <- 1 - rse
  metrics <- c("Mean Absolute Error" = mae,
               "Root Mean Squared Error" = rmse,
               "Relative Absolute Error" = rae,
               "Relative Squared Error" = rse,
               "Coefficient of Determination" = rsq)
  return(metrics)
}
####################################################################################################
## Decision forest prediction
####################################################################################################
forest_model <- unserialize(forest_model)
forest_prediction <- rxPredict(modelObject = forest_model,
                         data = prediction_df,
                         predVarNames = "Forest_Prediction",
                         overwrite = TRUE)
forest_metrics <- evaluate_model(observed = prediction_df$RUL,
                                 predicted = forest_prediction$Forest_Prediction)
####################################################################################################
## Boosted tree prediction
####################################################################################################
boosted_model <- unserialize(boosted_model)
boosted_prediction <- rxPredict(modelObject = boosted_model,
                         data = prediction_df,
                         predVarNames = "Boosted_Prediction",
                         overwrite = TRUE)
boosted_metrics <- evaluate_model(observed = prediction_df$RUL,
                                  predicted = boosted_prediction$Boosted_Prediction)
####################################################################################################
## Poisson regression prediction
####################################################################################################
poisson_model <- unserialize(poisson_model)
poisson_prediction <- rxPredict(modelObject = poisson_model,
                         data = prediction_df,
                         predVarNames = "Poisson_Prediction",
                         overwrite = TRUE)
poisson_metrics <- evaluate_model(observed = prediction_df$RUL,
                                  predicted = poisson_prediction$Poisson_Prediction)
####################################################################################################
## Neural network regression prediction
####################################################################################################
library(nnet)
nnet_model <- unserialize(nnet_model)
nnet_prediction <- predict(object = nnet_model,
                       	   newdata = prediction_df)
nnet_prediction <- nnet_prediction * max_train_rul
nnet_prediction <- as.data.frame(nnet_prediction)
names(nnet_prediction) <- "Nnet_Prediction"
nnet_metrics <- evaluate_model(observed = prediction_df$RUL,
                               predicted = nnet_prediction$Nnet_Prediction)
####################################################################################################
## Write test predictions to SQL
####################################################################################################
predictions <- cbind(prediction_df$id, prediction_df$cycle_orig, forest_prediction, 
                     boosted_prediction, poisson_prediction, nnet_prediction)
colnames(predictions) <- c("id", "cycle", "Forest_Prediction", "Boosted_Prediction", 
			   "Poisson_Prediction", "Nnet_Prediction")
prediction_table <- RxSqlServerData(table = "Regression_prediction",
                                    connectionString = connection_string)
rxDataStep(inData = predictions,
           outFile = prediction_table,
           overwrite = TRUE)
####################################################################################################
## Combine metrics and write to SQL
####################################################################################################
metrics_df <- rbind(forest_metrics, boosted_metrics, poisson_metrics, nnet_metrics)
metrics_df <- as.data.frame(metrics_df)
rownames(metrics_df) <- NULL
Algorithms <- c("Decision Forest",
                "Boosted Decision Tree",
                "Poisson Regression",
                "Neural Network")
metrics_df <- cbind(Algorithms, metrics_df)
metrics_table <- RxSqlServerData(table = "Regression_metrics",
                                 connectionString = connection_string)
rxDataStep(inData = metrics_df,
           outFile = metrics_table,
           overwrite = TRUE)'
, @input_data_1 = @inquery
, @params = N'@forest_model varbinary(max), @boosted_model varbinary(max), @poisson_model varbinary(max),  @nnet_model varbinary(max), @max_train_rul float, @connection_string varchar(300)'
, @forest_model = @model_rf
, @boosted_model = @model_btree
, @poisson_model = @model_glm
, @nnet_model = @model_nn
, @max_train_rul = @maxrul
, @connection_string = @connectionString

END

GO

