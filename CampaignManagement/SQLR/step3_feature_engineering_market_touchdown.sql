DROP TABLE IF EXISTS market_touchdown_agg

CREATE TABLE market_touchdown_agg
(
Lead_Id varchar(50),
Sms_Count int,
Email_Count int,
Call_Count int,
Conversion_Flag int,
Comm_Frequency float,
Age varchar(15),
Time_Of_Day varchar(15),
Day_Of_Week VARCHAR(30),
Source	varchar(50),
Campaign_Id int,
Annual_Income varchar(50),
Credit_Score varchar(50),
Last_Channel varchar(50),
Second_Last_Channel varchar(50)
)

CREATE CLUSTERED COLUMNSTORE INDEX [market_touchdown_agg_cci] ON [market_touchdown_agg] WITH (DROP_EXISTING = OFF)

insert into market_touchdown_agg

EXEC sp_execute_external_script @language = N'R',
                                  @script = N'

library("RevoScaleR")
library(data.table)

local <- RxLocalSeq()
rxSetComputeContext(local)

############################################# Importing Market_Touchdown ###################################################

## Aggregating data based on communication history by lead

market_touchdown_1 <- InputDataSet
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

age <- c("Young","Middle Age","Senior Citizen")
avalue <- c(0.35,0.4,0.25)
set.seed(100)
Market_Touchdown_Agg$Age[Market_Touchdown_Agg$Conversion_Flag==0] <- sample(age,row_nums,replace = T, prob = avalue)

annual_income <- c("<60k","60k-120k",">120k")
aivalue <- c(0.25,0.35,0.4)
set.seed(100)
Market_Touchdown_Agg$Annual_Income[Market_Touchdown_Agg$Conversion_Flag==0] <- sample(annual_income,row_nums,replace = T, prob = aivalue)

'
, @input_data_1 = N'select * from market_touchdown' 
, @output_data_1_name = N'Market_Touchdown_Agg'

