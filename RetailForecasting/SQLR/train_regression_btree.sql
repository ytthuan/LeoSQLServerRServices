SET ANSI_NULLS ON
GO

/****** Create the Stored Procedure for Retail Forecasting Template ******/

SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS train_regression_btree 
GO

TRUNCATE TABLE RetailForecasting_models_btree
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [train_regression_btree] @connectionString varchar(300),
                                          @num_folds int
AS
BEGIN
  DECLARE @inquery NVARCHAR(max) = N'SELECT * from train'
  INSERT INTO RetailForecasting_models_btree
  EXEC sp_execute_external_script @language = N'R',
                                  @script = N'
sql_share_directory <- paste("c:\\AllShare\\", Sys.getenv("USERNAME"), sep = "")
dir.create(sql_share_directory, recursive = TRUE)
sql <- RxInSqlServer(connectionString = connection_string, 
                     shareDir = sql_share_directory)
local <- RxLocalSeq()

train <- InputDataSet
####################################################################################################
## Regression formula
####################################################################################################
train_vars <- rxGetVarNames(train)
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
## Boosted tree modeling
####################################################################################################
set.seed(0)
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

trained_model <- data.frame(model = as.raw(serialize(boosted_model[[index]], connection = NULL)));'
, @input_data_1 = @inquery
, @output_data_1_name = N'trained_model'
, @params = N'@connection_string varchar(300), @num_folds int'
, @connection_string = @connectionString  
, @num_folds = @num_folds                     
END
GO
