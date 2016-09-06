
DROP TABLE IF EXISTS [campaign_detail];
CREATE TABLE [campaign_detail]
(
Campaign_Name varchar(50),
Campaign_Id int,
Category varchar(50),
Launch_Date	varchar(50),
Sub_Category varchar(50),
Campaign_Drivers varchar(50),
Product_Id int,
Multi_Channel varchar(50),
Call_For_Action	varchar(50),
Channel_1 varchar(50),
Channel_2 varchar(50),
Channel_3 varchar(50),
Focused_Geography varchar(50),
Tenure_Of_Campaign varchar(50)
);
CREATE CLUSTERED COLUMNSTORE INDEX [campaign_detail_cci] ON [campaign_detail] WITH (DROP_EXISTING = OFF);


DROP TABLE IF EXISTS [Product];
CREATE  TABLE [Product]
(
Product_Id	int,
Product varchar(50),
Category varchar(50),
Term int,
No_Of_People_Covered int,
Premium	int,
Payment_Frequency varchar(50),
Net_Amt_Insured	int,
Amt_On_Maturity int,
Amt_On_Maturity_Bin	varchar(50)
);
CREATE CLUSTERED COLUMNSTORE INDEX [Product_cci] ON [Product] WITH (DROP_EXISTING = OFF);


DROP TABLE IF EXISTS [market_touchdown];
CREATE TABLE [market_touchdown]
(
Lead_Id varchar(50),
Channel varchar(15),
Age varchar(15),
Time_Of_Day varchar(15),
Day_Of_Week VARCHAR(30),
Annual_Income varchar(50),
Product_Id int,
Credit_Score varchar(50),
Source	varchar(50),
Campaign_Id int,
Comm_Latency int,
Conversion_Flag int,
Comm_Id int
);
CREATE CLUSTERED COLUMNSTORE INDEX [market_touchdown_cci] ON [market_touchdown] WITH (DROP_EXISTING = OFF);


DROP TABLE IF EXISTS [lead_demography];
CREATE TABLE [lead_demography]
(
Lead_Id varchar(50),
Age	varchar(50),
Phone_No varchar(15),
Annual_Income_Bucket varchar(15),
Credit_Score varchar(15),
Country varchar(5),
[State] varchar(5),
No_Of_Dependents int,
Highest_Education varchar(50),
Ethnicity varchar(50),
No_Of_Children int,
Household_Size int,
Gender varchar(15),
Marital_Status varchar(2)
);
CREATE CLUSTERED COLUMNSTORE INDEX [lead_demography_cci] ON [lead_demography] WITH (DROP_EXISTING = OFF);
