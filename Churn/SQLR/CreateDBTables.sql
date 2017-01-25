DROP TABLE IF EXISTS Users
GO

create table Users
(
       UserId varchar(50) primary key,
       Age varchar(50),
       Address varchar(50),
       Gender varchar(50),
       UserType varchar(50)
)

DROP TABLE IF EXISTS Activities
GO

create table Activities
(
       [Column0] bigint,
       TransactionId bigint primary key,
       TransactionTime datetime,
       UserId varchar(50),
	   ItemId bigint,
	   Quantity bigint,
	   Val real,
	   Location varchar(50),
       ProductCategory varchar(50)
)

DROP TABLE IF EXISTS ChurnVars
GO

create table ChurnVars
(
	ChurnPeriod int,
	ChurnThreshold int
)
insert into ChurnVars (ChurnPeriod,ChurnThreshold)        values (21, 0)

DROP TABLE IF EXISTS ChurnModelR
GO

create table ChurnModelR
(
	model varbinary(max) not null
)

DROP TABLE IF EXISTS ChurnModelRx
GO

create table ChurnModelRx
(
	model varbinary(max) not null
)

DROP TABLE IF EXISTS ChurnPredictR
GO

create table ChurnPredictR
(
       UserId varchar(50), 
       Tag varchar(10),   
	   TagId char(1), 
       Score float,
	   Auc float
)

DROP TABLE IF EXISTS ChurnPredictRx
GO

create table ChurnPredictRx
(
       UserId varchar(50), 
       Tag varchar(10),    
	   TagId char(1), 
       Score float,
	   Auc float
)
go
