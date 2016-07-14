/* predict on testing data set */

set ansi_nulls on
go

set quoted_identifier on
go

DROP PROCEDURE IF EXISTS PredictR
GO

create procedure PredictR @table nvarchar(max)
as
begin
/* feature engineering for testing data */
exec FeatureEngineer @table

/* replace incorrect value as 0 in field isUserRegistered */
declare @sql_1 nvarchar(max)
set @sql_1 = 'update ' + @table + '
                set isUserRegistered = case when isUserRegistered like ''%[0-9]%'' then ''0'' else isUserRegistered end
			  from ' + @table
exec sp_executesql @sql_1

/* drop temporary columns */
-- keep transactionDate and transactionTime_new for testing data set in order to calculate evaluation metrics in step 6
declare @sql_2 nvarchar(max)
set @sql_2 = 'alter table ' + @table + '
                drop column dateNtime, timeFlag, random_number, trainFlag, transactionID,transactionCurrencyCode,transactionCurrencyConversionRate,localHour,transactionScenario,transactionDeviceId,transactionIPaddress,ipState,ipPostcode,ipCountryCode,browserLanguage,paymentInstrumentID,paymentBillingAddress,paymentBillingPostalCode,paymentBillingState,paymentBillingCountryCode,paymentBillingName,shippingAddress,shippingPostalCode,shippingCity,shippingState,shippingCountry,accountOwnerName,accountAddress,accountPostalCode,accountCity,accountState,accountCountry,accountOpenDate;'			  
exec sp_executesql @sql_2  

declare @modelt varbinary(max) = (select top 1 model from sql_trained_model);
declare @inquery nvarchar(max) 
set @inquery =  'select * from ' + @table;

truncate table sql_predict_score

insert into sql_predict_score
exec sp_execute_external_script @language = N'R',
                                  @script = N'
# unserialize the model object. Ready to use
mod <- unserialize(as.raw(model));

# exclude Label > 1
test_all <- InputDataSet
test <- subset(test_all,Label<=1)

test$Label <- as.factor(test$Label)
numeric_names <- c("transactionAmountUSD",
                   "transactionAmount",
                   "digitalItemCount",
                   "physicalItemCount",
                   "accountAge",
                   "paymentInstrumentAgeInAccount",
                   "sumPurchaseAmount1dPerUser",
                   "sumPurchaseAmount30dPerUser",
                   "sumPurchaseCount1dPerUser",
                   "sumPurchaseCount30dPerUser",
                   "numPaymentRejects1dPerUser")
id <- which(colnames(test) %in% numeric_names)
for(i in 1:length(id)){
  test[,id[i]] <- as.numeric(as.character(test[,id[i]]))
  id_na <- which(is.na(test[,id[i]]) ==TRUE)
  if(length(id_na) > 0){test[id_na,id[i]] <- 0}
 }
Scores <- rxPredict(modelObject = mod,
                         data = test,
                         type = "prob")
OutputDataSet <- data.frame(accountID=test$accountID, transactionDate=test$transactionDate, transactionTime=test$transactionTime_new, transactionAmountUSD=test$transactionAmountUSD, Label=test$Label, Score=Scores)
',
  @input_data_1 = @inquery,
  @params = N'@model varbinary(max)',
  @model = @modelt
 ;
end
