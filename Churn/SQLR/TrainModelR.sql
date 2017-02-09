set ansi_nulls on
go

set quoted_identifier on
go

DROP PROCEDURE IF EXISTS TrainModelR
GO

/* 
 Description: This file creates the procedure to train an open source R model for the customer churn template.
*/
create procedure TrainModelR
as
begin
  declare @inquery nvarchar(max) = N'
	select Age, Address, 
	TotalQuantity, TotalValue, StDevQuantity, StDevValue,
	AvgTimeDelta, Recency,
	UniqueTransactionId, UniqueItemId, UniqueLocation, UniqueProductCategory,
	TotalQuantityperUniqueTransactionId, TotalQuantityperUniqueItemId, TotalQuantityperUniqueLocation, TotalQuantityperUniqueProductCategory, 
	TotalValueperUniqueTransactionId, TotalValueperUniqueItemId, TotalValueperUniqueLocation, TotalValueperUniqueProductCategory,
	TagId
    from Features
    tablesample (70 percent) repeatable (98052)
	join Tags on Features.UserId=Tags.UserId
'
  -- Insert the trained model into a database table
  insert into ChurnModelR
  exec sp_execute_external_script @language = N'R',
                                  @script = N'

## Create model
InputDataSet$TagId <- factor(InputDataSet$TagId)
InputDataSet$Age <- factor(InputDataSet$Age)
InputDataSet$Address <- factor(InputDataSet$Address)
logitObj <- glm(TagId ~ ., family = binomial, data = InputDataSet)
summary(logitObj)

## Serialize model and put it in data frame
trained_model <- data.frame(model=as.raw(serialize(logitObj, connection=NULL)));'
,@input_data_1 = @inquery
,@output_data_1_name = N'trained_model';
end
go

execute TrainModelR
go
