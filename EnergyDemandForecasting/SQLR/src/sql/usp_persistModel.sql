IF OBJECT_ID('dbo.usp_persistModel', 'P') IS NOT NULL
  DROP PROCEDURE [dbo].[usp_persistModel]
GO


-- stored procedure for persisting model
CREATE PROCEDURE [dbo].[usp_persistModel] 
	@region VARCHAR(10),
	@scoreStartTime VARCHAR(50),
	@sqlConnString VARCHAR(255)
AS
BEGIN
	DECLARE @ModelTable TABLE 
	(model varbinary(max))

	DECLARE @queryStr VARCHAR(max)
	set @queryStr = concat('select * from inputAllfeatures where region=''',  @region, ''' and utcTimestamp < ''',  @scoreStartTime , '''')

	INSERT INTO @ModelTable EXEC usp_trainModel @queryStr = @queryStr,@region=@region,@scoreStartTime=@scoreStartTime, @sqlConnString = @sqlConnString

	Merge Model as target
		USING (select @region as region,@scoreStartTime as startTime, model from @ModelTable) as source
	on target.region = source.region and target.startTime=source.startTime
	WHEN MATCHED THEN 
		UPDATE SET target.model= source.model
	WHEN NOT MATCHED THEN
		INSERT (model, region, startTime) values (source.model,source.region,@scoreStartTime);
END;
GO

