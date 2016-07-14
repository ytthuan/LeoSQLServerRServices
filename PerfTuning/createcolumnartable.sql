-- Change file path of csv file below before running this script.
-- This script creates airlineColumnar table needed for running perf tuning tests.
use PerfTuning;
go
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES 
           WHERE TABLE_NAME = N'airlineColumnar')
BEGIN
  PRINT 'dropping existing table airlineColumnar'
  drop table [airlineColumnar];
END
go
create table [airlineColumnar] (
   [Year] smallint,
   [Month] tinyint,
   [DayOfMonth] tinyint,
   [DayOfWeek] tinyint,
   [DepTime] real,
   [CRSDepTime] real,
   [ArrTime] real,
   [CRSArrTime] real,
   [UniqueCarrier] varchar(100),
   [FlightNum] smallint,
   [TailNum] varchar(100),
   [ActualElapsedTime] smallint,
   [CRSElapsedTime] smallint,
   [AirTime] smallint,
   [ArrDelay] smallint,
   [DepDelay] smallint,
   [Origin] char(3),
   [Dest] char(3),
   [Distance] smallint,
   [TaxiIn] smallint,
   [TaxiOut] smallint,
   [Cancelled] bit,
   [CancellationCode] varchar(100),
   [Diverted] bit,
   [CarrierDelay] smallint,
   [WeatherDelay] smallint,
   [NASDelay] smallint,
   [SecurityDelay] smallint,
   [LateAircraftDelay] smallint,
);
go
CREATE CLUSTERED COLUMNSTORE INDEX airline_clustered ON airlineColumnar;
GO
DELETE FROM airlineColumnar

PRINT 'bulk inserting data from airline-cleaned-10M.csv into airlineColumnar'
GO
bulk insert airlineColumnar
from 'E:\PerfTuning\Data\airline-cleaned-10M.csv'
with(
batchsize = 1000000,  -- Reduce this value if there is memory issue
fieldterminator = ',',
keepnulls,
-- lastrow = 100,
firstrow = 2 -- Skip header
);
go
PRINT 'Inserting Data Done'
GO
ALTER TABLE airlineColumnar
ADD Late BIT
ALTER TABLE airlineColumnar
ADD CRSDepHour int
GO
PRINT 'computing Late and ArrDelay column values.'
GO
update airlineColumnar
set CRSDepHour=ROUND(CRSDepTime, 0, 1), Late=case when  ArrDelay>15 then 1 else 0 end
GO
PRINT 'computing done'
GO

PRINT 'adding id column and rebuilding index'
GO
ALTER TABLE airlineColumnar
ADD id INT IDENTITY(1,1)
ALTER INDEX airline_clustered ON airlineColumnar
REBUILD
GO
PRINT 'rebuilding done'
GO
