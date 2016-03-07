####################################################################################################
## Training regression models to answer questions on whether an engine will fail  fail in different 
## cycles. The models will be trained include:
## 1. Decision forest;
## 3. Boosted decision tree;
## 4. Multinomial modeling;
## 5. Neural network
## Input : The processed train and test dataset in SQL tables
## Output: The evaluations on test dataset and the metrics saved in SQL tables
####################################################################################################
####################################################################################################
## Connection string and compute context
####################################################################################################
connection_string <- "Driver=SQL Server;
                      Server=[SQL server name];
                      Database=[Database Name];
                      UID=[UserName];
                      PWD=[Password]"
sql_share_directory <- paste("c:\\AllShare\\", Sys.getenv("USERNAME"), sep = "")
dir.create(sql_share_directory, recursive = TRUE, showWarnings = FALSE)
sql <- RxInSqlServer(connectionString = connection_string,
                     shareDir = sql_share_directory)
local <- RxLocalParallel()
####################################################################################################
## Drop variables and make label a factor in train table
####################################################################################################
rxSetComputeContext(sql)
train_table_name <- "train_Features"
train_table <- RxSqlServerData(table = train_table_name,
                               connectionString = connection_string,
                               colInfo = list(label2 = list(type = "factor", 
                                                            levels = c("0", "1", "2"))))
####################################################################################################
## Find top 35 variables most correlated with label1
####################################################################################################
rxSetComputeContext(sql)
train_vars <- rxGetVarNames(train_table)
train_vars <- train_vars[!train_vars  %in% c("RUL", "label1", "id", "cycle_orig")]
formula <- as.formula(paste("~", paste(train_vars, collapse = "+")))
correlation <- rxCor(formula = formula, 
                     data = train_table,
                     transforms = list(label2 = as.numeric(label2)))
correlation <- correlation[, "label2"]
correlation <- abs(correlation)
correlation <- correlation[order(correlation, decreasing = TRUE)]
correlation <- correlation[-1]
correlation <- correlation[1:35]
formula <- as.formula(paste(paste("label2~"),
                            paste(names(correlation), collapse = "+")))
####################################################################################################
## Import test into data frame for faster prediction and model evaluation
####################################################################################################
test_table_name <- "test_Features"
test_table <- RxSqlServerData(table = test_table_name,
                              connectionString = connection_string,
                              colInfo = list(label2 = list(type = "factor", 
                                                           levels = c("0", "1", "2"))))
prediction_df <- rxImport(inData = test_table)
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
## Decision forest modeling
####################################################################################################
rxSetComputeContext(sql)
forest_model <- rxDForest(formula = formula,
                          data = train_table,
                          nTree = 8,
                          maxDepth = 32,
                          mTry = 35,
                          seed = 5)
rxSetComputeContext(local)
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
## Boosted tree modeling
####################################################################################################
rxSetComputeContext(sql)
boosted_model <- rxBTrees(formula = formula,
                          data = train_table,
                          learningRate = 0.2,
                          minSplit = 10,
                          minBucket = 10,
                          nTree = 100,
                          seed = 5,
                          lossFunction = "multinomial")
rxSetComputeContext(local)
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
## Multinomial modeling
####################################################################################################
library(nnet)
rxSetComputeContext(local)
train_df <- rxImport(inData = train_table)

multinomial_model <- multinom(formula = formula,
                              data = train_df)

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
## Neural network regression modeling
####################################################################################################
library(nnet)
rxSetComputeContext(local)
nodes <- 10
weights <- nodes * (35 + 3) + nodes + 3

nnet_model <- nnet(formula = formula,
                   data = train_df,
                   Wts = rep(0.1, weights),
                   size = nodes,
                   decay = 0.005,
                   maxit = 100,
                   MaxNWts = weights)

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
rxSetComputeContext(local)
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
           overwrite = TRUE)
####################################################################################################
## Cleanup
####################################################################################################
rm(list = ls())