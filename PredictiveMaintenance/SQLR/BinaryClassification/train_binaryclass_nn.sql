USE [DefaultDBName]
GO

/****** Create the Stored Procedure for PM Template ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

drop procedure if exists train_binaryclass_nn;
go

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [train_binaryclass_nn] 
AS
BEGIN
  DECLARE @inquery NVARCHAR(max) = N'SELECT * FROM train_Features_Normalized';

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
## Neural network regression modeling
####################################################################################################
library(nnet)
nodes <- 10
weights <- nodes * (35 + 1) + nodes + 1
nnet_model <- nnet(formula = formula,
                   data = train_table,
                   Wts = rep(0.1, weights),
                   size = nodes,
                   decay = 0.005,
                   MaxNWts = weights)
nn <- data.frame(payload = as.raw(serialize(nnet_model, connection=NULL)))'
,@input_data_1 = @inquery
, @output_data_1_name = N'nn'
with result sets ((model varbinary(max)));
end;

GO

