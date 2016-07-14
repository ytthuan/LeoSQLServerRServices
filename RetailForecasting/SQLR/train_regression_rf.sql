SET ANSI_NULLS ON
GO

/****** Create the Stored Procedure for Retail Forecasting Template ******/

SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS train_regression_rf 
GO

TRUNCATE TABLE RetailForecasting_models_rf
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [train_regression_rf] @connectionString varchar(300),
                                       @num_folds int
AS
BEGIN
  DECLARE @inquery NVARCHAR(max) = N'SELECT * from train'
  INSERT INTO RetailForecasting_models_rf
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
  # TODO: There is a bug in colClasses for sql compute context
  # As the work around, setting it as local
  # should change it back to sql compute context after it is fixed in RTM
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
		   
trained_model <- data.frame(model = as.raw(serialize(forest_model[[index]], connection = NULL)));'
, @input_data_1 = @inquery
, @output_data_1_name = N'trained_model'
, @params = N'@connection_string varchar(300), @num_folds int'
, @connection_string = @connectionString  
, @num_folds = @num_folds                     
END
GO
