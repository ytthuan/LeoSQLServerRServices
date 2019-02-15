--Create telemetry
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

--Create errors
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

--Create maint
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

--Create machines
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

--Create failures

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