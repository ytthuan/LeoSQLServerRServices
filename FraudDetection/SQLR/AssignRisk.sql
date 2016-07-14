/* The procedure to assign risk to each input variable */
-- @var_name = variable name
-- @table_name = the table to be updated
-- @risk_table_name =  the risk table to be used

set ansi_nulls on
go

set quoted_identifier on
go

DROP PROCEDURE IF EXISTS AssignRisk
GO

create procedure AssignRisk
@var_name varchar(max),
@table_name varchar(max),
@risk_table_name varchar(max)

as
begin
declare @sql nvarchar(max)
set @sql = 
'update ' + @table_name + 
' set ' + @var_name + '_risk = risk from (' +
 @table_name + ' as t1 left join ' + @risk_table_name + ' as t2 on t1.' + @var_name + ' = t2.' + @var_name + ');'
/* example:
update sql_tagged_training set localHour_risk = risk from (sql_tagged_training as t1 left join sql_risk_localHour as t2 on t1.localHour = t2.localHour);
*/
exec sp_executesql @sql
end


