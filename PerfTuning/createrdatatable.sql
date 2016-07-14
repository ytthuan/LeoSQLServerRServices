-- This script creates rdata table needed for running perf tuning tests.
use PerfTuning;
go
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES 
           WHERE TABLE_NAME = N'rdata')
BEGIN
  PRINT 'dropping existing table rdata'
  drop table [rdata];
END
go
PRINT 'creating table rdata'
CREATE TABLE [rdata] ([key] varchar(900) primary key not null, [value] varbinary(max))
go
