-- This script creates airlineWithIndex table needed for running perf tuning tests.
use PerfTuning;
go
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES 
           WHERE TABLE_NAME = N'airlineWithIndex')
BEGIN
  PRINT 'dropping existing table airlineWithIndex'
  drop table [airlineWithIndex];
END
GO
CREATE TABLE [dbo].airlineWithIndex(
	[Year] [int] NULL,
	[Month] [int] NULL,
	[DayofMonth] [int] NULL,
	[DayOfWeek] [bigint] NULL,
	[FlightDate] [float] NULL,
	[UniqueCarrier] [nvarchar](255) NULL,
	[TailNum] [nvarchar](255) NULL,
	[FlightNum] [nvarchar](255) NULL,
	[OriginAirportID] [nvarchar](255) NULL,
	[Origin] [nvarchar](255) NULL,
	[OriginState] [nvarchar](255) NULL,
	[DestAirportID] [nvarchar](255) NULL,
	[Dest] [nvarchar](255) NULL,
	[DestState] [nvarchar](255) NULL,
	[CRSDepTime] [float] NULL,
	[DepTime] [float] NULL,
	[DepDelay] [int] NULL,
	[DepDelayMinutes] [int] NULL,
	[DepDel15] [bit] NULL,
	[DepDelayGroups] [nvarchar](255) NULL,
	[TaxiOut] [int] NULL,
	[WheelsOff] [float] NULL,
	[WheelsOn] [float] NULL,
	[TaxiIn] [int] NULL,
	[CRSArrTime] [float] NULL,
	[ArrTime] [float] NULL,
	[ArrDelay] [int] NULL,
	[ArrDelayMinutes] [int] NULL,
	[ArrDel15] [bit] NULL,
	[ArrDelayGroups] [nvarchar](255) NULL,
	[Cancelled] [bit] NULL,
	[CancellationCode] [nvarchar](255) NULL,
	[Diverted] [bit] NULL,
	[CRSElapsedTime] [int] NULL,
	[ActualElapsedTime] [int] NULL,
	[AirTime] [int] NULL,
	[Flights] [int] NULL,
	[Distance] [int] NULL,
	[DistanceGroup] [nvarchar](255) NULL,
	[CarrierDelay] [int] NULL,
	[WeatherDelay] [int] NULL,
	[NASDelay] [int] NULL,
	[SecurityDelay] [int] NULL,
	[LateAircraftDelay] [int] NULL,
	[MonthsSince198710] [int] NULL,
	[DaysSince19871001] [int] NULL,
	[rowNum] [int] NULL
);
GO
CREATE CLUSTERED INDEX simple_index ON airlineWithIndex (rowNum);
GO
PRINT 'inserting data from airlineWithIntCol into airlineWithIndex'
GO
INSERT INTO airlineWithIndex SELECT * FROM airlineWithIntCol
GO
PRINT 'inserting data done'
GO
ALTER TABLE airlineWithIndex
ADD Late BIT
ALTER TABLE airlineWithIndex
ADD CRSDepHour int
GO
PRINT 'computing Late and ArrDelay column values.'
GO
update airlineWithIndex
set CRSDepHour=ROUND(CRSDepTime, 0, 1), Late=case when  ArrDelay>15 then 1 else 0 end
GO
PRINT 'computing done'
GO
PRINT 'rebuilding index after insert operations'
GO
ALTER INDEX simple_index ON airlineWithIndex
REBUILD
GO
PRINT 'rebuilding done'
GO