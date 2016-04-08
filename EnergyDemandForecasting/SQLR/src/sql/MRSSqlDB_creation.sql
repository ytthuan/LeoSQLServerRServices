USE [msdb]
GO

/* enable agent */
sp_configure 'show advanced options',1
go
reconfigure with override
go
sp_configure 'Agent XPs',1
go
reconfigure with override
go
sp_configure 'show advanced options',0
go
reconfigure with override
go

USE $(DBName)
GO

/* create tables */
IF OBJECT_ID('dbo.RegionLookup', 'U') IS NOT NULL
  DROP TABLE [dbo].[RegionLookup]
GO
CREATE TABLE [dbo].[RegionLookup] (
    [region]      BIGINT         NOT NULL,
    [Name]      NVARCHAR (MAX) NULL,
    [Latitude]  FLOAT (53)     NULL,
    [Longitude] FLOAT (53)     NULL,
	CONSTRAINT [PK_RegionLookup] PRIMARY KEY CLUSTERED ( [region] ASC)
);
go


IF OBJECT_ID('dbo.stepLookup', 'U') IS NOT NULL
  DROP TABLE [dbo].[stepLookup]
GO

CREATE TABLE [dbo].[stepLookup] (
	[step]			int				not null,
	[step_name]		nvarchar(64)		NOT NULL,	
	CONSTRAINT [PK_stepLookup] PRIMARY KEY CLUSTERED ( [step] ASC)	
);
go

IF OBJECT_ID('dbo.runlogs', 'U') IS NOT NULL
  DROP TABLE [dbo].[runlogs]
GO

CREATE TABLE [dbo].[runlogs] (
	[step]			int				not null,
	[utcTimestamp]	DATETIME		NOT NULL,
    [region]      	NVARCHAR(64)     NOT NULL,
	[runTimestamp]	datetime		not null,
	[success_flag]		int,
    [ErrorMessage]  		varchar (1000) 		NULL,	
	CONSTRAINT [PK_runlogs] PRIMARY KEY CLUSTERED ( step asc, [utcTimestamp] ASC, [region] ASC, runTimestamp asc)	
);
go

IF OBJECT_ID('dbo.DemandSeed', 'U') IS NOT NULL
  DROP TABLE [dbo].[DemandSeed]
GO

CREATE TABLE [dbo].[DemandSeed] (
	[utcTimestamp]	DATETIME		NOT NULL,
    [region]      	NVARCHAR(64)     NOT NULL,
    [Load]  		FLOAT (53) 		NULL,
    CONSTRAINT [PK_DemandSeed] PRIMARY KEY CLUSTERED ( [utcTimestamp] ASC, [region] ASC)	
);
go

IF OBJECT_ID('dbo.TemperatureSeed', 'U') IS NOT NULL
  DROP TABLE [dbo].[TemperatureSeed]
GO

CREATE TABLE [dbo].[TemperatureSeed] (
	[utcTimestamp]	DATETIME		NOT NULL,
    [region]      	NVARCHAR(64)     NOT NULL,
    [Temperature]  	FLOAT (53) 		NULL,
	[Flag]			INT				NOT NULL,
    CONSTRAINT [PK_TemperatureSeed] PRIMARY KEY CLUSTERED ( [utcTimestamp] ASC, [region] ASC)	
);
go

IF OBJECT_ID('dbo.DemandReal', 'U') IS NOT NULL
  DROP TABLE [dbo].[DemandReal]
GO

CREATE TABLE [dbo].[DemandReal] (
    [utcTimestamp] 	DATETIME   		NOT NULL,
    [region]      	NVARCHAR(64)     NOT NULL,
    [Load]  		FLOAT (53) 		NULL,
    CONSTRAINT [PK_DemandReal] PRIMARY KEY CLUSTERED ( [utcTimestamp] ASC, [region] ASC)
);
go

IF OBJECT_ID('dbo.TemperatureReal', 'U') IS NOT NULL
  DROP TABLE [dbo].[TemperatureReal]
GO

CREATE TABLE [dbo].[TemperatureReal] (
    [utcTimestamp] 	DATETIME   NOT NULL,
    [region]      	NVARCHAR(64)     NOT NULL,
    [Temperature]  	FLOAT (53) 		NULL,
	[Flag]			INT				NOT NULL,
    CONSTRAINT [PK_TemperatureReal] PRIMARY KEY CLUSTERED ( [utcTimestamp] ASC, [region] ASC)
);
go

IF OBJECT_ID('dbo.DemandForecast', 'U') IS NOT NULL
  DROP TABLE [dbo].[DemandForecast]
GO

IF OBJECT_ID('dbo.Model', 'U') IS NOT NULL
  DROP TABLE [dbo].[Model]
GO
CREATE TABLE [dbo].Model (
	[Model] 		varbinary(max)	NOT NULL,
    [region]      	NVARCHAR(64)     NOT NULL,
	[startTime]		NVARCHAR(50)		NOT NULL,
    CONSTRAINT [PK_Model] PRIMARY KEY CLUSTERED ( [region] ASC, startTime ASC)
);

IF OBJECT_ID('dbo.DemandForecast', 'U') IS NOT NULL
  DROP TABLE [dbo].[DemandForecast]
GO

CREATE TABLE [dbo].[DemandForecast] (
    [utcTimestamp] 	DATETIME   		NOT NULL,
    [region]      	NVARCHAR(64)     NOT NULL,
    [Load]  		FLOAT (53) 		NULL,
    CONSTRAINT [PK_DemandForecast] PRIMARY KEY CLUSTERED ( [utcTimestamp] ASC, [region] ASC)
);
go

IF OBJECT_ID('dbo.InputAllFeatures', 'U') IS NOT NULL
  DROP TABLE [dbo].[InputAllFeatures]
GO

CREATE TABLE InputAllFeatures(
   utcTimestamp datetime,
   region varchar(64),
	Load float,   
   temperature float,
   lag24 float,
   lag25 float,
   lag26 float,
   lag27 float,
   lag28 float,
   lag31 float,
   lag36 float,
   lag40 float,
   lag48 float,
   lag72 float,
   lag96 float,
   hourofday tinyint,
   dayinweek tinyint,
   monofyear tinyint,
   weekend tinyint,
   businesstime tinyint,
   ismorning tinyint,
   LinearTrend float,
   WKFreqCos1 float,
   WKFreqSin1 float,
   WDFreqCos1 float,
   WDFreqSin1 float,
   WKFreqCos2 float,
   WKFreqSin2 float,
   WDFreqCos2 float,
   WDFreqSin2 float,
    CONSTRAINT [PK_InputAllFeatures] PRIMARY KEY CLUSTERED ( [utcTimestamp] ASC, [region] ASC)	   );
GO	  

IF ('$(WindowsAuth)' =  'YES')
	insert into RegionLookup values(101,'SOUTH',34.939985,-119.630127);
ELSE
	BEGIN
		insert into RegionLookup values(101,'SOUTH',34.939985,-119.630127);
		insert into RegionLookup values(102,'CENTRAL',37.753344,-122.13501);
		insert into RegionLookup values(103,'NORTH',39.232253,-122.069092);
		insert into RegionLookup values(104,'EAST',36.1215,-115.1739);
	END

insert into stepLookup values(1,'FeaturEngineering');
insert into stepLookup values(2,'Training');
insert into stepLookup values(3,'Predicting');


