USE [DefaultDBName]
GO

/****** Create the Stored Procedure for PM Template ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [train_regression_glm]
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [train_regression_glm] 

AS
BEGIN

  DECLARE @inquery NVARCHAR(max) = N'SELECT * FROM train_Features_Normalized';

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
## Poisson regression modeling
####################################################################################################
poisson_model <- rxGlm(formula = formula,
                       data = train_table,
                       family = poisson())
myglm <- data.frame(payload = as.raw(serialize(poisson_model, connection=NULL)))'
, @input_data_1 = @inquery
, @output_data_1_name = N'myglm'
with result sets ((model varbinary(max)));
end;
GO

