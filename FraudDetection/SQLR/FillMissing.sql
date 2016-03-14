/* The procedure to fill missing value for each input variable */
-- @name = the name of the variable whose NA value to be filled

use [OnlineFraudDetection]
go

set ansi_nulls on
go

set quoted_identifier on
go

DROP PROCEDURE IF EXISTS dbo.FillMissing
GO

create procedure dbo.FillMissing 
@name varchar(max)
as
begin
declare @sql nvarchar(max)
set @sql = 
'update sql_taggedData 
   set ' + @name + ' = isnull(' + @name + ',0)
from sql_taggedData

update sql_taggedData
   set ' + @name + ' = case when ' + @name + '= ' + '''""''' + ' then ' + '''0''' + ' else ' + @name + ' end
from sql_taggedData'

exec sp_executesql @sql
end
