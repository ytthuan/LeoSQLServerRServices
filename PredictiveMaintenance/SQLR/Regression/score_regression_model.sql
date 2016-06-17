SET ANSI_NULLS ON
GO

/****** Create the Stored Procedure for PM Template ******/

DROP PROCEDURE IF EXISTS score_regression_model
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [score_regression_model] @modelname varchar(20),
                                          @connectionString varchar(300)
                                                       
AS
BEGIN

  declare @inquery NVARCHAR(max) = N'SELECT * FROM score_Features_Normalized';
  declare @model varbinary(max) = (select model from [PM_Models] where model_name = @modelname);

  EXEC sp_execute_external_script @language = N'R',
                                  @script = N'
####################################################################################################
## Get score table data for prediction
####################################################################################################
prediction_df <- InputDataSet
####################################################################################################
## Rregression prediction
####################################################################################################
model <- unserialize(model)

prediction <- rxPredict(modelObject = model,
                        data = prediction_df,
                        predVarNames = "Prediction",
                        overwrite = TRUE)
####################################################################################################
## Write score results to SQL
####################################################################################################
predictions <- cbind(prediction_df$id, prediction_df$cycle_orig, prediction)
colnames(predictions) <- c("id", "cycle", "Prediction")
prediction_table <- RxSqlServerData(table = paste("Regression_score", modelname, sep = "_"),
                                    connectionString = connection_string)
rxDataStep(inData = predictions,
           outFile = prediction_table,
           overwrite = TRUE)'
, @input_data_1 = @inquery
, @params = N'@model varbinary(max), @modelname varchar(20), @connection_string varchar(300)'
, @model = @model
, @modelname = @modelname
, @connection_string = @connectionString

END

GO

