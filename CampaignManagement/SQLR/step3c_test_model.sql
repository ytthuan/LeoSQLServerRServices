/****** Stored Procedure to test and evaluate the models trained in step 3-b) ******/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[TestModel]
GO

CREATE PROCEDURE [TestModel] @modelrf varchar(20),
		             @modelbtree varchar(20),
		             @connectionString varchar(300)
AS 
BEGIN
	DROP TABLE IF EXISTS best_model
	CREATE TABLE best_model (best_model varchar(10))

	DECLARE @inquery NVARCHAR(max) = N'SELECT * FROM CM_AD1 WHERE Split_Vector = 0';
	DECLARE @model_rf varbinary(max) = (select model from Campaign_Models where model_name = @modelrf);
	DECLARE @model_btree varbinary(max) = (select model from Campaign_Models where model_name = @modelbtree);
	INSERT INTO best_model
	EXECUTE sp_execute_external_script @language = N'R',
     					   @script = N' 
####################################################################################################
##	Dataset for test
####################################################################################################
prediction_df <- InputDataSet
prediction_df$Conversion_Flag <- factor(prediction_df$Conversion_Flag, levels = c("0", "1"))
####################################################################################################
## Model evaluation metrics
####################################################################################################
evaluate_model <- function(observed, predicted_probability, threshold) { 
  
  # Given the observed labels and the predicted probability, determine the AUC.
  data <- data.frame(observed, predicted_probability)
  data$observed <- as.numeric(as.character(data$observed))
  ROC <- rxRoc(actualVarName = "observed", predVarNames = "predicted_probability", data = data, numBreaks = 1000)
  auc <- rxAuc(ROC)
  
  # Given the predicted probability and the threshold, determine the binary prediction.
  predicted <- ifelse(predicted_probability > threshold, 1, 0) 
  predicted <- factor(predicted, levels = c(0, 1)) 
  
  # Build the corresponding Confusion Matrix, then compute the Accuracy, Precision, Recall, and F-Score.
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
  
  # Return the computed metrics.
  metrics <- c("Accuracy" = accuracy, 
                "Precision" = precision, 
                "Recall" = recall, 
                "F-Score" = fscore,
                "AUC" = auc) 
  return(metrics) 
} 
####################################################################################################
## Decision forest modeling
####################################################################################################
forest_model <- unserialize(forest_model)
forest_prediction <- rxPredict(modelObject = forest_model,
			       data = prediction_df,
			       type = "prob",
                   extraVarsToWrite = c("Conversion_Flag"),

overwrite = TRUE)

threshold <- median(forest_prediction$X1_prob)

forest_metrics <- evaluate_model(observed = prediction_df$Conversion_Flag,
                                 predicted_probability = forest_prediction$X1_prob,
				 threshold = threshold)

####################################################################################################
## Boosted tree modeling
####################################################################################################
boosted_model <- unserialize(boosted_model)
boosted_prediction <- rxPredict(modelObject = boosted_model,
                                data = prediction_df,
                                type = "prob",
				extraVarsToWrite = c("Conversion_Flag"),
                                overwrite = TRUE)

threshold <- median(boosted_prediction$X1_prob)

boosted_metrics <- evaluate_model(observed = prediction_df$Conversion_Flag,
                                  predicted_probability = boosted_prediction$X1_prob,
				  threshold = threshold)

####################################################################################################
## Write test predictions to SQL
####################################################################################################
predictions <- cbind(Lead_Id = prediction_df$Lead_Id, 
                     Channel = prediction_df$Channel, 
			       Conversion_Flag = as.character(prediction_df$Conversion_Flag),
			       Conversion_Flag_Pred_RF = as.character(forest_prediction$Conversion_Flag),
			       Conversion_Flag_Pred_BT = as.character(boosted_prediction$Conversion_Flag))

prediction_table <- RxSqlServerData(table = "Prediction_Test",
                                    connectionString = connection_string)
rxDataStep(inData = as.data.frame(predictions),
           outFile = prediction_table,
           overwrite = TRUE)

####################################################################################################
## Combine metrics and write to SQL
####################################################################################################
metrics_df <- rbind(forest_metrics, boosted_metrics)
metrics_df <- as.data.frame(metrics_df)
rownames(metrics_df) <- NULL
Algorithms <- c("Random Forest",
                "Boosted Decision Tree")
metrics_df <- cbind(Algorithms, metrics_df)

metrics_table <- RxSqlServerData(table = "Campaign_metrics",
                                 connectionString = connection_string)
rxDataStep(inData = metrics_df,
           outFile = metrics_table,
           overwrite = TRUE)
##########################################################################################################################################
## Select the best model based on AUC
##########################################################################################################################################
OutputDataSet <- data.frame(ifelse(forest_metrics[5] >= boosted_metrics[5], "RF", "GBT"))		 		   	   	   
	   '
, @input_data_1 = @inquery
, @params = N'@forest_model varbinary(max), @boosted_model varbinary(max), @connection_string varchar(300)'
, @forest_model = @model_rf
, @boosted_model = @model_btree
, @connection_string = @connectionString

;
END
GO
