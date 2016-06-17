/****** Create the Stored Procedure for PM Template ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [train_regression_model]
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [train_regression_model] @modelName varchar(20)

AS
BEGIN

  DECLARE @inquery NVARCHAR(max) = N'SELECT * FROM train_Features_Normalized';
  DELETE FROM [PM_Models]  WHERE model_name = @modelName;
  INSERT INTO [PM_Models] (model)
  EXEC sp_execute_external_script @language = N'R',
                                  @script = N'

####################################################################################################
## Drop variables from train table
####################################################################################################
train_table <- InputDataSet
train_vars <- rxGetVarNames(train_table)
train_vars <- train_vars[!train_vars  %in% c("label1", "label2", "id", "cycle_orig")]
####################################################################################################
## Find top 35 variables most correlated with RUL
####################################################################################################
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
## Training model based on model selection
####################################################################################################
if (model_name == "regression_btree") {
  model <- rxBTrees(formula = formula,
                    data = train_table,
                    learningRate = 0.2,
                    minSplit = 10,
                    minBucket = 10,
                    nTree = 100,
                    seed = 5,
                    lossFunction = "gaussian")
} else if (model_name == "regression_rf") {
  model <- rxDForest(formula = formula,
                     data = train_table,
                     nTree = 8,
                     maxDepth = 32,
                     mTry = 35,
                     seed = 5)
} else if (model_name == "regression_glm") {
  model <- rxGlm(formula = formula,
                 data = train_table,
                 family = poisson())
} else {
  library(nnet)
  max_train_rul <- max(train_table$RUL)
  train_table$RUL <- train_table$RUL / max_train_rul
  nodes <- 10
  weights <- nodes * (35 + 1) + nodes + 1
  model <- nnet(formula = formula,
                data = train_table,
                Wts = rep(0.1, weights),
                size = nodes,
                decay = 0.005,
                MaxNWts = weights)
}

OutputDataSet <- data.frame(payload = as.raw(serialize(model, connection=NULL)))'
,@input_data_1 = @inquery
, @params = N'@model_name varchar(20)'
, @model_name = @modelName

UPDATE [PM_models] set model_name = @modelName 
WHERE model_name = 'default model'
END

GO
