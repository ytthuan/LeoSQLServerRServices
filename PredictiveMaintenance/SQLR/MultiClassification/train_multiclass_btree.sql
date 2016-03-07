USE [DefaultDBName]
GO

/****** Create the Stored Procedure for PM Template ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS train_multiclass_btree
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [train_multiclass_btree] 

AS
BEGIN
  DECLARE @inquery NVARCHAR(max) = N'SELECT * FROM train_Features_Normalized';

  EXEC sp_execute_external_script @language = N'R',
                                  @script = N'

####################################################################################################
## Drop variables and make label a factor in train dataset
####################################################################################################
train_table <- InputDataSet
train_table$label2 <- factor(train_table$label2, levels = c("0", "1", "2"))
train_vars <- rxGetVarNames(train_table)
train_vars <- train_vars[!train_vars  %in% c("RUL", "label1", "id", "cycle_orig")]
####################################################################################################
## Find top 35 variables most correlated with label2
####################################################################################################
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
## Boosted tree modeling
####################################################################################################
boosted_model <- rxBTrees(formula = formula,
                          data = train_table,
                          learningRate = 0.2,
                          minSplit = 10,
                          minBucket = 10,
                          nTree = 100,
                          seed = 5,
                          lossFunction = "multinomial")

bt <- data.frame(payload = as.raw(serialize(boosted_model, connection=NULL)))'
,@input_data_1 = @inquery
, @output_data_1_name = N'bt'
with result sets ((model varbinary(max)));
end;
