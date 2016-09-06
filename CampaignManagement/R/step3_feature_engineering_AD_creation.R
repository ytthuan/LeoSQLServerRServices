##########################################################################################################################################
## This R script will do the following :
## 1. Aggregate Market_Touchdown data to get the communication history by Lead_Id
## 2. AD creation
## 3. Test data and Train Data creation
## Input : Corresponding data from SQL Server
## Output: Test, Train and Scored dataset
##########################################################################################################################################
library("RevoScaleR")
################################################# Connecting to table ###################################################

connection_string <- "Driver=SQL Server;Server=[SQL Server Name];Database=[Database Name];UID=[User ID];PWD=[User Password]"

sql_share_directory <- paste("c:\\AllShare\\", Sys.getenv("USERNAME"), sep = "")
dir.create(sql_share_directory, recursive = TRUE, showWarnings = FALSE)
sql <- RxInSqlServer(connectionString = connection_string, shareDir = sql_share_directory)

local <- RxLocalSeq()

rxSetComputeContext(sql)

############################################# Importing Market_Touchdown ###################################################

market_touchdown <- RxSqlServerData(table = "market_touchdown", stringsAsFactors = T,connectionString = connection_string)

market_touchdown_1 <- rxImport(inData = market_touchdown, stringsAsFactors = T,outFile = NULL)

## Aggregating data based on communication history by lead

library(data.table)
market_touchdown <- data.table(market_touchdown_1)
dt=dcast.data.table(market_touchdown,Lead_Id~Channel,fun=length,value.var = "Channel")
names(dt)=c("Lead_Id","SMS_Count","Email_Count","Call_Count")
Conversion_Flag=market_touchdown[,list(Conversion_Flag=max(Conversion_Flag)),by=c("Lead_Id")]
Comm_Frequency=market_touchdown[Comm_Latency!=0,list(Comm_Frequency=mean(Comm_Latency)),by=c("Lead_Id")]
setkey(dt,Lead_Id)
setkey(Conversion_Flag,Lead_Id)
setkey(dt,Lead_Id)
merged=Reduce(merge,list(dt,Conversion_Flag,Comm_Frequency))

rm(dt,Conversion_Flag,Comm_Frequency)

#### Subsetting for Lead_Id which have not converted

Lead_Id_0=merged[Conversion_Flag==0,.(Lead_Id)]
Lead_Id_0=Lead_Id_0[market_touchdown, nomatch=0L, on = "Lead_Id"]
Lead_Id_0$row_num=1:nrow(Lead_Id_0)
Lead_Id_0=Lead_Id_0[,max:=max(Comm_Id),by=c("Lead_Id")]
row_1=Lead_Id_0$row_num[Lead_Id_0$Comm_Id==Lead_Id_0$max]
row_2=row_1-1
Lead_Id_0=Lead_Id_0[c(row_1,row_2),]
Lead_Id_0=Lead_Id_0[order(Lead_Id_0$Lead_Id,Lead_Id_0$row_num),]

#### Subsetting for Lead_Id which have converted

Lead_Id_1=merged[Conversion_Flag==1,.(Lead_Id)]
Lead_Id_1=Lead_Id_1[market_touchdown, nomatch=0L, on = "Lead_Id"]
x_1=Lead_Id_1[Lead_Id_1$Conversion_Flag==1,]
x_not_1=Lead_Id_1[Lead_Id_1$Conversion_Flag!=1,]
x_not_1=x_not_1[,cnt:=length(Age),by="Lead_Id"]
y=unique(x_not_1[,.(Lead_Id,cnt)])
y$index2=cumsum(y$cnt)
y$index1=c(1,y$index2[-nrow(y)]+1)
set.seed(15)
x_not_1=x_not_1[apply(y[,.(index1,index2)],1,function(x) sample(x[1]:x[2],1)),]
x_not_1$cnt=NULL
Lead_Id_1=rbind(x_1,x_not_1)

Lead_Id_0$row_num=NULL
Lead_Id_0$max=NULL

Lead_Id_1=Lead_Id_1[order(Lead_Id_1$Lead_Id,-Lead_Id_1$Comm_Id),]


### Combining both groups

Lead_combined=rbind(Lead_Id_0,Lead_Id_1)

Last_Mediums=Lead_combined[seq(2,nrow(Lead_combined),by=2),.(Lead_Id,Age,Time_Of_Day,Day_Of_Week,Source,Campaign_Id,Annual_Income,Credit_Score)]

names(Last_Mediums)=c("Lead_Id","Age","Action_Time","Action_Day","Source","Campaign_Id","Annual_Income","Credit_Score")
Lead_combined$channel_order=c("Second_Last_Channel","Last_Channel")
Lead_combined=dcast.data.table(Lead_combined,Lead_Id~channel_order,value.var = "Channel")

rm(Lead_Id_1,Lead_Id_0,x_1,x_not_1,y,row_2,row_1,market_touchdown)
setkey(Lead_combined,Lead_Id)
setkey(merged,Lead_Id)

##Creating the final aggregated data

Market_Touchdown_Agg=Reduce(merge,list(merged,Last_Mediums,Lead_combined))

row_nums=length(which(Market_Touchdown_Agg$Conversion_Flag==0))

channel <- c("Email","Cold Calling","SMS")
cvalue <- c(.4,0.35,0.25)
set.seed(100)
Market_Touchdown_Agg$Last_Channel[Market_Touchdown_Agg$Conversion_Flag==0] <- sample(channel,row_nums,replace=TRUE,prob=cvalue)

dvalue <- c(0.11,0.22,0.23,0.18,0.15,0.06,0.05)
set.seed(100)
Market_Touchdown_Agg$Action_Day[Market_Touchdown_Agg$Conversion_Flag==0] <- sample(1:7,row_nums,replace = T, prob = dvalue)

tod <- c("Morning","Afternoon","Evening")
tvalue <- c(0.31,0.36,0.33)
set.seed(100)
Market_Touchdown_Agg$Action_Time[Market_Touchdown_Agg$Conversion_Flag==0] <- sample(tod,row_nums,replace = T, prob = tvalue)



##############################################  Importing tables to create AD  #############################################
## Importing Lead_Demography

Lead_Demography <- RxSqlServerData(table = "Lead_Demography", stringsAsFactors = T,connectionString = connection_string)

Lead_Demography <- data.table(rxImport(inData = Lead_Demography, stringsAsFactors = T,outFile = NULL))

#############################################################################################################################
## Importing Campaign_Detail

Campaign_Detail <- RxSqlServerData(table = "Campaign_Detail", stringsAsFactors = T,connectionString = connection_string)

Campaign_Detail <- data.table(rxImport(inData = Campaign_Detail, stringsAsFactors = T,outFile = NULL))

#############################################################################################################################
## Importing Product

Product <- RxSqlServerData(table = "Product", stringsAsFactors = T,connectionString = connection_string)

Product <- data.table(rxImport(inData = Product, stringsAsFactors = T,outFile = NULL))

###########################################  Creating AD   ###################################################

Lead_Demography=Lead_Demography[,.(Lead_Id,No_Of_Dependents,Highest_Education,Marital_Status)]
Campaign_Detail=Campaign_Detail[,.(Campaign_Id,Product_Id,Campaign_Name,Sub_Category,Campaign_Drivers,Call_For_Action,Tenure_Of_Campaign)]
Product=Product[,.(Product_Id,Product,Category,Term,No_Of_People_Covered,Premium,Payment_Frequency,Amt_On_Maturity_Bin)]


setkey(Campaign_Detail,Product_Id)
setkey(Product,Product_Id)
Campaign_Product <- Campaign_Detail[Product,nomatch=0]

setkey(Market_Touchdown_Agg,Lead_Id)
setkey(Lead_Demography,Lead_Id)
lead_market_mix <-Market_Touchdown_Agg[Lead_Demography,nomatch=0] 

setkey(lead_market_mix,Campaign_Id)
setkey(Campaign_Product,Campaign_Id)
CM_AD <- lead_market_mix[Campaign_Product,nomatch=0]

CM_AD$Campaign_Id <- NULL
CM_AD$Product_Id <- NULL

############################################  Creating Train and Test Tables  ###############################################

CM_AD_Train <- CM_AD[sample(length(CM_AD$Lead_Id),0.7*(nrow(CM_AD))),] 

CM_AD_Test <- CM_AD[!(CM_AD$Lead_Id %in% CM_AD_Train$Lead_Id),]


############################################  Writing Tables into Database  ##################################################

rxSetComputeContext(sql)

CM_AD_columns <- c(
  Lead_Id = "character",
  SMS_Count = "numeric",
  Email_Count = "numeric",
  Call_Count = "numeric",
  Conversion_Flag = "numeric",
  Comm_Frequency = "numeric",
  Age = "character",
  Action_Time = "character",
  Action_Day = "numeric",
  Source = "character",
  Annual_Income = "character",
  Credit_Score = "character",
  Last_Channel = "character",
  Second_Last_Channel = "character",
  No_Of_Dependents = "numeric",
  Highest_Education = "character",
  Marital_Status = "character",
  Campaign_Name = "character",
  Sub_Category = "character",
  Campaign_Drivers = "character",
  Call_For_Action = "numeric",
  Tenure_of_Campaign = "numeric",
  Product = "character",
  Category = "character",
  Term = "numeric",
  No_Of_People_Covered = "numeric",
  Premium = "numeric",
  Payment_Frequency = "character",
  Amt_On_Maturity_Bin = "character"
)

CM_AD_table <- RxSqlServerData(table = "CM_AD",connectionString = connection_string,colClasses = CM_AD_columns)

rxSetComputeContext(local)

rxDataStep(inData = CM_AD,outFile = CM_AD_table,overwrite = T)


rxSetComputeContext(sql)


CM_AD_Train_table <- RxSqlServerData(table = "CM_AD_Train",connectionString = connection_string,colClasses = CM_AD_columns)

rxSetComputeContext(local)

rxDataStep(inData = CM_AD_Train,outFile = CM_AD_Train_table,overwrite = T)


rxSetComputeContext(sql)

CM_AD_Test_table <- RxSqlServerData(table = "CM_AD_Test",connectionString = connection_string,colClasses = CM_AD_columns)

rxSetComputeContext(local)

rxDataStep(inData = CM_AD_Test,outFile = CM_AD_Test_table,overwrite = T)
