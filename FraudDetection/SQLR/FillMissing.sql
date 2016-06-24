/* The procedure to fill missing value for each input variable */
-- @name = the name of the variable to fill NA value
-- @table = the name of table to be updated

set ansi_nulls on
go

set quoted_identifier on
go

DROP PROCEDURE IF EXISTS FillMissing
GO

create procedure FillMissing 
@name varchar(max),
@table varchar(max)
as
begin
declare @sql nvarchar(max)
set @sql = 
'update ' + @table + '
   set ' + @name + ' = isnull(' + @name + ',0)
from ' + @table + '

update ' + @table + '
   set ' + @name + ' = case when ' + @name + '= ' + '''""''' + ' then ' + '''0''' + ' else ' + @name + ' end
from ' + @table

exec sp_executesql @sql
end
