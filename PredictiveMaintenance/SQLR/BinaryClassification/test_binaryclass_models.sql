SET ANSI_NULLS ON
GO

/****** Create the Stored Procedure for PM Template ******/

SET QUOTED_IDENTIFIER ON
GO

drop procedure if exists test_binaryclass_models;
go
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [test_binaryclass_models] @modelrf varchar(20),
                                           @modelbtree varchar(20),
                                           @modellogit varchar(20),
                                           @modelnn varchar(20),
                                           @connectionString varchar(300)
AS 
BEGIN
  DECLARE @inquery NVARCHAR(max) = N'SELECT * FROM test_Features_Normalized';
  declare @model_rf varbinary(max) = (select model from [PM_Models] where model_name = @modelrf);
  declare @model_btree varbinary(max) = (select model from [PM_Models] where model_name = @modelbtree);
  declare @model_logit varbinary(max) = (select model from [PM_Models] where model_name = @modellogit);
  declare @model_nn varbinary(max) = (select model from [PM_Models] where model_name = @modelnn);  

  EXEC sp_execute_external_script @language = N'R',
                                  @script = N'
####################################################################################################
## Import test into data frame for faster prediction and model evaluation
####################################################################################################
prediction_df <- InputDataSet
prediction_df$label1 <- factor(prediction_df$label1, levels = c("0", "1"))
####################################################################################################
## Classification model evaluation metrics
####################################################################################################
evaluate_model <- function(observed, predicted) {
  confusion <- table(observed, predicted)
  print(confusion)
  tp <- confusion[1, 1]
  fn <- confusion[1, 2]
  fp <- confusion[2, 1]
  tn <- confusion[2, 2]
  accuracy <- (tp + tn) / (tp + fn + fp + tn)
  precision <- tp / (tp + fp)
  recall <- tp / (tp + fn)
  fscore <- 2 * (precision * recall) / (precision + recall)
  metrics <- c("Accuracy" = accuracy,
               "Precision" = precision,
               "Recall" = recall,
               "F-Score" = fscore)
  return(metrics)
}
####################################################################################################
## Decision forest modeling
####################################################################################################
forest_model <- unserialize(forest_model)
forest_prediction <- rxPredict(modelObject = forest_model,
                               data = prediction_df,
                               type = "prob",
                               overwrite = TRUE)
threshold <- 0.5
forest_prediction$X0_prob <- NULL
forest_prediction$label1_Pred <- NULL
names(forest_prediction) <- c("Forest_Probability")
forest_prediction$Forest_Prediction <- ifelse(forest_prediction$Forest_Probability > threshold, 1, 0)
forest_prediction$Forest_Prediction <- factor(forest_prediction$Forest_Prediction, levels = c(0, 1))

forest_metrics <- evaluate_model(observed = prediction_df$label1,
                                 predicted = forest_prediction$Forest_Prediction)
####################################################################################################
## Boosted tree modeling
####################################################################################################
boosted_model <- unserialize(boosted_model)
boosted_prediction <- rxPredict(modelObject = boosted_model,
                                data = prediction_df,
                                type = "prob",
                                overwrite = TRUE)
threshold <- 0.5
names(boosted_prediction) <- c("Boosted_Probability")
boosted_prediction$Boosted_Prediction <- ifelse(boosted_prediction$Boosted_Probability > threshold, 1, 0)
boosted_prediction$Boosted_Prediction <- factor(boosted_prediction$Boosted_Prediction, levels = c(0, 1))

boosted_metrics <- evaluate_model(observed = prediction_df$label1,
                                  predicted = boosted_prediction$Boosted_Prediction)

####################################################################################################
## Logistic regression modeling
####################################################################################################
logistic_model <- unserialize(logistic_model)
logistic_prediction <- rxPredict(modelObject = logistic_model,
                         	  data = prediction_df,
                         	  type = "response",
                         	  overwrite = TRUE)
threshold <- 0.5
names(logistic_prediction) <- c("Logistic_Probability")
logistic_prediction$Logistic_Prediction <- ifelse(logistic_prediction$Logistic_Probability > threshold, 1, 0)
logistic_prediction$Logistic_Prediction <- factor(logistic_prediction$Logistic_Prediction, levels = c(0, 1))

logistic_metrics <- evaluate_model(observed = prediction_df$label1,
                                   predicted = logistic_prediction$Logistic_Prediction)

####################################################################################################
## Neural network regression modeling
####################################################################################################
library(nnet)
nnet_model <- unserialize(nnet_model)
nnet_prediction <- predict(object = nnet_model,
                           newdata = prediction_df)
nnet_prediction <- as.data.frame(nnet_prediction)
threshold <- 0.5
names(nnet_prediction) <- c("Nnet_Probability")
nnet_prediction$Nnet_Prediction <- ifelse(nnet_prediction$Nnet_Probability > threshold, 1, 0)
nnet_prediction$Nnet_Prediction <- factor(nnet_prediction$Nnet_Prediction, levels = c(0, 1))

nnet_metrics <- evaluate_model(observed = prediction_df$label1,
                               predicted = nnet_prediction$Nnet_Prediction)

####################################################################################################
## Write test predictions to SQL
####################################################################################################
predictions <- cbind(prediction_df$id, prediction_df$cycle_orig, forest_prediction, 
                     boosted_prediction, logistic_prediction, nnet_prediction)
colnames(predictions)[1] <- "id"
colnames(predictions)[2] <- "cycle"

prediction_table <- RxSqlServerData(table = "Binary_prediction",
                                    connectionString = connection_string)
rxDataStep(inData = predictions,
           outFile = prediction_table,
           overwrite = TRUE)
####################################################################################################
## Combine metrics and write to SQL
####################################################################################################
metrics_df <- rbind(forest_metrics, boosted_metrics, logistic_metrics, nnet_metrics)
metrics_df <- as.data.frame(metrics_df)
rownames(metrics_df) <- NULL
Algorithms <- c("Decision Forest",
                "Boosted Decision Tree",
                "Logistic Regression",
                "Neural Network")
metrics_df <- cbind(Algorithms, metrics_df)

metrics_table <- RxSqlServerData(table = "Binary_metrics",
                                 connectionString = connection_string)
rxDataStep(inData = metrics_df,
           outFile = metrics_table,
           overwrite = TRUE)'
, @input_data_1 = @inquery
, @params = N'@forest_model varbinary(max), @boosted_model varbinary(max), @logistic_model varbinary(max), @nnet_model varbinary(max), @connection_string varchar(300)'
, @forest_model = @model_rf
, @boosted_model = @model_btree
, @logistic_model = @model_logit
, @nnet_model = @model_nn
, @connection_string = @connectionString

END

GO

