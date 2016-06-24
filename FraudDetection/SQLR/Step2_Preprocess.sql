/* assume sql_taggedData table has been created in step 1 */

/* 
The procedure to preprocess data 
*/
set ansi_nulls on
go

set quoted_identifier on
go

DROP PROCEDURE IF EXISTS Preprocess
GO

DROP TABLE IF EXISTS sql_tagged_training
GO

DROP TABLE IF EXISTS sql_tagged_testing
GO

DROP TABLE IF EXISTS sql_columns
GO

create procedure Preprocess
as
begin

/* remove useless columns: tDT, sDT, eDT, startDate, startTime, endDate, endTime */
IF Exists (SELECT top 1 *  FROM sys.columns where [object_id] = OBJECT_ID('sql_taggedData') AND [name] = 'tDT')
  alter table sql_taggedData
     drop column tDT,sDT, eDT, startDate, startTime, endDate, endTime;

/* remove transaction with negative transactionAmount */
delete from sql_taggedData
where cast(transactionAmount as float) <= 0;

/* remove transaction with invalid date and time */
update sql_taggedData
  set dateNtime = convert(datetime,stuff(stuff(stuff(concat(transactionDate,transactionTime_new), 9, 0, ' '), 12, 0, ':'), 15, 0, ':'))
  from sql_taggedData
update sql_taggedData
  set timeFlag = case when (dateNtime is null) then 1 else 0 end
  from sql_taggedData

delete from sql_taggedData
where timeFlag = 1;

/* fill missing value with 0 */
-- select all column names into table sql_columns
select name into sql_columns
from syscolumns where id=object_id('sql_taggedData')

-- exclude variables which don't need to be filled
delete from sql_columns where name = 'dateNtime' or name = 'Label' or name = 'random_number' or name = 'trainFlag' or name = 'timeFlag'

-- loops to fill missing values for all variables
DECLARE @name_1 NVARCHAR(100)
DECLARE @getname CURSOR

SET @getname = CURSOR FOR
SELECT name
FROM   sql_columns
OPEN @getname
FETCH NEXT
FROM @getname INTO @name_1
WHILE @@FETCH_STATUS = 0
BEGIN
    print @name_1
    EXEC FillMissing @name_1,'sql_taggedData' 
	FETCH NEXT
    FROM @getname INTO @name_1
END

CLOSE @getname
DEALLOCATE @getname

/************************************************************/
/* create training and testing by spliting on account level */
/************************************************************/

/* sql_temp_1 table contains rows with label bigger than 0 */
select * 
into sql_temp_1
from sql_taggedData
where Label>0;


/* check the total number of rows which will be used in random number generating */
select count(*) as count
from sql_temp_1;

/* create training flag for fraud transactions (Label >0 )*/
update sql_temp_1
  set random_number = abs(checksum(newid())) % 1671
  from sql_temp_1;

update sql_temp_1
  set trainFlag = case   -- trainFlag depends on random_number, don't update it with random_number in the same block
	               when (random_number <= cast(round(1674 * 0.7,-1) as int)) then 1 -- training/testing ratio = 7:3
				   else 0
				  end
  from sql_temp_1;

/* similarly create training flag for non-fraud transactions (Label =0) */
select * 
into sql_temp_2
from sql_taggedData
where Label=0;

select count(*) as count
from sql_temp_2;

update sql_temp_2
  set random_number = abs(checksum(newid())) % 196479
  from sql_temp_2;

update sql_temp_2
  set trainFlag = case
	               when (random_number <= cast(round(198326 * 0.7,-1) as int)) then 1 -- training/testing ratio = 7:3
				   else 0
				  end
  from sql_temp_2;

/* create training data set */
select * 
into sql_tagged_training
from sql_temp_1
where trainFlag = 1;

insert into sql_tagged_training
   select * from sql_temp_2 where trainFlag=1;

/* create testing data set */
select * 
into sql_tagged_testing
from sql_temp_1
where trainFlag = 0;

insert into sql_tagged_testing
   select * from sql_temp_2 where trainFlag=0;

/* drop temporary tables */
drop table sql_temp_1;
drop table sql_temp_2;

IF NOT Exists (SELECT top 1 *  FROM sys.columns where [object_id] = OBJECT_ID('sql_tagged_training') AND [name] = 'is_highAmount')
/* add columns will be used in next step */
  alter table sql_tagged_training  
    add is_highAmount varchar(255),
      acct_billing_address_mismatchFlag varchar(255),
	  acct_billing_postalCode_mismatchFlag varchar(255),
	  acct_billing_country_mismatchFlag varchar(255),
	  acct_billing_name_mismatchFlag varchar(255),
	  acct_shipping_address_mismatchFlag varchar(255),
	  acct_shipping_postalCode_mismatchFlag varchar(255),
	  acct_shipping_country_mismatchFlag varchar(255),
	  shipping_billing_address_mismatchFlag varchar(255),
	  shipping_billing_postalCode_mismatchFlag varchar(255),
	  shipping_billing_country_mismatchFlag varchar(255),
	  transactionCurrencyCode_risk float,
      localHour_risk float,
      ipState_risk float,
      ipPostCode_risk float,
      ipCountryCode_risk float,
      browserLanguage_risk float,
      paymentBillingPostalCode_risk float,
      paymentBillingState_risk float,
      paymentBillingCountryCode_risk float,
      shippingPostalCode_risk float,
      shippingState_risk float,
      shippingCountry_risk float,
      accountPostalCode_risk float,
      accountState_risk float,
      accountCountry_risk float;
IF NOT Exists (SELECT top 1 *  FROM sys.columns where [object_id] = OBJECT_ID('sql_tagged_testing') AND [name] = 'is_highAmount')
  alter table sql_tagged_testing  
    add is_highAmount varchar(255),
      acct_billing_address_mismatchFlag varchar(255),
	  acct_billing_postalCode_mismatchFlag varchar(255),
	  acct_billing_country_mismatchFlag varchar(255),
	  acct_billing_name_mismatchFlag varchar(255),
	  acct_shipping_address_mismatchFlag varchar(255),
	  acct_shipping_postalCode_mismatchFlag varchar(255),
	  acct_shipping_country_mismatchFlag varchar(255),
	  shipping_billing_address_mismatchFlag varchar(255),
	  shipping_billing_postalCode_mismatchFlag varchar(255),
	  shipping_billing_country_mismatchFlag varchar(255),
	  transactionCurrencyCode_risk float,
      localHour_risk float,
      ipState_risk float,
      ipPostCode_risk float,
      ipCountryCode_risk float,
      browserLanguage_risk float,
      paymentBillingPostalCode_risk float,
      paymentBillingState_risk float,
      paymentBillingCountryCode_risk float,
      shippingPostalCode_risk float,
      shippingState_risk float,
      shippingCountry_risk float,
      accountPostalCode_risk float,
      accountState_risk float,
      accountCountry_risk float;

end
