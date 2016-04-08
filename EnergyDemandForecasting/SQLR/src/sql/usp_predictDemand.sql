IF OBJECT_ID('dbo.usp_predictDemand', 'P') IS NOT NULL
  DROP PROCEDURE [dbo].[usp_predictDemand]
GO

CREATE PROCEDURE [dbo].[usp_predictDemand] 
	@queryStr NVARCHAR(max),
	@region VARCHAR(64),
	@startTime VARCHAR(50)
AS
BEGIN
	DECLARE @regForestModel varbinary(max) = (SELECT TOP 1 model FROM Model where region=@region and startTime=@startTime);

	BEGIN TRY
		EXEC sp_execute_external_script @language = N'R',
									  @script = N'
										mod <- unserialize(as.raw(model));
										print(summary(mod))
										OutputDataSet<-rxPredict(modelObject = mod, data = InputDataSet, outData = NULL, 
										type = "response", extraVarsToWrite=c("utcTimestamp"), overwrite = TRUE);
										str(OutputDataSet)
										print(OutputDataSet)',
									  @input_data_1 = @queryStr,
									  @params = N'@model varbinary(max)',
									  @model = @regForestModel
		WITH RESULT SETS ((Load_Pred float, utcTimestamp NVARCHAR(50)));
	
		merge runlogs a 
		using (select 3 as step, @startTime as utcTimeStamp, @region as region, getutcdate() as runtimestamp, 0 as success_flag, '' as errMsg) b
		on a.step = b.step and a.utcTimeStamp = b.utcTimeStamp and a.region=b.region and a.runTimestamp = b.runTimestamp
		when matched then
			update set ErrorMessage = b.errMsg, success_flag = b.success_flag
		WHEN NOT MATCHED THEN	
			insert (step,utcTimeStamp,region, runTimestamp,success_flag,errorMessage)
			values (b.step,b.utcTimeStamp,b.region, b.runTimestamp,b.success_flag,b.errMsg);	
	END TRY
	BEGIN CATCH
		merge runlogs a 
		using (select 3 as step, @startTime as utcTimeStamp, @region as region, getutcdate() as runtimestamp, -1 as success_flag, ERROR_MESSAGE() as errMsg) b
		on a.step = b.step and a.utcTimeStamp = b.utcTimeStamp and a.region=b.region and a.runTimestamp = b.runTimestamp
		when matched then
			update set ErrorMessage = b.errMsg, success_flag = b.success_flag
		WHEN NOT MATCHED THEN	
			insert (step,utcTimeStamp,region, runTimestamp,success_flag,errorMessage)
			values (b.step,b.utcTimeStamp,b.region, b.runTimestamp,b.success_flag,b.errMsg);
	END CATCH;		
END;
GO