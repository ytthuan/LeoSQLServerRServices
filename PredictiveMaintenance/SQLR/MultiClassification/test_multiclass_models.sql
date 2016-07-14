SET ANSI_NULLS ON
GO

/****** Create the Stored Procedure for PM Template ******/

SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS test_multiclass_models
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [test_multiclass_models] @modelrf varchar(20),
                                            @modelbtree varchar(20),
                                            @modelnn varchar(20),
                                            @modelmn varchar(20),
                                            @connectionString varchar(300)

AS
BEGIN
  DECLARE @inquery NVARCHAR(max) = N'SELECT * FROM test_Features_Normalized';
  declare @model_rf varbinary(max) = (select model from [PM_Models] where model_name = @modelrf);
  declare @model_nn varbinary(max) = (select model from [PM_Models] where model_name = @modelnn);
  declare @model_mn varbinary(max) = (select model from [PM_Models] where model_name = @modelmn);
  declare @model_btree varbinary(max) = (select model from [PM_Models] where model_name = @modelbtree);
  
  EXEC sp_execute_external_script @language = N'R',
                                  @script = N'
####################################################################################################
## Get test data from the input
####################################################################################################
prediction_df <- InputDataSet
prediction_df$label2 <- factor(prediction_df$label2, levels = c("0", "1", "2"))
####################################################################################################
## Mulit-classification model evaluation metrics
####################################################################################################
evaluate_model <- function(observed, predicted) {
  confusion <- table(observed, predicted)
  num_classes <- nlevels(observed)
  tp <- rep(0, num_classes)
  fn <- rep(0, num_classes)
  fp <- rep(0, num_classes)
  tn <- rep(0, num_classes)
  accuracy <- rep(0, num_classes)
  precision <- rep(0, num_classes)
  recall <- rep(0, num_classes)
  for(i in 1:num_classes) {
    tp[i] <- sum(confusion[i, i])
    fn[i] <- sum(confusion[-i, i])
    fp[i] <- sum(confusion[i, -i])
    tn[i] <- sum(confusion[-i, -i])
    accuracy[i] <- (tp[i] + tn[i]) / (tp[i] + fn[i] + fp[i] + tn[i])
    precision[i] <- tp[i] / (tp[i] + fp[i])
    recall[i] <- tp[i] / (tp[i] + fn[i])
  }
  overall_accuracy <- sum(tp) / sum(confusion)
  average_accuracy <- sum(accuracy) / num_classes
  micro_precision <- sum(tp) / (sum(tp) + sum(fp))
  macro_precision <- sum(precision) / num_classes
  micro_recall <- sum(tp) / (sum(tp) + sum(fn))
  macro_recall <- sum(recall) / num_classes
  metrics <- c("Overall accuracy" = overall_accuracy,
               "Average accuracy" = average_accuracy,
               "Micro-averaged Precision" = micro_precision,
               "Macro-averaged Precision" = macro_precision,
               "Micro-averaged Recall" = micro_recall,
               "Macro-averaged Recall" = macro_recall)
  return(metrics)
}
####################################################################################################
## Decision forest prediction
####################################################################################################
forest_model <- unserialize(forest_model)
forest_prediction <- rxPredict(modelObject = forest_model,
                               data = prediction_df,
                               type = "prob",
                               overwrite = TRUE)

names(forest_prediction) <- c("Forest_Probability_Class_0",
                              "Forest_Probability_Class_1",
                              "Forest_Probability_Class_2",
                              "Forest_Prediction")

forest_metrics <- evaluate_model(observed = prediction_df$label2,
                                 predicted = forest_prediction$Forest_Prediction)
####################################################################################################
## Boosted tree prediction
####################################################################################################
boosted_model <- unserialize(boosted_model)
boosted_prediction <- rxPredict(modelObject = boosted_model,
                  	        data = prediction_df,
                        	type = "prob",
                         	overwrite = TRUE)

names(boosted_prediction) <- c("Boosted_Probability_Class_0",
                        	"Boosted_Probability_Class_1",
                        	"Boosted_Probability_Class_2",
                        	"Boosted_Prediction")

boosted_metrics <- evaluate_model(observed = prediction_df$label2,
                                  predicted = boosted_prediction$Boosted_Prediction)
####################################################################################################
## Multinomial prediction
####################################################################################################
library(nnet)
multinomial_model <- unserialize(multinomial_model)

mnet_prediction <- predict(object = multinomial_model,
                           newdata = prediction_df,
                           type = "prob")
mnet_prediction <- as.data.frame(mnet_prediction)
names(mnet_prediction) <- c("Multinomial_Probability_Class_0",
                            "Multinomial_Probability_Class_1",
                            "Multinomial_Probability_Class_2")


mnet_prediction_response <- predict(object = multinomial_model,
                                    newdata = prediction_df)

mnet_prediction_response <- as.data.frame(mnet_prediction_response)
names(mnet_prediction_response) <- "Multinomial_Prediction"
mnet_prediction <- cbind(mnet_prediction, mnet_prediction_response)
multinomial_metrics <- evaluate_model(observed = prediction_df$label2,
                                      predicted = mnet_prediction$Multinomial_Prediction)
####################################################################################################
## Neural network prediction
####################################################################################################
nodes <- 10
weights <- nodes * (35 + 3) + nodes + 3

nnet_model <- unserialize(nnet_model)

nnet_prediction <- predict(object = nnet_model,
                           newdata = prediction_df,
                           type = "raw")
nnet_prediction <- as.data.frame(nnet_prediction)
names(nnet_prediction) <- c("Nnet_Probability_Class_0",
                            "Nnet_Probability_Class_1",
                            "Nnet_Probability_Class_2")

nnet_prediction_response <- predict(object = nnet_model,
                                    newdata = prediction_df,
                                    type = "class")

nnet_prediction_response <- as.data.frame(nnet_prediction_response)
names(nnet_prediction_response) <- "Nnet_Prediction"
nnet_prediction <- cbind(nnet_prediction, nnet_prediction_response)
nnet_metrics <- evaluate_model(observed = prediction_df$label2,
                               predicted = nnet_prediction$Nnet_Prediction)
####################################################################################################
## Write test predictions to SQL
####################################################################################################
predictions <- cbind(prediction_df$id, prediction_df$cycle_orig, forest_prediction, 
                     boosted_prediction, mnet_prediction, nnet_prediction)
colnames(predictions)[1] <- "id"
colnames(predictions)[2] <- "cycle"

prediction_table <- RxSqlServerData(table = "Multiclass_prediction",
                                    connectionString = connection_string)
rxDataStep(inData = predictions,
           outFile = prediction_table,
           overwrite = TRUE)
####################################################################################################
## Combine metrics and write to SQL
####################################################################################################
metrics_df <- rbind(forest_metrics, boosted_metrics, multinomial_metrics, nnet_metrics)
metrics_df <- as.data.frame(metrics_df)
rownames(metrics_df) <- NULL
Algorithms <- c("Decision Forest",
                "Boosted Decision Tree",
                "Multinomial",
                "Neural Network")
metrics_df <- cbind(Algorithms, metrics_df)

metrics_table <- RxSqlServerData(table = "Multiclass_metrics",
                                 connectionString = connection_string)
rxDataStep(inData = metrics_df,
           outFile = metrics_table,
           overwrite = TRUE)'
, @input_data_1 = @inquery
, @params = N'@forest_model varbinary(max), @nnet_model varbinary(max), @multinomial_model varbinary(max), @boosted_model varbinary(max), @connection_string varchar(300)'
, @forest_model = @model_rf
, @nnet_model = @model_nn
, @multinomial_model = @model_mn
, @boosted_model = @model_btree
, @connection_string = @connectionString

END

GO

