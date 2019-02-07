--This SQL script creates and loads the data for telemetry, errors, maintanence, machines and failures
--Ensure the location of the input CSV file 'C:\...' is updated with your file location

--Create + load data into telemetry
DROP TABLE IF EXISTS telemetry
GO

create table telemetry
(
	datetime datetime,
	machineID float,
	volt float,
	rotate float,
	pressure float,
	vibration float	
	)
CREATE CLUSTERED COLUMNSTORE INDEX [telemetry_cci] ON telemetry WITH (DROP_EXISTING = OFF)
GO

bulk insert telemetry
from 'C:\...\telemetry.csv'
with
(
firstrow =2,
fieldterminator =',',
rowterminator ='\n'
)
GO

select top 10 * from telemetry

--Create + load data into errors
DROP TABLE IF EXISTS errors
GO

create table errors
(
	datetime datetime,
	machineID float,
	errorID varchar(50)	
	)
CREATE CLUSTERED COLUMNSTORE INDEX [errors_cci] ON errors WITH (DROP_EXISTING = OFF)
GO

bulk insert errors
from 'C:\...\errors.csv'
with
(
firstrow =2,
fieldterminator =',',
rowterminator ='\n'
)
GO

UPDATE errors
SET errorID = REPLACE(errorID, '"','');

select top 10 * from errors

--Create + load data into maint
DROP TABLE IF EXISTS maint
GO

create table maint
(
	datetime datetime,
	machineID float,
	comp varchar(50)	
	)
CREATE CLUSTERED COLUMNSTORE INDEX [maint_cci] ON maint WITH (DROP_EXISTING = OFF)
GO

bulk insert maint
from 'C:\...\maint.csv'
with
(
firstrow =2,
fieldterminator =',',
rowterminator ='\n'
)
GO

UPDATE maint
SET comp = REPLACE(comp, '"','');

select top 10 * from maint

--Create + load data into machines

DROP TABLE IF EXISTS machines
GO

create table machines
(
	machineID float,
	model varchar(50),
	age float	
	)
CREATE CLUSTERED COLUMNSTORE INDEX [machines_cci] ON machines WITH (DROP_EXISTING = OFF)
GO

bulk insert machines
from 'C:\...\machines.csv'
with
(
firstrow =2,
fieldterminator =',',
rowterminator ='\n'
)
GO

UPDATE machines
SET model = REPLACE(model, '"','');

select top 10 * from machines

--Create + load data into failures

DROP TABLE IF EXISTS failures
GO

create table failures
(
	datetime datetime, 
	machineID float,
	failure varchar(50)
	)
CREATE CLUSTERED COLUMNSTORE INDEX [failures_cci] ON failures WITH (DROP_EXISTING = OFF)
GO

bulk insert failures
from 'C:\...\failures.csv'
with
(
firstrow =2,
fieldterminator =',',
rowterminator ='\n'
)
GO

UPDATE failures
SET failure = REPLACE(failure, '"','');

select top 10 * from failures

