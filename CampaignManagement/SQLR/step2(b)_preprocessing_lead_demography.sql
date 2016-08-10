
--#################### Creating a duplicate table with same structure of Lead_Demography #######################
drop table if exists Lead_Demography_1;

CREATE TABLE [Lead_Demography_1]
(
Lead_Id varchar(50),
Age	varchar(50),
Phone_No varchar(15),
Annual_Income varchar(15),
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
)

CREATE CLUSTERED COLUMNSTORE INDEX [Lead_Demography_1_cci] ON [Lead_Demography_1] WITH (DROP_EXISTING = OFF);

--######################################## Data Cleaning ###########################################
insert into Lead_Demography_1
EXEC sp_execute_external_script @language = N'R',
                                  @script = N'

local <- RxLocalSeq()
rxSetComputeContext(local)

Lead_Demography = InputDataSet

Mode <- function(x) {
  unq <- unique(x)
  unq[which.max(tabulate(match(x, unq)))]
  }

Lead_Demography$No_Of_Children <- as.numeric(Lead_Demography$No_Of_Children)
Lead_Demography$No_Of_Dependents <- as.numeric(Lead_Demography$No_Of_Dependents)

Lead_Demography[is.na(Lead_Demography$No_Of_Children),"No_Of_Children"] <- Mode(Lead_Demography$No_Of_Children)

Lead_Demography[is.na(Lead_Demography$No_Of_Dependents),"No_Of_Dependents"] <- Mode(Lead_Demography$No_Of_Dependents)

Lead_Demography[is.na(Lead_Demography$Highest_Education),"Highest_Education"] <- Mode(Lead_Demography$Highest_Education)

Lead_Demography[is.na(Lead_Demography$Household_Size),"Household_Size"] <- Mode(Lead_Demography$Household_Size)'

, @input_data_1 = N'select * from Lead_Demography'
, @output_data_1_name = N'Lead_Demography'

--######################################## Dropping the table with unclean data ###########################################

drop table if exists Lead_Demography;
exec sp_rename 'Lead_Demography_1', 'Lead_Demography';
