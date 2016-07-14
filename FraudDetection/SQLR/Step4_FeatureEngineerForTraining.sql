/*
The procedure to do feature engineering for training
*/

set ansi_nulls on
go

set quoted_identifier on
go

DROP PROCEDURE IF EXISTS FeatureEngineer_ForTraining
GO

create procedure FeatureEngineer_ForTraining
as
begin

/* create binary variables and assign risk by calling the stored procedure FeatureEngineer */
exec FeatureEngineer 'sql_tagged_training'


/* replace incorrect value as 0 in field isUserRegistered */
update sql_tagged_training
  set isUserRegistered = case when isUserRegistered like '%[0-9]%' then '0' else isUserRegistered end
  from sql_tagged_training;


/* drop temporary columns */
alter table sql_tagged_training
  drop column dateNtime, timeFlag, random_number, trainFlag, transactionID,transactionCurrencyCode,transactionCurrencyConversionRate,transactionDate,localHour,transactionScenario,transactionDeviceId,transactionIPaddress,ipState,ipPostcode,ipCountryCode,browserLanguage,paymentInstrumentID,paymentBillingAddress,paymentBillingPostalCode,paymentBillingState,paymentBillingCountryCode,paymentBillingName,shippingAddress,shippingPostalCode,shippingCity,shippingState,shippingCountry,accountOwnerName,accountAddress,accountPostalCode,accountCity,accountState,accountCountry,accountOpenDate,transactionTime_new;

end
