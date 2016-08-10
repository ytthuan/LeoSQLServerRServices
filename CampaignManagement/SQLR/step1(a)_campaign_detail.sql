DROP TABLE IF EXISTS [Campaign_Detail]

CREATE TABLE [Campaign_Detail]
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
)

CREATE CLUSTERED COLUMNSTORE INDEX [Campaign_Detail_cci] ON [Campaign_Detail] WITH (DROP_EXISTING = OFF)

INSERT INTO [Campaign_Detail]

EXEC sp_execute_external_script @language = N'R',
                                  @script = N'
############################################################ Creation of campaign table ##################################################

local <- RxLocalSeq()
rxSetComputeContext(local)

##########################################################################################################################################
##Creating campaigns
##########################################################################################################################################

Campaign_Name <- c(
  "Above all in service",
  "All your protection under one roof",
  "Be life full confident",
  "Together we are stronger",
  "The power to help you succeed",
  "Know Money"
)

##########################################################################################################################################
## Creating and Assigning various Campaign variables.
## The various variables that have been assigned values are : 
## Category, launch_date, sub_category, campaign_drivers, product_family,call_for_action flag, channel and Tenure_of_Campaign. 
##########################################################################################################################################

table_campaign <- data.frame(Campaign_Name)
table_campaign$campaign_id <- c(1:6)        
table_campaign$Category <- "Acquisition"
table_campaign$launch_date  <- format(sample(seq(ISOdate(2014,1,1), ISOdate(2014,12,31), by="day"), 6,replace=TRUE), "%D")

sub_category <- c("Branding","Penetration","Seasonal")

table_campaign$sub_category <- sample(sub_category,6,replace=T)

campaign_drivers <- c("Discount offer","Additional Coverage","Extra benifits")

table_campaign$campaign_drivers <- sample(campaign_drivers,6,replace=T)

product_camp <- c(1:6)

table_campaign$product_id <- sample(product_camp,6,replace = F)

table_campaign$Multi_channel <- 1

table_campaign$call_for_action <- rbinom(1,6,0.7)

table_campaign$Channel_1 <- "Email"

table_campaign$Channel_2 <- "Cold Calling"

table_campaign$Channel_3 <- "SMS"

table_campaign$Focused_geopraphy <- "Nation Wide"

table_campaign$Tenure_of_Campaign <- c(rep(1,4),rep(2,2))


########################################################### End of table_campaign ########################################################'

, @output_data_1_name = N'table_campaign'