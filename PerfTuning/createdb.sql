IF NOT EXISTS (SELECT name FROM master.sys.databases WHERE name = N'PerfTuning')
BEGIN
  PRINT 'Creating Database PerfTuning'
  CREATE DATABASE PerfTuning;
END
ELSE
  PRINT 'Database PerfTuning already exists. Skipping creation.'
GO
