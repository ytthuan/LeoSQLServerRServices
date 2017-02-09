-- =============================================
-- Description:	Predict Galaxy's class using trained Microsoft ML model.
-- =============================================
CREATE PROCEDURE [dbo].[PredictGalaxiesNN]
@ModelName nvarchar(50)
AS
BEGIN	
	SET NOCOUNT ON;

	-- Get the latest Model.
	DECLARE @dbModel varbinary(max) = (SELECT TOP (1) Model FROM [dbo].GalaxiesModels WHERE [Name] = @ModelName ORDER BY CreationDate DESC);  

	-- Produce input to the RML script.
	declare @inputCmd nvarchar(max)
	set @inputCmd = N'select * from [dbo].[GalaxiesToScore] where [PredictedLabel] is NULL';

	-- Prediction Script
	DECLARE @predictScript nvarchar(max);
	set @predictScript = N'
	   library("MicrosoftML") 
	   # Force factor to string
	   i <- sapply(InputDataSet, is.factor)
	   InputDataSet[i] <- lapply(InputDataSet[i], as.character)

       model_un <- unserialize(as.raw(nb_model)); 
	   
	   #score the model
	   scores <- rxPredict(modelObject = model_un, data = InputDataSet,  extraVarsToWrite="path")
	   OutputDataSet <- data.frame(scores$path, scores$PredictedLabel)
	   print("Scoring is done:")
	   print(OutputDataSet)	
	   '

	  -- Create temporary table to store scored results for rows where label=NULL.
	IF OBJECT_ID('tempdb.dbo.#results', 'U') IS NOT NULL
		DROP TABLE #results;
	create table #results ([path] char(300), [PredictedLabel] char(100));

	  -- Execute the RML script (train & score).
	insert into #results
	execute sp_execute_external_script
	  @language = N'R'
	, @script = @predictScript
	, @input_data_1 = @inputCmd	
	, @params = N'@nb_model varbinary(max)'
	, @nb_model = @dbModel;
	
	
	-- Update the original table to fill up the NULL labels with predicted labels.
	BEGIN TRAN
	UPDATE [GalaxiesToScore]
	SET [PredictedLabel]  = r.[PredictedLabel] from [GalaxiesToScore]
	INNER JOIN #results AS r ON [GalaxiesToScore].[path] = r.[path]
	WHERE [GalaxiesToScore].[PredictedLabel] is NULL
	COMMIT TRAN	
	   	
END