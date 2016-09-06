--
-- remove old rdemo user and login from master
--
USE [master]
GO
IF EXISTS (SELECT name  FROM sys.database_principals WHERE name = 'rdemo')
BEGIN
	PRINT 'Deleting old rdemo user from master'
    DROP USER [rdemo]
END
GO
IF EXISTS (SELECT name  FROM master.sys.server_principals WHERE name = 'rdemo')
BEGIN
	PRINT 'Deleting old rdemo login from master'
	DROP LOGIN [rdemo]
END
GO
--
-- create new rdemo login in master
--
USE [master]
GO
PRINT 'Creating rdemo login in master'
CREATE LOGIN [rdemo] WITH PASSWORD=N'D@tascience', CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF;
CREATE USER [rdemo] FOR LOGIN [rdemo] WITH DEFAULT_SCHEMA=[db_datareader]
--ALTER ROLE [db_rrerole] ADD MEMBER [rdemo]
ALTER ROLE [db_owner] ADD MEMBER [rdemo]
