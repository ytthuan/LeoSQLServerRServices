/* assume risk tables and the table storing column names (named 'sql_risk_var') have been created in step3 */
/* procedure to do feature engineering */
set ansi_nulls on
go

set quoted_identifier on
go

DROP PROCEDURE IF EXISTS FeatureEngineer
GO

create procedure FeatureEngineer @table nvarchar(max)
as
begin

/* set binary variables */
declare @sql_bin nvarchar(max)
set @sql_bin = 'update ' + @table +
'
set is_highAmount = case when cast(transactionAmountUSD as float) > 150 then ''TRUE'' else ''FALSE'' end,
      acct_billing_address_mismatchFlag = case when paymentBillingAddress = accountAddress then ''FALSE'' else ''TRUE'' end,
	  acct_billing_postalCode_mismatchFlag = case when paymentBillingPostalCode = accountPostalCode then ''FALSE'' else ''TRUE'' end,
	  acct_billing_country_mismatchFlag = case when paymentBillingCountryCode = accountCountry then ''FALSE'' else ''TRUE'' end,
	  acct_billing_name_mismatchFlag = case when paymentBillingName = accountOwnerName then ''FALSE'' else ''TRUE'' end,
	  acct_shipping_address_mismatchFlag = case when shippingAddress = accountAddress then ''FALSE'' else ''TRUE'' end,
	  acct_shipping_postalCode_mismatchFlag = case when shippingPostalCode = accountPostalCode then ''FALSE'' else ''TRUE'' end,
	  acct_shipping_country_mismatchFlag = case when shippingCountry = accountCountry then ''FALSE'' else ''TRUE'' end,
	  shipping_billing_address_mismatchFlag = case when shippingAddress = paymentBillingAddress then ''FALSE'' else ''TRUE'' end,
	  shipping_billing_postalCode_mismatchFlag = case when shippingPostalCode = paymentBillingPostalCode then ''FALSE'' else ''TRUE'' end,
	  shipping_billing_country_mismatchFlag = case when shippingCountry = paymentBillingCountryCode then ''FALSE'' else ''TRUE'' end
from
' + @table

--print @sql_bin
exec sp_executesql @sql_bin

/* assign risk */
declare @sql_assign nvarchar(max)
set @sql_assign = 
'
DECLARE @name_1 NVARCHAR(100)
DECLARE @name_2 NVARCHAR(100)
DECLARE @getname CURSOR

SET @getname = CURSOR FOR
SELECT var_names,
	   table_names
FROM   sql_risk_var
OPEN @getname
FETCH NEXT
FROM @getname INTO @name_1,@name_2
WHILE @@FETCH_STATUS = 0
BEGIN
	EXEC AssignRisk @name_1,'+ '''' + @table + ''',@name_2  
	EXEC FillNA @name_1,@name_2,'+ '''' + @table + '''
    FETCH NEXT
    FROM @getname INTO @name_1, @name_2
END

CLOSE @getname
DEALLOCATE @getname
'
--print @sql_assign
exec sp_executesql @sql_assign
end
