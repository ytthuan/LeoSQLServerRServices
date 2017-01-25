set ansi_nulls on
go

set quoted_identifier on
go

DROP Table IF EXISTS Tags
GO

DROP PROCEDURE IF EXISTS [CreateTag]
GO

/* 
 Description: This file creates the tag for the customer churn template.
*/
create procedure [CreateTag]
as
begin

	-- Calculate total number of transactions by each customer
	select UserId, count(TransactionId) as OverallProductsPurchased into #OverallActivities from Activities group by UserId

	-- Calculate total number of transactions by each customer in the pre-churn period
	select UserId, count(TransactionId) as PrechurnProductsPurchased
			into Tags
			from  Activities
			where TransactionTime<=dateAdd(day, -1*(select ChurnPeriod from ChurnVars), (select max(TransactionTime) from  Activities)) 
			group by UserId

	-- Create tags: those with fewer transactions than a threshold in the churn period are tagged as churners. A binary version is also created. 
	alter table Tags add Tag varchar(10)
	update Tags 
		set Tags.Tag = case 
							when ((OverallProductsPurchased-PrechurnProductsPurchased)<=(select ChurnThreshold from ChurnVars))  then 'Churner'
							else 'Nonchurner'
						end
		from Tags 
		full join #OverallActivities
		on Tags.UserId = #OverallActivities.UserId

	alter table Tags add TagId varchar(10)
	update Tags 
		set Tags.TagId = case 
							when ((OverallProductsPurchased-PrechurnProductsPurchased)<=(select ChurnThreshold from ChurnVars))  then '1'
							else '0'
						end
		from Tags 
		full join #OverallActivities
		on Tags.UserId = #OverallActivities.UserId


	alter table Tags 
	drop column PrechurnProductsPurchased
end
go

execute CreateTag
go

