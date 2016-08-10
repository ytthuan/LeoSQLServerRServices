##########################################################################################################################################
## This R script will simulate data for the following tables:
## 1. Lead_Demography
## 2. Market_Touchdown
## 3. Campaign_Detail
## 4. Product
## Output: Product, Campaign_Detail, Lead_Demography & Market_Touchdown tables to SQL Server

##########################################################################################################################################
library("RevoScaleR")
##########################################################################################################################################

## Compute context

connection_string <- "Driver=SQL Server;Server=[SQL Server Name];Database=[Database Name];UID=[User ID];PWD=[User Password]"

sql_share_directory <- paste("c:\\AllShare\\", Sys.getenv("USERNAME"), sep = "")

dir.create(sql_share_directory, recursive = TRUE, showWarnings = FALSE)

sql <- RxInSqlServer(connectionString = connection_string, shareDir = sql_share_directory)

local <- RxLocalSeq()

##########################################################################################################################################
##														Declare the number of Unique leads
##########################################################################################################################################

no_of_unique_leads <- 100000

##########################################################################################################################################
##														Creating Lead_Demography table
##########################################################################################################################################

library(data.table)

##Generating lead_id

sample_fn=function(x)
{
  p  <- paste(sample(c(letters[1:6],0:9),32,replace=TRUE),collapse="")
  p=paste(
    substr(p,1,8),"-",
    substr(p,9,12),"-",
    substr(p,13,16),"-",
    substr(p,17,20),"-",
    substr(p,21,32),
    sep = "",collapse = "")
  
  q=paste(9,paste( sample( 0:9, 9, replace=TRUE ), collapse="" ),sep="")
  as.matrix(data.frame(lead_id=p,phone_no=q,stringsAsFactors = F))
  
}

lead_id=function(x)
{
  sapply(1:x, function(x) sample_fn() )
}

table_target <- data.frame(lead_id=t(lead_id(no_of_unique_leads))) #Setting the number of Leads here
names(table_target)=c("lead_id","phone_no")

age <- c("Young","Middle Age","Senior Citizen")
table_target$age <- sample(age,nrow(table_target),replace=T)

annual_income <- c("<60k","60k-120k",">120k")

table_target$annual_income_bucket <- sample(annual_income, nrow(table_target), replace = T) 

credit <- c("<350","350-700",">700")

table_target$credit_score <- sample(credit, nrow(table_target), replace = T)

table_target$Country <- rep("US",nrow(table_target))

state <- c("US",  "AL",	"AK",	"AZ",	"AR",	"CA",	"CO",	"CT",	"DE",	"DC",	"FL",	"GA",	"HI",	"ID",	"IL",	"IN",	"IA",	"KS",	"KY",	"LA",	"ME",	"MD",	"MA",	"MI",	"MN",	"MS",	"MO",	"MT",	"NE",	"NV",	"NH",	"NJ",	"NM",	"NY",	"NC",	"ND",	"OH",	"OK",	"OR",	"PA",	"RI",	"SC",	"SD",	"TN",	"TX",	"UT",	"VT",	"VA",	"WA",	"WV",	"WI",	"WY",	"AS",	"GU",	"MP",	"PR",	"VI",	"UM",	"FM",	"MH",	"PW")
table_target$state <- sample(state,nrow(table_target),replace=TRUE)

table_target$no_of_children <- sample(c(0:3),nrow(table_target),replace=T)

education <- c("High School","Attended Vocational","Graduate School","College") 

table_target$Highest_education <- sample(education,nrow(table_target),replace=TRUE)

et <- c("White Americans","African American","Hispanic","Latino")
table_target$ethnicity <- sample(et,nrow(table_target),replace=TRUE)

table_target$no_of_dependents <- round(runif(nrow(table_target),0,table_target$no_of_children),digits=0)

table_target$household_size <- round(runif(nrow(table_target),1,table_target$no_of_children+1),digits=0)

table_target$Gender <- ""
table_target$Gender[1:(0.505*(nrow(table_target)))] <- "Male"
table_target$Gender[(0.505*(nrow(table_target))+1):(nrow(table_target))] <- "Female"

table_target$Marital_Status <- ""
table_target$Marital_Status[1:(0.45*(nrow(table_target)))] <- "S"          #Single
table_target$Marital_Status[(0.45*(nrow(table_target))+1):(0.8*(nrow(table_target)))] <- "M"          #Married
table_target$Marital_Status[(0.8*(nrow(table_target))+1):(0.9*(nrow(table_target)))] <- "D"          #Divorced
table_target$Marital_Status[(0.9*(nrow(table_target))+1):(nrow(table_target))] <- "W"          #Widowed


################## Inserting NA values in no_of_children,no_of_dependents,household_size and Highest_education ##################

table_target$no_of_children[sample(1:nrow(table_target) ,round(0.01*(nrow(table_target)),0))] = NA
table_target$no_of_dependents[sample(1:nrow(table_target) ,round(0.01*(nrow(table_target)),0))] = NA
table_target$household_size[sample(1:nrow(table_target) ,round(0.01*(nrow(table_target)),0))] = NA
table_target$Highest_education[sample(1:nrow(table_target) ,round(0.01*(nrow(table_target)),0))] = NA

names(table_target) <- c("Lead_Id","Phone_No","Age","Annual_Income","Credit_Score","Country","State",
                         "No_Of_Children","Highest_Education","Ethnicity","No_Of_Dependents","Household_Size",
                         "Gender","Marital_Status")

lead_demography <- table_target

################################################## Exporting table to SQL Server ##################################################

rxSetComputeContext(sql)

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

rxDataStep(inData = lead_demography,outFile = lead_demography_table,overwrite = T)




##########################################################################################################################################
## 												Creating Market_Touchdown Table
##########################################################################################################################################

library(data.table)

## Importing lead_id,Age,Annual_Income_Bucket,Credit_Score

campaign_table <- subset(lead_demography, select = c("Lead_Id","Age","Annual_Income","Credit_Score")) 

names(campaign_table) <- c("lead_id","age","annual_income_bucket","credit_score")

Source <- c("Inbound call","SMS","Previous Campaign")

campaign_table$Source <- sample(Source,nrow(campaign_table),replace=TRUE)

##Assigning values to the various touchdown variables randomly.
## The variables created below are: 
## campaign_id, day_of_week, time_of_day, channel, comm_latency, 

campaign_table$campaign_id <- sample(1:6,nrow(campaign_table),replace = T)

campaign_table$day_of_week <- sample(1:7,nrow(campaign_table),replace = T)

tod <- c("Morning","Afternoon","Evening")
campaign_table$time_of_day <- sample(tod,nrow(campaign_table),replace = T)

ch <- c("Email","Cold Calling","SMS")
campaign_table$channel <- sample(ch, nrow(campaign_table), replace = T)

campaign_table$comm_latency <- sample(1:14, nrow(campaign_table),replace= T)

product_id  <- (1:6)
campaign_table$product_id  <- sample(product_id, nrow(campaign_table), replace = T)


######### Distributing conversion_flag across different variables

channel <- c("Email","Cold Calling","SMS")
cvalue <- c(0.04,0.035,0.025)

age <- c("Young","Middle Age","Senior Citizen")
avalue <- c(0.35,0.4,0.25)

time_of_day <- c("Morning","Afternoon","Evening")
tvalue <- c(0.31,0.36,0.33)

day_of_week <- c(1,2,3,4,5,6,7)
dvalue <- c(0.11,0.22,0.23,0.18,0.15,0.06,0.05)

annual_income_bucket <- c("<60k","60k-120k",">120k")
aivalue <- c(0.25,0.35,0.4)

product_id  <- (1:6)
pcvalue <- c(0.2,0.15,0.15,0.2,0.2,0.1)

values=cbind(expand.grid(channel,age,time_of_day,day_of_week,annual_income_bucket,product_id),expand.grid(cvalue,avalue,tvalue,dvalue,aivalue,pcvalue))
names(values)=c("channel","age","time_of_day","day_of_week","annual_income_bucket","product_id","cvalue","avalue","tvalue","dvalue","aivalue","pcvalue")

values$value <- apply(values[grepl("value",names(values))],1,prod)
values$value_final=round(nrow(campaign_table)*values$value,0)

######## Assigning the conversion_flag=1

df=data.table(values[!grepl("value",names(values))])
df1=data.table(campaign_table)
df$value_final=values$value_final

setkey(df,channel,age,time_of_day,day_of_week,annual_income_bucket,product_id)
setkey(df1,channel,age,time_of_day,day_of_week,annual_income_bucket,product_id)

df=df[df1,nomatch=0]
row.names(df) <- 1:nrow(df)

df[,cnt:=length(value_final),by=c("channel","age","time_of_day","day_of_week","annual_income_bucket","product_id")]
df$conversion_flag=0
sample=unique(data.frame(df)[,c("channel","age","time_of_day","day_of_week","annual_income_bucket","product_id","cnt","value_final")])
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

########### Creating random amount of communications to each lead from different combinations of day of week, time of day and channel

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


campaign_table_final <- subset(campaign_table_final, select = c("lead_id","channel","age","time_of_day","day_of_week",
                                                                "annual_income_bucket","product_id","credit_score",
                                                                "Source","campaign_id","comm_latency","conversion_flag",
                                                                "comm_id"))

names(campaign_table_final) <-c("Lead_Id","Channel","Age","Time_Of_Day","Day_Of_Week","Annual_Income","Product_Id",
                                "Credit_Score","Source","Campaign_Id","Comm_Latency","Conversion_Flag","Comm_Id")

market_touchdown <- campaign_table_final

################################################## Exporting table to SQL Server ##################################################

rxSetComputeContext(sql)

market_touchdown_columns <- c(
  Lead_Id = "character",
  channel = "character",
  Age = "character",
  time_of_day = "character",
  day_of_week = "numeric",
  Annual_Income_Bucket = "character",
  product_id = "numeric",
  credit_score = "character",
  Source = "character",
  campaign_id = "numeric",
  comm_latency = "numeric",
  conversion_flag = "numeric",
  comm_id = "numeric"
)

market_touchdown_table <- RxSqlServerData(table = "market_touchdown",connectionString = connection_string,colClasses = market_touchdown_columns)

rxSetComputeContext(local)

rxDataStep(inData = market_touchdown, outFile = market_touchdown_table,overwrite = T)

##########################################################################################################################################
##											Creating campaign_detail table
##########################################################################################################################################

Campaign_Name <- c(
  "Above all in service",
  "All your protection under one roof",
  "Be life full confident",
  "Together we are stronger",
  "The power to help you succeed",
  "Know Money"
)

## Creating and Assigning various Campaign variables.
## The various variables that have been assigned values are : 
## Category, launch_date, sub_category, campaign_drivers, product_family,call_for_action flag, channel and Tenure_of_Campaign. 

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

names(table_campaign) = c("Campaign_Name","Campaign_Id","Category","Launch_Date","Sub_Category","Campaign_Drivers",
                          "Product_Id","Multi_Channel","Call_For_Action","Channel_1","Channel_2","Channel_3","Focused_Geography",
                          "Tenure_Of_Campaign")

Campaign_Detail <- table_campaign
################################################## Exporting table to SQL Server ##################################################

rxSetComputeContext(sql)

Campaign_Detail_columns <- c(
  Campaign_Name = "character",
  Campaign_Id = "integer",
  Category = "character",
  Launch_Date = "character",
  Sub_Category = "character",
  Campaign_Drivers = "character",
  Product_Id = "numeric",
  Multi_Channel = "numeric",
  Call_For_Action = "character",
  Channel_1 = "character",
  Channel_2 = "character",
  Channel_3 = "character",
  Focused_Geography = "character",
  Tenure_Of_Campaign = "character"
)

Campaign_Detail_table <- RxSqlServerData(table = "Campaign_Detail",connectionString = connection_string,colClasses = Campaign_Detail_columns)

rxSetComputeContext(local)

rxDataStep(inData = Campaign_Detail, outFile = Campaign_Detail_table,overwrite = T)


##########################################################################################################################################
##													Creating Product table
##########################################################################################################################################

##Creating product ids for various Product

product_id <- c(1:6)
product <- paste("P",product_id,sep="",collapse=NULL)

table_product <- data.frame(product_id)
table_product$product <- data.frame(product)

table_product$product <- ifelse(table_product$product == "P1","Protect Your Future",
                                ifelse(table_product$product == "P2","Live Free",
                                       ifelse(table_product$product == "P3","Secured Happiness",
                                              ifelse(table_product$product == "P4","Making Tomorrow Better",
                                                     ifelse(table_product$product == "P5","Secured Life",
                                                            ifelse(table_product$product == "P6","Live Happy",
                                                                   "X"))))))

##Assigning the various categories of product for each product id.

table_product$category <- ifelse(table_product$product == "Protect Your Future","Long Term Care",
                                 ifelse(table_product$product == "Live Free","Life",
                                        ifelse(table_product$product == "Secured Happiness","Health",
                                               ifelse(table_product$product == "Making Tomorrow Better","Disability",
                                                      ifelse(table_product$product == "Secured Life","Health",
                                                             ifelse(table_product$product == "Live Happy","Life",
                                                                    "X"))))))

##Assigning various product variables such as Term, No_of_people_covered, Premium, Payment_frequency, Net_Amt_Insured, Amt_on_Maturity,

table_product$Term <- c(10,15,20,30,24,16)

table_product$No_of_people_covered <- c(4,2,1,4,2,5)

table_product$Premium <- c(1000,1500,2000,700,900,2000)

table_product$Payment_frequency <- c(rep("Monthly",3),rep("Quarterly",2),"Yearly")

table_product$Net_Amt_Insured <- c(100000,200000,150000,100000,200000,150000)

table_product$Amt_on_Maturity <- ifelse(table_product$Payment_frequency=="Monthly",12*table_product$Premium*table_product$Term*1.5,
                                        ifelse(table_product$Payment_frequency=="Quarterly",4*table_product$Premium*table_product$Term*1.5,1*table_product$Premium*table_product$Term*1.5))


table_product$Amt_on_Maturity_bin <- ifelse(table_product$Amt_on_Maturity<200000,"<200000",
                                            ifelse((table_product$Amt_on_Maturity>=200000)& (table_product$Amt_on_Maturity<250000),"200000-250000",
                                                   ifelse((table_product$Amt_on_Maturity>=250000)& (table_product$Amt_on_Maturity<300000),"250000-300000",
                                                          ifelse((table_product$Amt_on_Maturity>=300000)& (table_product$Amt_on_Maturity<350000),"300000-350000",
                                                                 ifelse((table_product$Amt_on_Maturity>=350000)& (table_product$Amt_on_Maturity<400000),"350000-400000",
                                                                        "<400000")))))


names(table_product) <- c("Product_Id","Product","Category","Term","No_Of_People_Covered","Premium","Payment_Frequency",
                          "Net_Amt_Insured","Amt_On_Maturity","Amt_On_Maturity_Bin")


################################################## Exporting table to SQL Server ##################################################

Product <- table_product

rxSetComputeContext(sql)

Product_columns <- c(
  product_id = "numeric",
  product = "character",
  category = "character",
  Term = "numeric",
  No_of_people_covered = "numeric",
  Premium = "numeric",
  Payment_frequency = "character",
  Net_Amt_Insured = "numeric",
  Amt_on_Maturity = "numeric",
  Amt_on_Maturity_bin = "character"
)


Product_table <- RxSqlServerData(table = "Product",connectionString = connection_string,colClasses = Product_columns)

rxSetComputeContext(local)

rxDataStep(inData = Product,outFile = Product_table,overwrite = T)


##############################################################  End of code  #############################################################
