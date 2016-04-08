IF OBJECT_ID('dbo.usp_GenerateHistorcialData', 'P') IS NOT NULL
  DROP PROCEDURE [dbo].[usp_GenerateHistorcialData]
GO

CREATE PROCEDURE [dbo].[usp_GenerateHistorcialData] 
AS
BEGIN
	SET NOCOUNT ON;
	
	declare @currTimestamp_15min datetime;
	declare @currTimestamp_hour datetime;
	declare @breakTimestamp1 datetime;
	declare @breakTimestamp2 datetime;
	declare @breakTimestamp3 datetime;
	declare @curyear int;
	declare @lastyear int;

	select @curyear = datepart(year,GETUTCDATE())
	select @lastyear=@curyear-1
	select @currTimestamp_15min=dateadd(minute, datediff(minute,0,GETUTCDATE()) / 15 * 15, 0);
	select @breakTimestamp1 = dateadd(year,2015-@curyear,@currTimestamp_15min)

	select @currTimestamp_hour = dateadd(minute, datediff(minute,0,GETUTCDATE()) / 60 * 60, 0);
	select @breakTimestamp2 = dateadd(hour,6,dateadd(year,-1,@currTimestamp_hour))
	select @breakTimestamp3 = dateadd(year,2015-@curyear,@currTimestamp_hour)

	
	MERGE DemandReal as target
	USING (
			select * from (
				select concat(datepart(year,@currTimestamp_15min),'-',convert(NVARCHAR(5), utctimestamp, 110), ' ', convert(NVARCHAR(8), cast(utctimestamp as time),108)) as utcTimeStamp,region,load
				from DemandSeed
				where utcTimestamp <=@breakTimestamp1
				union all
				select concat(@lastyear,'-',convert(NVARCHAR(5), utctimestamp, 110), ' ', convert(NVARCHAR(8), cast(utctimestamp as time),108)) as utcTimeStamp,region, load
				from DemandSeed
				where utcTimestamp >= @breakTimestamp1) a
	)	as source
	ON (target.region = source.region and target.utcTimestamp=source.utcTimestamp)	
	WHEN MATCHED THEN 
		UPDATE SET load= source.load
	WHEN NOT MATCHED THEN
		INSERT (utcTimestamp, region, load)
		VALUES (source.utcTimestamp, source.region, source.load); 

	MERGE TemperatureReal as target
	USING (
		select * from (
			SELECT concat(datepart(year,@currTimestamp_hour),'-',convert(NVARCHAR(5), utctimestamp, 110), ' ', convert(NVARCHAR(8), cast(utctimestamp as time),108)) as utcTimeStamp,
			region, temperature, flag 
			from TemperatureSeed 
			where utcTimestamp <=@breakTimestamp2
			union all
			select concat(@lastyear,'-',convert(NVARCHAR(5), utctimestamp, 110), ' ', convert(NVARCHAR(8), cast(utctimestamp as time),108)) as utcTimeStamp,
			region, temperature,flag
			from TemperatureSeed 
			where utcTimestamp >= @breakTimestamp3) a
	) as source
	ON (target.region = source.region and target.utcTimestamp=source.utcTimestamp)	
	WHEN MATCHED THEN 
		UPDATE SET temperature= source.temperature, flag= source.flag
	WHEN NOT MATCHED THEN
		INSERT (utcTimestamp, region, temperature, flag)
		VALUES (source.utcTimestamp, source.region, source.temperature, source.flag);

END;
Go