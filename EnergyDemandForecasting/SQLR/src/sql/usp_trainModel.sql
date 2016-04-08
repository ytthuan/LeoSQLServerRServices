IF OBJECT_ID('dbo.usp_trainModel', 'P') IS NOT NULL
  DROP PROCEDURE [dbo].[usp_trainModel]
GO



-- stored procedure for model training
CREATE PROCEDURE [dbo].[usp_trainModel] 
	@queryStr nvarchar(max),
	@region VARCHAR(10),	
	@scoreStartTime VARCHAR(50),	
	@sqlConnString VARCHAR(255)
AS
BEGIN
	BEGIN TRY
		EXEC sp_execute_external_script @language = N'R',
								  @script = N'
									
									sqlCompute <- RxInSqlServer(connectionString = sqlConnString)
									rxSetComputeContext(sqlCompute)

									edfFeaturesTrainSQL =  RxSqlServerData(sqlQuery = query,connectionString = sqlConnString)
									labelVar = "Load"
									featureVars = rxGetVarNames(edfFeaturesTrainSQL)
									featureVars = featureVars[which((featureVars!=labelVar)&(featureVars!="region")&(featureVars!="utcTimestamp"))]
									formula = as.formula(paste(paste(labelVar,"~"),paste(featureVars,collapse="+")))

									regForest = rxDForest(formula, data = edfFeaturesTrainSQL)

									modelbin <- as.raw(serialize(regForest, NULL))

									OutputDataSet = data.frame(model=modelbin)',
								  @input_data_1 = N'select getdate()',  --The input dataset is not actually used, but this parameter is required by the stored procedure
								  @params = N'@query varchar(max), @sqlConnString varchar(255)',
								  @query = @queryStr,
								  @sqlConnString = @sqlConnString
								  WITH RESULT SETS ((model varbinary(max)));
								  
		MERGE runlogs a 
		using (select 2 as step, @scoreStartTime as utcTimeStamp, @region as region, getutcdate() as runtimestamp, 0 as success_flag, '' as errMsg) b
		on a.step = b.step and a.utcTimeStamp = b.utcTimeStamp and a.region=b.region and a.runTimestamp = b.runTimestamp
		when matched then
			update set ErrorMessage = b.errMsg, success_flag = b.success_flag
		WHEN NOT MATCHED THEN	
			insert (step,utcTimeStamp,region, runTimestamp,success_flag,errorMessage)
			values (b.step,b.utcTimeStamp,b.region, b.runTimestamp,b.success_flag,b.errMsg);	
	END TRY
	BEGIN CATCH
		merge runlogs a 
		using (select 2 as step, @scoreStartTime as utcTimeStamp, @region as region, getutcdate() as runtimestamp, -1 as success_flag, ERROR_MESSAGE() as errMsg) b
		on a.step = b.step and a.utcTimeStamp = b.utcTimeStamp and a.region=b.region and a.runTimestamp = b.runTimestamp
		when matched then
			update set ErrorMessage = b.errMsg, success_flag = b.success_flag
		WHEN NOT MATCHED THEN	
			insert (step,utcTimeStamp,region, runTimestamp,success_flag,errorMessage)
			values (b.step,b.utcTimeStamp,b.region, b.runTimestamp,b.success_flag,b.errMsg);
	END CATCH;	 
END;
GO