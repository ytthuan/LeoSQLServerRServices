####################################################################################################
## Training regression models to answer questions on whether an engine will fail within 30 cycles
## Four models will be trained:
## 1. Decision forest;
## 3. Boosted decision tree;
## 4. Logistic regression modeling;
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
                               colInfo = list(label1 = list(type = "factor", levels = c("0", "1"))))
####################################################################################################
## Find top 35 variables most correlated with label1
####################################################################################################
rxSetComputeContext(sql)
train_vars <- rxGetVarNames(train_table)
train_vars <- train_vars[!train_vars  %in% c("RUL", "label2", "id", "cycle_orig")]
formula <- as.formula(paste("~", paste(train_vars, collapse = "+")))
correlation <- rxCor(formula = formula, 
                     data = train_table,
                     transforms = list(label1 = as.numeric(label1)))
correlation <- correlation[, "label1"]
correlation <- abs(correlation)
correlation <- correlation[order(correlation, decreasing = TRUE)]
correlation <- correlation[-1]
correlation <- correlation[1:35]
formula <- as.formula(paste(paste("label1~"),
                            paste(names(correlation), collapse = "+")))
####################################################################################################
## Import test into data frame for faster prediction and model evaluation
####################################################################################################
test_table_name <- "test_Features"
test_table <- RxSqlServerData(table = test_table_name,
                              connectionString = connection_string,
                              colInfo = list(label1 = list(type = "factor", levels = c("0", "1"))))
prediction_df <- rxImport(inData = test_table)
####################################################################################################
## Binary classification model evaluation metrics
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
## ROC curve
####################################################################################################
roc_curve <- function(data, observed, predicted) {
  data <- data[, c(observed, predicted)]
  data[[observed]] <- as.numeric(as.character(data[[observed]]))
  rxRocCurve(actualVarName = observed,
             predVarNames = predicted,
             data = data)
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
threshold <- 0.5
forest_prediction$X0_prob <- NULL
forest_prediction$label1_Pred <- NULL
names(forest_prediction) <- c("Forest_Probability")
forest_prediction$Forest_Prediction <- ifelse(forest_prediction$Forest_Probability > threshold, 1, 0)
forest_prediction$Forest_Prediction <- factor(forest_prediction$Forest_Prediction, levels = c(0, 1))
prediction_df <- cbind(prediction_df, forest_prediction)
forest_metrics <- evaluate_model(observed = prediction_df$label1,
                                 predicted = forest_prediction$Forest_Prediction)
roc_curve(data = prediction_df,
          observed = "label1",
          predicted = "Forest_Probability")
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
                          lossFunction = "bernoulli")
rxSetComputeContext(local)
boosted_prediction <- rxPredict(modelObject = boosted_model,
                                data = prediction_df,
                                type = "prob",
                                overwrite = TRUE)
threshold <- 0.5
names(boosted_prediction) <- c("Boosted_Probability")
boosted_prediction$Boosted_Prediction <- ifelse(boosted_prediction$Boosted_Probability > threshold, 1, 0)
boosted_prediction$Boosted_Prediction <- factor(boosted_prediction$Boosted_Prediction, levels = c(0, 1))
prediction_df <- cbind(prediction_df, boosted_prediction)

boosted_metrics <- evaluate_model(observed = prediction_df$label1,
                                  predicted = boosted_prediction$Boosted_Prediction)
roc_curve(data = prediction_df,
          observed = "label1",
          predicted = "Boosted_Probability")
####################################################################################################
## Logistic regression modeling
####################################################################################################
rxSetComputeContext(sql)
logistic_model <- rxLogit(formula = formula,
                          data = train_table)
rxSetComputeContext(local)
logistic_prediction <- rxPredict(modelObject = logistic_model,
                                 data = prediction_df,
                                 type = "response",
                                 overwrite = TRUE)
threshold <- 0.5
names(logistic_prediction) <- c("Logistic_Probability")
logistic_prediction$Logistic_Prediction <- ifelse(logistic_prediction$Logistic_Probability > threshold, 1, 0)
logistic_prediction$Logistic_Prediction <- factor(logistic_prediction$Logistic_Prediction, levels = c(0, 1))
prediction_df <- cbind(prediction_df, logistic_prediction)

logistic_metrics <- evaluate_model(observed = prediction_df$label1,
                                   predicted = logistic_prediction$Logistic_Prediction)
roc_curve(data = prediction_df,
          observed = "label1",
          predicted = "Logistic_Probability")
####################################################################################################
## Neural network regression modeling
####################################################################################################
library(nnet)
rxSetComputeContext(local)
train_df <- rxImport(inData = train_table)
nodes <- 10
weights <- nodes * (35 + 1) + nodes + 1
nnet_model <- nnet(formula = formula,
                   data = train_df,
                   Wts = rep(0.1, weights),
                   size = nodes,
                   decay = 0.005,
                   MaxNWts = weights)
nnet_prediction <- predict(object = nnet_model,
                           newdata = prediction_df)
nnet_prediction <- as.data.frame(nnet_prediction)
threshold <- 0.5
names(nnet_prediction) <- c("Nnet_Probability")
nnet_prediction$Nnet_Prediction <- ifelse(nnet_prediction$Nnet_Probability > threshold, 1, 0)
nnet_prediction$Nnet_Prediction <- factor(nnet_prediction$Nnet_Prediction, levels = c(0, 1))
prediction_df <- cbind(prediction_df, nnet_prediction)

nnet_metrics <- evaluate_model(observed = prediction_df$label1,
                               predicted = nnet_prediction$Nnet_Prediction)
roc_curve(data = prediction_df,
          observed = "label1",
          predicted = "Nnet_Probability")
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
           overwrite = TRUE)
####################################################################################################
## Cleanup
####################################################################################################
rm(list = ls())