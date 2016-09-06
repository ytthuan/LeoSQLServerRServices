
##########################################################################################################################################
## This R script will do feature normalization of the following tables:
## 1. Lead_Demography
## 2. Market_Touchdown
## Input : Corresponding data from SQL Server
## Output: Processed data 
##########################################################################################################################################
library("RevoScaleR")
##########################################################################################################################################

## Compute context
connection_string <- "Driver=SQL Server;Server=[SQL Server Name];Database=[Database Name];UID=[User ID];PWD=[User Password]"

sql_share_directory <- paste("c:\\AllShare\\",Sys.getenv("USERNAME"),sep = "")

dir.create(sql_share_directory,recursive = TRUE,showWarnings = FALSE)

sql <- RxInSqlServer(connectionString = connection_string,shareDir = sql_share_directory)

local <- RxLocalSeq()


##########################################################################################################################################
##													Market_Touchdown 
##########################################################################################################################################

rxSetComputeContext(sql)

m_touchdown <- RxSqlServerData(table = "market_touchdown", stringsAsFactors = T,connectionString = connection_string)

market_touchdown <- rxImport(inData = m_touchdown, stringsAsFactors = T,outFile = NULL)

## Replacing Outliers with appropriate Values

mean <- mean(market_touchdown$Comm_Latency)
std_dev <- sd(market_touchdown$Comm_Latency)

min <- round(mean - std_dev)
max <- round(mean + 2*std_dev)

market_touchdown[market_touchdown$Comm_Latency<0,"Comm_Latency"] <- min
market_touchdown[market_touchdown$Comm_Latency>max,"Comm_Latency"] <- max

############################################ Writing changes back to Market_Touchdown table #############################################

market_touchdown_columns <- c(
  Lead_Id = "character",
  channel = "character",
  Age = "character",
  time_of_day = "character",
  day_of_week = "numeric",
  annual_income = "character",
  product_category = "character",
  credit_score = "character",
  Source = "character",
  campaign_id = "numeric",
  comm_latency = "numeric",
  conversion_flag = "numeric",
  comm_id = "numeric"
)

market_touchdown_table <- RxSqlServerData(table = "market_touchdown",
                                          connectionString = connection_string,
                                          colClasses = market_touchdown_columns)

rxSetComputeContext(local)

rxDataStep(inData = market_touchdown, 
		   outFile = market_touchdown_table, 
		   overwrite = T)


##########################################################################################################################################
##													Lead_Demography 
##########################################################################################################################################

rxSetComputeContext(sql)

l_demography <- RxSqlServerData(table = "lead_demography", stringsAsFactors = T,connectionString = connection_string)

Lead_Demography <- rxImport(inData = l_demography, stringsAsFactors = T,outFile = NULL)

Mode <- function(x) {
					unq <- unique(x)
					unq[which.max(tabulate(match(x, unq)))]
					}


## Replacing values of no_of_children, no_of_dependents, Highest_education & household_size

Lead_Demography$No_Of_Children <- as.numeric(Lead_Demography$No_Of_Children)

Lead_Demography$No_Of_Dependents <- as.numeric(Lead_Demography$No_Of_Dependents)

Lead_Demography[is.na(Lead_Demography$No_Of_Children),"No_Of_Children"] <- Mode(Lead_Demography$No_Of_Children)

Lead_Demography[is.na(Lead_Demography$No_Of_Dependents),"No_Of_Dependents"] <- Mode(Lead_Demography$No_Of_Dependents)

Lead_Demography[is.na(Lead_Demography$Highest_Education),"Highest_Education"] <- Mode(Lead_Demography$Highest_Education)

Lead_Demography[is.na(Lead_Demography$Household_Size),"Household_Size"] <- Mode(Lead_Demography$Household_Size)

############################################ Writing changes back to Lead_Demography table #############################################

lead_demography_columns <- c(
	Lead_Id = "character",
	Age = "character",
	Phone_No = "character",
	Annual_Income_Bucket = "character",
	Credit_Score = "character",
	Country = "character",
	State = "character",
	No_Of_Dependents = "numeric",
	No_Of_Dependents = "numeric",
	Highest_Education = "character",
	Ethnicity = "character",
	No_Of_Children = "numeric",
	Household_Size = "numeric",
	Gender = "character",
	Marital_Status = "character"
	)

lead_demography_table <- RxSqlServerData(table = "lead_demography",connectionString = connection_string,colClasses = lead_demography_columns)

rxSetComputeContext(local)

rxDataStep(inData = Lead_Demography, outFile = lead_demography_table,overwrite = T)

##############################################################  End of code  #############################################################

