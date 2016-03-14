/*
The procedure to do feature engineering for training
*/

use [OnlineFraudDetection]
go

set ansi_nulls on
go

set quoted_identifier on
go

DROP PROCEDURE IF EXISTS dbo.FeatureEngineer_ForTraining
GO

create procedure dbo.FeatureEngineer_ForTraining
as
begin

/* create binary variables and assign risk by calling the stored procedure FeatureEngineer */
exec FeatureEngineer 'sql_tagged_training'


/* replace incorrect value as 0 in field isUserRegistered */
update OnlineFraudDetection.dbo.sql_tagged_training
  set isUserRegistered = case when isUserRegistered like '%[0-9]%' then '0' else isUserRegistered end
  from OnlineFraudDetection.dbo.sql_tagged_training;


/* drop temporary columns */
alter table OnlineFraudDetection.dbo.sql_tagged_training
  drop column dateNtime, timeFlag, random_number, trainFlag, transactionID,transactionCurrencyCode,transactionCurrencyConversionRate,transactionDate,localHour,transactionScenario,transactionDeviceId,transactionIPaddress,ipState,ipPostcode,ipCountryCode,browserLanguage,paymentInstrumentID,paymentBillingAddress,paymentBillingPostalCode,paymentBillingState,paymentBillingCountryCode,paymentBillingName,shippingAddress,shippingPostalCode,shippingCity,shippingState,shippingCountry,accountOwnerName,accountAddress,accountPostalCode,accountCity,accountState,accountCountry,accountOpenDate,transactionTime_new;

end
