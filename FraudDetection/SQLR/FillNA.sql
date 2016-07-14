/* The procedure to fill NA values using average risk in risk tables */
-- @var_name = variable name
-- @risk_table_name =  the risk table to be used
-- @table the table you want to update: training or testing
set ansi_nulls on
go

set quoted_identifier on
go

DROP PROCEDURE IF EXISTS FillNA
GO

create procedure FillNA
@var_name varchar(max),
@risk_table_name varchar(max),
@table varchar(max)

as
begin
declare @sql nvarchar(max)
set @sql = 'update ' + replace(@table, '''','''''') +
   ' 
   set ' + replace(@var_name, '''','''''') + '_risk = case when ' + replace(@var_name, '''','''''') + '_risk is null then x.mean else ' + replace(@var_name, '''','''''') + '_risk end
   from (select avg(risk) as mean from ' + replace(@risk_table_name, '''','''''') + ') x;'

exec sp_executesql @sql
end
