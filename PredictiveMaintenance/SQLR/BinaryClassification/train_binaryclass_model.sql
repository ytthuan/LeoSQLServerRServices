/****** Create the Stored Procedure for PM Template ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS train_binaryclass_model;
go

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[train_binaryclass_model] @modelName varchar(20)
AS
BEGIN
  DECLARE @inquery NVARCHAR(max) = N'SELECT * FROM train_Features_Normalized';
  DELETE FROM [PM_Models]  WHERE model_name = @modelName;
  INSERT INTO [PM_Models] (model)
  EXEC sp_execute_external_script @language = N'R',
                                  @script = N'

####################################################################################################
## Drop variables and make label a factor in train dataset
####################################################################################################
train_table <- InputDataSet
train_table$label1 <- factor(train_table$label1, levels = c("0", "1"))
train_vars <- rxGetVarNames(train_table)
train_vars <- train_vars[!train_vars  %in% c("RUL", "label2", "id", "cycle_orig")]
####################################################################################################
## Find top 35 variables most correlated with label1
####################################################################################################
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
## Training model based on model selection
####################################################################################################
if (model_name == "binaryclass_btree") {
  model <- rxBTrees(formula = formula,
                    data = train_table,
                    learningRate = 0.2,
                    minSplit = 10,
                    minBucket = 10,
                    nTree = 100,
                    seed = 5,
                    lossFunction = "bernoulli")
} else if (model_name == "binaryclass_rf") {
  model <- rxDForest(formula = formula,
                     data = train_table,
                     nTree = 8,
                     maxDepth = 32,
                     mTry = 35,
                     seed = 5)
} else if (model_name == "binaryclass_logit") {
  model <- rxLogit(formula = formula,
                   data = train_table)
} else {
  library(nnet)
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

, @input_data_1 = @inquery
, @params = N'@model_name varchar(20)'
, @model_name = @modelName

UPDATE [PM_models] set model_name = @modelName 
WHERE model_name = 'default model'
END

GO