

--#################### Creating a duplicate table with same structure of market_touchdown #######################
drop table if exists [market_touchdown_1];

CREATE TABLE [market_touchdown_1]
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

CREATE CLUSTERED COLUMNSTORE INDEX [market_touchdown_1_cci] ON [market_touchdown_1] WITH (DROP_EXISTING = OFF);

--######################################## Data Cleaning ###########################################

insert into [market_touchdown_1]

EXEC sp_execute_external_script @language = N'R',
                                  @script = N'
market_touchdown = InputDataSet

mean <- mean(market_touchdown$Comm_Latency)
std_dev <- sd(market_touchdown$Comm_Latency)

min <- round(mean - std_dev)
max <- round(mean + 2*std_dev)

market_touchdown[market_touchdown$Comm_Latency<0,"Comm_Latency"] <- min
market_touchdown[market_touchdown$Comm_Latency>max,"Comm_Latency"] <- max
'
, @input_data_1 = N'select * from [market_touchdown]'
, @output_data_1_name = N'market_touchdown'

--######################################## Dropping the table with unclean data ###########################################

drop table if exists market_touchdown;
exec sp_rename 'market_touchdown_1', 'market_touchdown';
