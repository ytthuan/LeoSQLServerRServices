####################################################################################################
## Training regression models to answer questions on how many cycles will be left for an engine
## Four models will be trained:
## 1. Decision forest;
## 3. Boosted decision tree;
## 4. Poison regression modeling;
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
## Drop variables from train table
####################################################################################################
rxSetComputeContext(sql)
train_table_name <- "train_Features"
train_table <- RxSqlServerData(table = train_table_name, 
                               connectionString = connection_string)
####################################################################################################
## Find top 35 variables most correlated with RUL
####################################################################################################
rxSetComputeContext(sql)
train_vars <- rxGetVarNames(train_table)
train_vars <- train_vars[!train_vars  %in% c("label1", "label2", "id", "cycle_orig")]
formula <- as.formula(paste("~", paste(train_vars, collapse = "+")))
correlation <- rxCor(formula = formula, 
                     data = train_table)
correlation <- correlation[, "RUL"]
correlation <- abs(correlation)
correlation <- correlation[order(correlation, decreasing = TRUE)]
correlation <- correlation[-1]
correlation <- correlation[1:35]
formula <- as.formula(paste(paste("RUL~"), paste(names(correlation), collapse = "+")))
####################################################################################################
## Import test into data frame for faster prediction and model evaluation
####################################################################################################
test_table_name <- "test_Features"
test_table <- RxSqlServerData(table = test_table_name,
                              connectionString = connection_string)
prediction_df <- rxImport(inData = test_table)
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
                               predVarNames = "Forest_Prediction",
                               overwrite = TRUE)

forest_metrics <- evaluate_model(observed = prediction_df$RUL,
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
                          lossFunction = "gaussian")
rxSetComputeContext(local)
boosted_prediction <- rxPredict(modelObject = boosted_model,
                                data = prediction_df,
                                predVarNames = "Boosted_Prediction",
                                overwrite = TRUE)

boosted_metrics <- evaluate_model(observed = prediction_df$RUL,
                                  predicted = boosted_prediction$Boosted_Prediction)
####################################################################################################
## Poisson regression modeling
####################################################################################################
rxSetComputeContext(sql)
poisson_model <- rxGlm(formula = formula,
                       data = train_table,
                       family = poisson())
rxSetComputeContext(local)
poisson_prediction <- rxPredict(modelObject = poisson_model,
                                 data = prediction_df,
                                 predVarNames = "Poisson_Prediction",
                                 overwrite = TRUE)

poisson_metrics <- evaluate_model(observed = prediction_df$RUL,
                                  predicted = poisson_prediction$Poisson_Prediction)
####################################################################################################
## Neural network regression modeling
####################################################################################################
library(nnet)
rxSetComputeContext(local)
train_df <- rxImport(inData = train_table)
max_train_rul <- max(train_df$RUL)
train_df$RUL <- train_df$RUL / max_train_rul
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
           overwrite = TRUE)
####################################################################################################
## Cleanup
####################################################################################################
rm(list = ls())
