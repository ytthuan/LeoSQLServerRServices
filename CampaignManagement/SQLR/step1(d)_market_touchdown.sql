DROP TABLE IF EXISTS market_touchdown

CREATE TABLE market_touchdown
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
)

CREATE CLUSTERED COLUMNSTORE INDEX [market_touchdown_cci] ON [market_touchdown] WITH (DROP_EXISTING = OFF)

insert into market_touchdown

EXEC sp_execute_external_script @language = N'R',
                                  @script = N'

local <- RxLocalSeq()
rxSetComputeContext(local)

market = InputDataSet

campaign_table <- data.frame(market)

names(campaign_table) <- c("lead_id","age","annual_income","credit_score")

Source <- c("Inbound call","SMS","Previous Campaign")

campaign_table$Source <- sample(Source,nrow(campaign_table),replace=TRUE)

###########################################################################################################################################
##Assigning values to the various touchdown variables randomly.
## The variables created below are: 
## campaign_id, day_of_week, time_of_day, channel, comm_latency, 
###########################################################################################################################################
library(data.table)


campaign_table$campaign_id <- sample(1:6,nrow(campaign_table),replace = T)

campaign_table$day_of_week <- sample(1:7,nrow(campaign_table),replace = T)

tod <- c("Morning","Afternoon","Evening")
campaign_table$time_of_day <- sample(tod,nrow(campaign_table),replace = T)

ch <- c("Email","Cold Calling","SMS")
campaign_table$channel <- sample(ch, nrow(campaign_table), replace = T)

campaign_table$comm_latency <- sample(1:14, nrow(campaign_table),replace= T)

product_id  <- (1:6)
campaign_table$product_id  <- sample(product_id, nrow(campaign_table), replace = T)


##################################################################################
######### Creating the values table
##################################################################################

channel <- c("Email","Cold Calling","SMS")
cvalue <- c(0.04,0.035,0.025)

age <- c("Young","Middle Age","Senior Citizen")
avalue <- c(0.35,0.4,0.25)

time_of_day <- c("Morning","Afternoon","Evening")
tvalue <- c(0.31,0.36,0.33)

day_of_week <- c(1,2,3,4,5,6,7)
dvalue <- c(0.11,0.22,0.23,0.18,0.15,0.06,0.05)

annual_income <- c("<60k","60k-120k",">120k")
aivalue <- c(0.25,0.35,0.4)

product_id  <- (1:6)
pcvalue <- c(0.2,0.15,0.15,0.2,0.2,0.1)

values=cbind(expand.grid(channel,age,time_of_day,day_of_week,annual_income,product_id),expand.grid(cvalue,avalue,tvalue,dvalue,aivalue,pcvalue))
names(values)=c("channel","age","time_of_day","day_of_week","annual_income","product_id","cvalue","avalue","tvalue","dvalue","aivalue","pcvalue")

values$value <- apply(values[grepl("value",names(values))],1,prod)
values$value_final=round(nrow(campaign_table)*values$value,0)

####################################################################################

##################################################################################
######## Assigning the Conversion Flag
##################################################################################

df=data.table(values[!grepl("value",names(values))])
df1=data.table(campaign_table)
df$value_final=values$value_final

setkey(df,channel,age,time_of_day,day_of_week,annual_income,product_id)
setkey(df1,channel,age,time_of_day,day_of_week,annual_income,product_id)

df=df[df1,nomatch=0]
row.names(df) <- 1:nrow(df)

df[,cnt:=length(value_final),by=c("channel","age","time_of_day","day_of_week","annual_income","product_id")]
df$conversion_flag=0
sample=unique(data.frame(df)[,c("channel","age","time_of_day","day_of_week","annual_income","product_id","cnt","value_final")])
sample=sample[c("cnt","value_final")]

sample$value_final=ifelse(sample$cnt>sample$value_final,sample$value_final,0)
sample=cbind(index1=as.numeric(as.character(row.names(sample))),sample)
sample$index2=c(sample$index1[-1]-1,100000)
sample$cnt=NULL
sample=sample[c("index1","index2","value_final")]
set.seed(11)
df$conversion_flag[unlist(apply(sample,1,function(x) sample(x[1]:x[2],x[3])))]=1


tot_1=table(df$conversion_flag)[names(table(df$conversion_flag))==1]
df$conversion_flag[sample(which(df$conversion_flag==1),round(tot_1*.02,0))]=0
df$conversion_flag[sample(which(df$conversion_flag==0),round(tot_1*.02,0))]=1
campaign_table_1=df


####################################################################################

campaign_table_2 <- data.frame(campaign_table_1)
campaign_table_2[c("comm_latency","conversion_flag")] <- 0
campaign_table_2$channel <- sample(ch, nrow(campaign_table_2), replace = T)

######################################################################################################################################
########### Creating random amount of communications to each lead from different combinations of day of week, time of day and channel.
######################################################################################################################################

campaign_table_3 <- data.frame(campaign_table_1)
campaign_table_3=campaign_table_3[rep(1:nrow(campaign_table_3),sapply(1:nrow(campaign_table_3), function(x) sample(2:4,1))),]
set.seed(10)
campaign_table_3$channel <- sample(ch,nrow(campaign_table_3),replace = T)

campaign_table_3$day_of_week <- sample(1:7, nrow(campaign_table_3), replace = T)
campaign_table_3$time_of_day <- sample(time_of_day, nrow(campaign_table_3),replace = T)
campaign_table_3$conversion_flag <- 0
campaign_table_3$comm_latency <- sample(1:14, nrow(campaign_table_3), replace = T)

campaign_table_final <- rbind(campaign_table_1,campaign_table_2,campaign_table_3)



campaign_table_final <- data.table(campaign_table_final[order(campaign_table_final$lead_id),])
campaign_table_final$comm_id=sequence(data.frame(campaign_table_final[,length(age),by=c("lead_id")])[,2])
campaign_table_final=data.frame(campaign_table_final)
campaign_table_final$comm_latency[sample(1:nrow(campaign_table_final),round(nrow(campaign_table_final)*.01,0))]=sample(c(25,30,32,45,41,-1,-4),round(nrow(campaign_table_final)*.01,0),replace=T)

campaign_table_final <- subset(campaign_table_final, select = c(8,1:7,9:15))
campaign_table_final$value_final <- NULL
campaign_table_final$cnt <- NULL

market_touchdown <- campaign_table_final
############################################################End of market_touchdown#######################################################

'
, @input_data_1 = N'select Lead_Id,Age,Annual_Income,Credit_Score from lead_demography' 
, @output_data_1_name = N'market_touchdown'
