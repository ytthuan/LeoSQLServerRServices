/****** Stored Procedure to train models (Random Forest and GBT) ******/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Campaign_Models' AND xtype='U')
    create table Campaign_Models
    (
	model_name varchar(30) not null default('default model') primary key,
	model varbinary(max) not null
    )
go

DROP PROCEDURE IF EXISTS [dbo].[TrainModel];
GO

CREATE PROCEDURE [TrainModel] @modelName varchar(20)
AS 
BEGIN
	DECLARE @inquery NVARCHAR(max) = N'SELECT * FROM CM_AD1 WHERE Split_Vector = 1';
	DELETE FROM Campaign_Models WHERE model_name = @modelName;
	INSERT INTO Campaign_Models (model)
	EXECUTE sp_execute_external_script @language = N'R',
					   @script = N' 
##########################################################################################################################################
##	Dataset for train
##########################################################################################################################################
trainDS <- InputDataSet
trainDS$Conversion_Flag <- factor(trainDS$Conversion_Flag, levels = c("0", "1"))
##########################################################################################################################################
##	Specify the variables to keep for the training 
##########################################################################################################################################
variables_all <- rxGetVarNames(trainDS)
variables_to_remove <- c("Lead_Id", "Phone_No", 
			 "Country", "Comm_Id", 
			 "Time_Stamp", "Category", 
			 "Launch_Date", "Focused_Geography",
                         "Split_Vector")
traning_variables <- variables_all[!(variables_all %in% c("Conversion_Flag", variables_to_remove))]
formula <- as.formula(paste("Conversion_Flag ~", paste(traning_variables, collapse = "+")))

##########################################################################################################################################
## Training model based on model selection
##########################################################################################################################################
if (model_name == "RF") {
	# Train the Random Forest.
	model <- rxDForest(formula = formula,
	 			     data = trainDS,
				     nTree = 40,
 				     minBucket = 5,
				     minSplit = 10,
				     cp = 0.00005,
				     seed = 5, 
				     importance = TRUE)
} else {
	# Train the GBT.
	model <- rxBTrees(formula = formula,
				    data = trainDS,
				    learningRate = 0.05,				    
				    minBucket = 5,
				    minSplit = 10,
				    cp = 0.0005,
				    nTree = 40,
				    seed = 5,
				    lossFunction = "multinomial")
}

OutputDataSet <- data.frame(payload = as.raw(serialize(model, connection=NULL)))'
, @input_data_1 = @inquery
, @params = N'@model_name varchar(20)'
, @model_name = @modelName

UPDATE Campaign_models set model_name = @modelName 
WHERE model_name = 'default model'

;
END
GO
