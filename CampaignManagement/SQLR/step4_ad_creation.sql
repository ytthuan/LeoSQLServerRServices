
/********************************************************************************************************************************************************
****** This code snippet will perform a join and select the variables needed for AD on the following four tables : 


****** 	1. market_touchdown_agg	: The table information of historical campaign data including lead response

** Structure **
Lead_Id varchar(50),
Age varchar(15),
Source	varchar(50),
Campaign_Id int,
Category varchar(30),
Email_Count int,
Call_Count int,
Sms_Count int,
Conversion_Flag int,
Comm_Frequency int,
Action_Day int,
Action_Time varchar(15),
Last_Channel varchar(15),
Second_Last_Channel varchar(15)


******	2. Target_demography : The demographic data of the lead 

** Structure **
lead_id varchar(50),
age	int,
phone_no varchar(15),
Gender varchar(15),
Marital_Status varchar(2),
credit_score int,
annual_income int,
no_of_dependents int,
Highest_education varchar(50)


******	3. Product : The product table which lists the details of various product information

** Structure **
product	varchar(50),
category varchar(50),
Term varchar(50),
No_of_people_covered varchar(50),
Premium	varchar(50),
Payment_frequency varchar(50),
Net_Amt_Insured	varchar(50),
Amt_on_Maturity_bin	varchar(50)


******	4. campaign_detail : The customer policy table which will give the policy details of a customer

** Structure **
Campaign_Name varchar(50),
launch_date	varchar(50),
sub_category varchar(50),
campaign_drivers varchar(50),
Product_id varchar(50),
product_category varchar(50),
call_for_action	varchar(50),
Channel_1 varchar(50),
Channel_2 varchar(50),
Channel_3 varchar(50),
Tenure_of_Campaign varchar(50)


********************************************************************************************************************************************************/


--############################### Creating the AD table : CM_AD ###############################
drop table if exists cm_AD;
select * into cm_AD 
from (
select
  m.lead_id as Lead_Id
, m.Age
, t.Marital_Status
, m.Credit_Score
, m.Annual_Income
, t.No_Of_Dependents
, t.Highest_Education
, m.Source
, p.Product
, p.Category
, p.Term
, p.No_Of_People_Covered
, p.Premium
, p.Payment_Frequency
, p.Amt_On_Maturity_Bin
, c.Campaign_Name
, c.Sub_Category
, c.Campaign_Drivers
, c.Call_For_Action
, c.Tenure_Of_Campaign
, m.Day_Of_Week as Action_Day
, m.Time_Of_Day as Action_Time
, m.Last_Channel
, coalesce(m.second_last_channel, 'NONE') Second_Last_Channel
, m.Email_Count 
, m.Call_Count
, m.Sms_Count
, m.Comm_Frequency
, m.Conversion_Flag

from market_touchdown_agg m	
join lead_demography as t on m.lead_id = t.Lead_Id
join campaign_detail as c on m.campaign_id = c.campaign_id
join Product as p on c.product_id = p.product_id
)a;

CREATE CLUSTERED COLUMNSTORE INDEX [cm_AD_cci] ON cm_AD WITH (DROP_EXISTING = OFF);


--############################### Creating the AD training table : CM_AD_train ###############################

drop table if exists cm_AD_train;
select * into cm_AD_train
from ( select * from cm_AD tablesample(70 Percent) )a
;


--############################### Creating the AD testing table : CM_AD_test ###############################

drop table if exists cm_AD_test;
select * into cm_AD_test
from ( 
	select * from cm_AD
	where Lead_Id not in ( select Lead_Id from cm_AD_train)
	)a
;
