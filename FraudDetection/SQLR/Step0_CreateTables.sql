/* create tables to store untagged and fraud data */

use [OnlineFraudDetection]
go

set ansi_nulls on
go

set quoted_identifier on
go

DROP TABLE IF EXISTS OnlineFraudDetection.dbo.untaggedData
GO

create table OnlineFraudDetection.dbo.untaggedData
(
transactionID varchar(255),
accountID varchar(255),
transactionAmountUSD varchar(255),
transactionAmount varchar(255),
transactionCurrencyCode varchar(255),
transactionCurrencyConversionRate varchar(255),
transactionDate varchar(255),
transactionTime varchar(255),
localHour varchar(255),
transactionScenario varchar(255),
transactionType varchar(255),
transactionMethod varchar(255),
transactionDeviceType varchar(255),
transactionDeviceId varchar(255),
transactionIPaddress varchar(255),
ipState varchar(255),
ipPostcode varchar(255),
ipCountryCode varchar(255),
isProxyIP varchar(255),
browserType varchar(255),
browserLanguage varchar(255),
paymentInstrumentType varchar(255),
cardType varchar(255),
cardNumberInputMethod varchar(255),
paymentInstrumentID varchar(255),
paymentBillingAddress varchar(255),
paymentBillingPostalCode varchar(255),
paymentBillingState varchar(255),
paymentBillingCountryCode varchar(255),
paymentBillingName varchar(255),
shippingAddress varchar(255),
shippingPostalCode varchar(255),
shippingCity varchar(255),
shippingState varchar(255),
shippingCountry varchar(255),
cvvVerifyResult varchar(255),
responseCode varchar(255),
digitalItemCount varchar(255),
physicalItemCount varchar(255),
purchaseProductType varchar(255),
accountOwnerName varchar(255),
accountAddress varchar(255),
accountPostalCode varchar(255),
accountCity varchar(255),
accountState varchar(255),
accountCountry varchar(255),
accountOpenDate varchar(255),
accountAge varchar(255),
isUserRegistered varchar(255),
paymentInstrumentAgeInAccount varchar(255),
sumPurchaseAmount1dPerUser varchar(255),
sumPurchaseAmount30dPerUser varchar(255),
sumPurchaseCount1dPerUser varchar(255),
sumPurchaseCount30dPerUser varchar(255),
numPaymentRejects1dPerUser varchar(255)
);

DROP TABLE IF EXISTS OnlineFraudDetection.dbo.fraud
GO

create table OnlineFraudDetection.dbo.fraud
(
transactionID varchar(255),
accountID varchar(255),
transactionAmount varchar(255),
transactionCurrencyCode varchar(255),
transactionDate varchar(255), 
transactionTime varchar(255),
localHour varchar(255),
transactionDeviceId varchar(255),
transactionIPaddress varchar(255)
);
