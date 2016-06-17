SET ANSI_NULLS ON
GO

/****** Create the Stored Procedure for PM Template ******/

SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS score_multiclass_model
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [score_multiclass_model] @modelname varchar(20),
                                          @connectionString varchar(300)

AS
BEGIN
  DECLARE @inquery NVARCHAR(max) = N'SELECT * FROM score_Features_Normalized';
  declare @model varbinary(max) = (select model from [PM_Models] where model_name = @modelname);
 
  EXEC sp_execute_external_script @language = N'R',
                                  @script = N'
####################################################################################################
## Get score table data for prediction
####################################################################################################
prediction_df <- InputDataSet
####################################################################################################
## Multiclass classification prediction
####################################################################################################
model <- unserialize(model)
prediction <- rxPredict(modelObject = model,
               	        data = prediction_df,
                       	type = "prob",
                       	overwrite = TRUE)

names(prediction) <- c("Probability_Class_0",
                       "Probability_Class_1",
                       "Probability_Class_2",
                       "Prediction")

####################################################################################################
## Write test predictions to SQL
####################################################################################################
predictions <- cbind(prediction_df$id, prediction_df$cycle_orig, prediction)
colnames(predictions)[1] <- "id"
colnames(predictions)[2] <- "cycle"

prediction_table <- RxSqlServerData(table = paste("Score", modelname, sep = "_"),
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

