
/*
The procedure to reformat the data and create tag on account level
*/
set ansi_nulls on
go

set quoted_identifier on
go

DROP PROCEDURE IF EXISTS Tagging
GO

DROP TABLE IF EXISTS sql_fraud_account
GO

DROP TABLE IF EXISTS sql_taggedData
GO

create procedure Tagging
as
begin

/***********************************************/
/* reformat transactionTime to make it 6 digits*/
/***********************************************/
select *,
  case
   when len(transactionTime) = 5 then concat('0',transactionTime)
   when len(transactionTime) = 4 then concat('00',transactionTime)
   when len(transactionTime) = 3 then concat('000',transactionTime)
   when len(transactionTime) = 2 then concat('0000',transactionTime)
   when len(transactionTime) = 1 then concat('00000',transactionTime)
   else transactionTime
  end as transactionTime_new
into sql_formatted_untaggedData
from untaggedData;

select *,
  case
   when len(transactionTime) = 5 then concat('0',transactionTime)
   when len(transactionTime) = 4 then concat('00',transactionTime)
   when len(transactionTime) = 3 then concat('000',transactionTime)
   when len(transactionTime) = 2 then concat('0000',transactionTime)
   when len(transactionTime) = 1 then concat('00000',transactionTime)
   else transactionTime
  end as transactionTime_new
into sql_formatted_fraud
from fraud;

/* drop the original transactionTime column */
alter table sql_formatted_untaggedData
 drop column transactionTime

alter table sql_formatted_fraud
 drop column transactionTime

/* remove duplicate based on keys: transactionID, accountID, transactionDate, transactionDate, transactionAmount */
/* sometimes an entire transaction might be divided into multiple sub-transactions. thus, even transactionID, accountID, transactionDate/Time are same, the amount might be different */
;WITH cte_1
     AS (SELECT ROW_NUMBER() OVER (PARTITION BY transactionID, accountID, transactionDate, transactionTime_new, transactionAmount
                                       ORDER BY transactionID ASC) RN 
         FROM sql_formatted_untaggedData)
DELETE FROM cte_1
WHERE  RN > 1;

;WITH cte_2
     AS (SELECT ROW_NUMBER() OVER (PARTITION BY transactionID, accountID, transactionDate, transactionTime_new, transactionAmount
                                       ORDER BY transactionID ASC) RN 
         FROM sql_formatted_fraud)
DELETE FROM cte_2
WHERE  RN > 1;

/* check and compare the result with original template
select * 
from sql_formatted_untaggedData
order by accountID, transactionDate, transactionTime_new;
select * 
from sql_formatted_fraud
order by accountID, transactionDate, transactionTime_new;
*/

/****************************/
/* tagging on account level */
/****************************/
/* convert transaction level fraud file to account level */

-- get the startDate and startTime on top of each accountID
select accountID, transactionDate, transactionTime_new, row_number() 
over (
     partition by accountID
	 order by transactionDate ASC, transactionTime_new ASC
	 ) as rn
into sql_temp1
from sql_formatted_fraud;

-- get the endDate and endTime on top of each accountID
select accountID, transactionDate, transactionTime_new, row_number() 
over (
     partition by accountID
	 order by transactionDate DESC, transactionTime_new DESC
	 ) as rn
into sql_temp2
from sql_formatted_fraud;

-- delete rows between start and end time
delete from sql_temp1
where rn>1;
delete from sql_temp2
where rn>1;

-- create the fraud table on account level merging by accountID
select t1.accountID, t1.transactionDate as startDate, t1.transactionTime_new as startTime, t2.transactionDate as endDate, t2.transactionTime_new as endTime
into sql_fraud_account
from 
(sql_temp1 as t1
 inner join 
 sql_temp2 as t2
 on t1.accountID = t2.accountID
 );

/* drop temporary tables */
drop table sql_temp1;
drop table sql_temp2;

/* tagging */
-- merge untaggedData table with fraud_account table
select t1.*, t2.startDate, t2.startTime, t2.endDate, t2.endTime
into sql_taggedData
from 
(sql_formatted_untaggedData as t1
 left join
 sql_fraud_account as t2
 on t1.accountID = t2.accountID
 );

-- create new columns which will be used later
alter table sql_taggedData
 add tDT varchar(255),
     sDT varchar(255),
	 eDT varchar(255),
	 Label int,
	 dateNtime datetime,
	 timeFlag int,
	 random_number int,
     trainFlag int;

-- combine date and time
update sql_taggedData
 set tDT = concat(transactionDate,transactionTime_new),
     sDT = concat(startDate,startTime),
	 eDT = concat(endDate,endTime)
 from sql_taggedData;

update sql_taggedData
  set Label = case 
                when (startDate is not null and tDT >= sDT and tDT <= eDT) then 1
				when (startDate is not null and tDT < sDT) then 2
				when (startDate is not null and tDT > eDT) then 2
				when startDate is null then 0
			  end
  from sql_taggedData;

/* drop temporary tables */
drop table sql_fraud_account;
drop table sql_formatted_untaggedData;
drop table sql_formatted_fraud;

end
