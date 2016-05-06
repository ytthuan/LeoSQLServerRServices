####################################################################################################
## Compute context
####################################################################################################
connection_string <- "Driver=SQL Server;
                      Server=[SQL Server Name];
                      Database=[Database Name];
                      UID=[User ID];
                      PWD=[User Password]"
sql_share_directory <- paste("c:\\AllShare\\", Sys.getenv("USERNAME"), sep = "")
dir.create(sql_share_directory, recursive = TRUE)
sql <- RxInSqlServer(connectionString = connection_string, 
                     shareDir = sql_share_directory)
local <- RxLocalSeq()
####################################################################################################
## Create 5 folds
####################################################################################################
num_folds <- 5
create_folds <- function(train_table, num_folds, connection_string) {
  train <- rxImport(train_table)
  train_rows <- seq(1:nrow(train))
  train_size <- floor(nrow(train) / num_folds)
  for (i in 1:num_folds) {
    rows <- sample(train_rows, train_size)
    train_rows <- train_rows[!train_rows %in% rows]
    fold <- train[rows, ]
    
    fold_table <- RxSqlServerData(table = paste0("train_fold", i), 
                                  connectionString = connection_string)
    rxDataStep(inData = fold,
               outFile = fold_table,
               overwrite = TRUE)
  }
}
rxSetComputeContext(sql)
train_table <- RxSqlServerData(table = "train", 
                               connectionString = connection_string)
rxExec(create_folds,
       train_table,
       num_folds,
       connection_string)
####################################################################################################
## Regression formula
####################################################################################################
rxSetComputeContext(sql)
train_table <- RxSqlServerData(table = "train", 
                               connectionString = connection_string)
train_vars <- rxGetVarNames(train_table)
train_vars <- train_vars[train_vars != "time"]
formula <- as.formula(paste("value~", paste(train_vars, collapse = "+")))
####################################################################################################
## Regression model evaluation metrics
####################################################################################################
evaluate_model <- function(data, observed, predicted) {
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
  metrics <- c("Mean Absolute Error" = mae,
               "Root Mean Squared Error" = rmse,
               "Relative Absolute Error" = rae,
               "Relative Squared Error" = rse,
               "Coefficient of Determination" = rsq)
  return(metrics)
}
####################################################################################################
## Import test into data frame for faster prediction and model evaluation
####################################################################################################
test_table <- RxSqlServerData(table = "test",
                              connectionString = connection_string)
prediction_df <- rxImport(inData = test_table, stringsAsFactors = TRUE)
####################################################################################################
## Boosted tree modeling
####################################################################################################
set.seed(0)
num_folds <- 5
learningRate <- vector("list", num_folds)
minSplit <- vector("list", num_folds)
minBucket <- vector("list", num_folds)
nTree <- vector("list", num_folds)
boosted_model <- vector("list", num_folds)
boosted_metrics <- vector("list", num_folds)
for (i in 1:num_folds) {
  learningRate[[i]] <- runif(1, 0, 0.4)
  minSplit[[i]] <- sample(1:100, 1)
  minBucket[[i]] <- sample(1:50, 1)
  nTree[[i]] <- sample(1:100, 1)
  # TODO: There is a bug to use colCalsses to convert data types in sql compute context.
  #       Need switch the compute context to sql after the bug is fixed
  rxSetComputeContext(local)
  fold_table <- RxSqlServerData(table = paste0("train_fold", i), 
                                connectionString = connection_string,
                                colClasses = c(horizon = "integer"))
  
  boosted_model[[i]] <- rxBTrees(formula = formula,
                                 data = fold_table,
                                 learningRate = learningRate[[i]],
                                 minSplit = minSplit[[i]],
                                 minBucket = minBucket[[i]],
                                 nTree = nTree[[i]],
                                 seed = 0,
                                 lossFunction = "gaussian")
  
  fold_df <- rxImport(fold_table)
  predictions <- rxPredict(modelObject = boosted_model[[i]],
                           data = fold_df,
                           predVarNames = "Boosted_Prediction",
                           overwrite = TRUE)
  fold_df <- cbind(fold_df, predictions)
  boosted_metrics[[i]] <- evaluate_model(data = fold_df,
                                         observed = "value",
                                         predicted = "Boosted_Prediction")
  boosted_metrics[[i]] <- c("Learning Rate" = learningRate[[i]],
                            "Min Split" = minSplit[[i]],
                            "Min Bucket" = minBucket[[i]],
                            "Number of Trees" = nTree[[i]],
                            boosted_metrics[[i]])
}

boosted_metrics <- as.data.frame(do.call(rbind, boosted_metrics))

boosted_sweep_table <- RxSqlServerData(table = "boosted_sweep",
                                       connectionString = connection_string)
rxDataStep(inData = boosted_metrics,
           outFile = boosted_sweep_table,
           overwrite = TRUE)
index <- which(boosted_metrics$`Root Mean Squared Error` == 
                 min(boosted_metrics$`Root Mean Squared Error`))
predictions <- rxPredict(modelObject = boosted_model[[index]],
                         data = prediction_df,
                         predVarNames = "forecast.BstDecTree",
                         overwrite = TRUE)
prediction_df <- cbind(prediction_df, predictions)
boosted_metrics <- evaluate_model(data = prediction_df,
                                  observed = "value",
                                  predicted = "forecast.BstDecTree")
prediction_df$forecast.BstDecTree <- exp(prediction_df$forecast.BstDecTree)
####################################################################################################
## Decision forest modeling
####################################################################################################
set.seed(0)
nTree <- vector("list", num_folds)
maxDepth <- vector("list", num_folds)
mTry <- vector("list", num_folds)
forest_model <- vector("list", num_folds)
forest_metrics <- vector("list", num_folds)
for (i in 1:num_folds) {
  nTree[[i]] <- sample(1:100, 1)
  maxDepth[[i]] <- sample(1:50, 1)
  mTry[[i]] <- sample(1:50, 1)
  rxSetComputeContext(local)
  fold_table <- RxSqlServerData(table = paste0("train_fold", i), 
                                connectionString = connection_string,
                                colClasses = c(horizon = "integer"))
  forest_model[[i]] <- rxDForest(formula = formula,
                                 data = fold_table,
                                 nTree = nTree[[i]],
                                 maxDepth = maxDepth[[i]],
                                 mTry = mTry[[i]],
                                 seed = 0)
  rxSetComputeContext(local)
  fold_df <- rxImport(fold_table)
  predictions <- rxPredict(modelObject = forest_model[[i]],
                           data = fold_df,
                           predVarNames = "Forest_Prediction",
                           overwrite = TRUE)
  fold_df <- cbind(fold_df, predictions)
  forest_metrics[[i]] <- evaluate_model(data = fold_df,
                                        observed = "value",
                                        predicted = "Forest_Prediction")
  forest_metrics[[i]] <- c("Number of Trees" = nTree[[i]],
                           "Max Depth" = maxDepth[[i]],
                           "Number of Variables" = mTry[[i]],
                           forest_metrics[[i]])
}

forest_metrics <- as.data.frame(do.call(rbind, forest_metrics))

forest_sweep_table <- RxSqlServerData(table = "forest_sweep",
                                       connectionString = connection_string)
rxDataStep(inData = forest_metrics,
           outFile = forest_sweep_table,
           overwrite = TRUE)
index <- which(forest_metrics$`Root Mean Squared Error` == 
                 min(forest_metrics$`Root Mean Squared Error`))
predictions <- rxPredict(modelObject = forest_model[[index]],
                         data = prediction_df,
                         predVarNames = "forecast.DecFore",
                         overwrite = TRUE)
prediction_df <- cbind(prediction_df, predictions)
forest_metrics <- evaluate_model(data = prediction_df,
                                  observed = "value",
                                  predicted = "forecast.DecFore")
prediction_df$forecast.DecFore <- exp(prediction_df$forecast.DecFore)
####################################################################################################
## Write test predictions to SQL
####################################################################################################
rxSetComputeContext(local)
prediction_df <- prediction_df[, c("ID1", "ID2", "time", "forecast.BstDecTree", "forecast.DecFore")]

prediction_table <- RxSqlServerData(table = "regression_forecasts",
                                    connectionString = connection_string)
rxDataStep(inData = prediction_df,
           outFile = prediction_table,
           overwrite = TRUE)
####################################################################################################
## Cleanup
####################################################################################################
rm(list = ls())