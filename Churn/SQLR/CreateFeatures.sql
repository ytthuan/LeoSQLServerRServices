set ansi_nulls on
go

set quoted_identifier on
go

DROP PROCEDURE IF EXISTS [CreateFeatures]
GO

DROP Table IF EXISTS Features
GO

/* 
 Description: This file creates the features for the customer churn template.
*/
create procedure [CreateFeatures]
as
begin
	-- Calculate previous transaction time of a customer
	select UserId, TransactionId, LagTransactionTime = lag(TransactionTime) over (partition by UserId order by TransactionTime) into #LagTransactionTimes from Activities
	
	-- Calculate day difference between two subsequence transactions of a customer
	select 	Activities.TransactionId, Activities.UserId,
			TransactionInterval = isnull(datediff(day, LagTransactionTime,  TransactionTime),0)
			into #LagIntervals
			from Activities 
			join #LagTransactionTimes
			on Activities.UserId = #LagTransactionTimes.UserId and Activities.TransactionId = #LagTransactionTimes.TransactionId

	-- Feature engineering in pre churn period
	/*
	  count of purchased items and total amount of transactions per customer
	  standard deviation of count of purchased items and total amount of transactions per customer
	  average time between transactions 
	  count of transactions
	  count of locaiton, product category and items
	*/
	select A.UserId, count(A.TransactionId) as PrechurnProductsPurchased, 
				   sum(A.Quantity) as TotalQuantity, 
				   sum(A.Val) as TotalValue, 
				   isnull(stdev(A.Quantity),0) as StDevQuantity, 
				   isnull(stdev(A.Val),0) as StDevValue,
				   avg(TransactionInterval) as AvgTimeDelta,
				   datediff(day,max(A.TransactionTime),(select max(TransactionTime) from Activities))-(select ChurnPeriod from ChurnVars)  as Recency,
				   count(distinct(A.TransactionId)) as UniqueTransactionId,
				   count(distinct(A.ItemId)) as UniqueItemId,
				   count(distinct(A.Location)) as UniqueLocation,
				   count(distinct(A.ProductCategory)) as UniqueProductCategory
			into Features
			from (select Activities.*, #LagIntervals.TransactionInterval from Activities join #LagIntervals 
			      on Activities.UserId = #LagIntervals.UserId and Activities.TransactionId = #LagIntervals.TransactionId) A
			where	  
				 A.TransactionTime<=dateAdd(day, -1*(select ChurnPeriod from ChurnVars), (select max(TransactionTime) from  Activities)) 
			group by A.UserId

	/*
	  average quantity and value per transaction per customer
	  average quantity and value per item per customer
	  average quantity and value per location per customer
	  average quantity and value per product category per customer 
	*/
	alter table Features
	add TotalQuantityperUniqueTransactionId real,
		TotalQuantityperUniqueItemId real,
		TotalQuantityperUniqueLocation real,
		TotalQuantityperUniqueProductCategory real,
		TotalValueperUniqueTransactionId real,
		TotalValueperUniqueItemId real,
		TotalValueperUniqueLocation real,
		TotalValueperUniqueProductCategory real

	update Features
		set Features.TotalQuantityperUniqueTransactionId = cast(TotalQuantity as float)/(UniqueTransactionId+1),
			Features.TotalQuantityperUniqueItemId = cast(TotalQuantity as float)/(UniqueItemId+1),
			Features.TotalQuantityperUniqueLocation = cast(TotalQuantity as float)/(UniqueLocation+1),
			Features.TotalQuantityperUniqueProductCategory = cast(TotalQuantity as float)/(UniqueProductCategory+1),
			Features.TotalValueperUniqueTransactionId = TotalValue/(UniqueTransactionId+1),
			Features.TotalValueperUniqueItemId = TotalValue/(UniqueItemId+1),
			Features.TotalValueperUniqueLocation = TotalValue/(UniqueLocation+1),
			Features.TotalValueperUniqueProductCategory = TotalValue/(UniqueProductCategory+1)
		from Features

	-- Remove total item purchased from the Features table and add customer profile variables to the table
	alter table Features 
	drop column PrechurnProductsPurchased

	alter table Features 
	add Age varchar(50),
		Address varchar(50),
		Gender varchar(50),
		UserType varchar(50)

	update Features 
		set Features.Age = Users.Age,
			Features.Address = Users.Address,
			Features.UserType = Users.UserType
		from Features 
		inner join Users
		on Features.UserId = Users.UserId
end
go

execute CreateFeatures
go