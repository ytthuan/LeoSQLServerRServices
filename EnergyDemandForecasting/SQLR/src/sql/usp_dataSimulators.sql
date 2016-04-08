IF OBJECT_ID('dbo.usp_Data_Simulator_Demand', 'P') IS NOT NULL
  DROP PROCEDURE [dbo].[usp_Data_Simulator_Demand]
GO

IF OBJECT_ID('dbo.usp_Data_Simulator_Temperature', 'P') IS NOT NULL
  DROP PROCEDURE [dbo].[usp_Data_Simulator_Temperature]
GO

CREATE PROCEDURE usp_Data_Simulator_Demand
AS
SET NOCOUNT ON;
BEGIN   
	declare @currTimestamp1 datetime;
	declare @currTimestamp2 datetime;	
	
	select @currTimestamp1 = dateadd(minute, datediff(minute,0,GETUTCDATE()) / 15 * 15, 0)
	
	IF convert(NVARCHAR(5), @currTimestamp1, 110) = '02-29'
	BEGIN
		MERGE DemandReal as target
		USING (	
			SELECT concat(datepart(year,@currTimestamp1),'-',convert(NVARCHAR(5), @currTimestamp1, 110), ' ', convert(NVARCHAR(8), cast(utctimestamp as time),108)) as utcTimeStamp,
					region, round(load*(RAND(CHECKSUM(NEWID()))*(105.99-94.99)+94.99)/100,1) as load
			from DemandSeed 
			where concat(convert(NVARCHAR(5), utcTimeStamp, 110), ' ', cast(utctimestamp as time)) 
				=concat(convert(NVARCHAR(5), dateadd(day, 1, @currTimestamp1), 110), ' ', cast(@currTimestamp1 as time))
		) as source
		ON (target.region = source.region and target.utcTimestamp=source.utcTimestamp)	
		WHEN MATCHED THEN 
			UPDATE SET load= source.load
		WHEN NOT MATCHED THEN
			INSERT (utcTimestamp, region, load)
			VALUES (source.utcTimestamp, source.region, source.load); 			
	END
	ELSE
	BEGIN
		MERGE DemandReal as target
		USING (
			SELECT concat(datepart(year,@currTimestamp1),'-',convert(NVARCHAR(5), utctimestamp, 110), ' ', convert(NVARCHAR(8), cast(utctimestamp as time),108)) as utcTimeStamp,
					region, round(load*(RAND(CHECKSUM(NEWID()))*(105.99-94.99)+94.99)/100,1) as load
			from DemandSeed 
			where concat(convert(NVARCHAR(5), utctimestamp, 110), ' ', cast(utctimestamp as time)) 
					=concat(convert(NVARCHAR(5), @currTimestamp1, 110), ' ', cast(@currTimestamp1 as time))
		) as source
		ON (target.region = source.region and target.utcTimestamp=source.utcTimestamp)	
		WHEN MATCHED THEN 
			UPDATE SET load= source.load
		WHEN NOT MATCHED THEN
			INSERT (utcTimestamp, region, load)
			VALUES (source.utcTimestamp, source.region, source.load); 				
	END
END;
GO


CREATE PROCEDURE usp_Data_Simulator_Temperature
AS
SET NOCOUNT ON;
BEGIN   
	declare @currTimestamp2 datetime;	
	
	--select @currTimestamp2 = dateadd(minute, datediff(minute,0,GETUTCDATE()) / 60 * 60, 0)
	select @currTimestamp2 = dateadd(minute, datediff(minute,0,dateadd(hour,6,GETUTCDATE())) / 60 * 60, 0)
	
	IF convert(NVARCHAR(5), @currTimestamp2, 110) = '02-29'
	BEGIN
		MERGE TemperatureReal as target
		USING (	
			SELECT concat(datepart(year,@currTimestamp2),'-',convert(NVARCHAR(5), @currTimestamp2, 110), ' ', convert(NVARCHAR(8), cast(utctimestamp as time),108)) as utcTimeStamp,
					region, round(temperature*(RAND(CHECKSUM(NEWID()))*(105.99-94.99)+94.99)/100,1) as temperature, flag 
			from TemperatureSeed 
			where concat(convert(NVARCHAR(5), utcTimeStamp, 110), ' ', cast(utctimestamp as time)) 
				=concat(convert(NVARCHAR(5), dateadd(day, 1, @currTimestamp2), 110), ' ', cast(@currTimestamp2 as time))
		) as source
		ON (target.region = source.region and target.utcTimestamp=source.utcTimestamp)	
		WHEN MATCHED THEN 
			UPDATE SET temperature= source.temperature, flag= source.flag
		WHEN NOT MATCHED THEN
			INSERT (utcTimestamp, region, temperature, flag)
			VALUES (source.utcTimestamp, source.region, source.temperature, source.flag); 	

	END
	ELSE
	BEGIN
		MERGE TemperatureReal as target
		USING (
			SELECT concat(datepart(year,@currTimestamp2),'-',convert(NVARCHAR(5), utctimestamp, 110), ' ', convert(NVARCHAR(8), cast(utctimestamp as time),108)) as utcTimeStamp,
					region, round(temperature*(RAND(CHECKSUM(NEWID()))*(105.99-94.99)+94.99)/100,1) as temperature, 
					flag 
			from TemperatureSeed 
			where concat(convert(NVARCHAR(5), utctimestamp, 110), ' ', cast(utctimestamp as time)) 
					=concat(convert(NVARCHAR(5), @currTimestamp2, 110), ' ', cast(@currTimestamp2 as time))
		) as source
		ON (target.region = source.region and target.utcTimestamp=source.utcTimestamp)	
		WHEN MATCHED THEN 
			UPDATE SET temperature= source.temperature, flag= source.flag
		WHEN NOT MATCHED THEN
			INSERT (utcTimestamp, region, temperature, flag)
			VALUES (source.utcTimestamp, source.region, source.temperature, source.flag); 	
	END
END;
GO