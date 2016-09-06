drop table if exists lead_list;

CREATE  TABLE lead_list
(
Lead_Id varchar(50),					
Age varchar(50),
Annual_Income varchar(50),
Credit_Score varchar(50),
Product varchar(50),
Campaign_Name varchar(50),
Recommended_Channel varchar(50),
Recommended_Day_Of_Week varchar(50),
Recommended_Time_Of_Day	varchar(50),
Probability float,
conversion_flag int,
Model_name varchar(20)
);

CREATE CLUSTERED COLUMNSTORE INDEX [lead_list_cci] ON [lead_list] WITH (DROP_EXISTING = OFF);

DECLARE @inquery NVARCHAR(max) = N'select * from CM_AD';

declare @model varbinary(max)  =
(select case when model_name = 'GBM' then (select model from model_gbm) else (select model from model_rf) end
from
(select top 1 model_name from model_statistics order by auc desc) a);

declare @best_model_name varchar(max) = (select top 1 model_name from model_statistics order by auc desc);

INSERT INTO lead_list

EXEC sp_execute_external_script @language = N'R',
                                  @script = N'

local <- RxLocalSeq()
rxSetComputeContext(local)

if(best_model == "Random Forest")
{
AD_full <- InputDataSet

Action_Day=data.frame(Action_Day=unique(AD_full$Action_Day))
Last_Channel=data.frame(Last_Channel=unique(AD_full$Last_Channel))
Action_Time=data.frame(Action_Time=unique(AD_full$Action_Time))

var_combo=merge(Action_Day,Last_Channel)
var_combo=merge(Action_Time,var_combo)

################################ Finding the highest probability for every combination by target ##############################################

AD_full_merged=merge(AD_full[-match(c("Action_Day","Last_Channel","Action_Time"),names(AD_full))],var_combo)

AD_full_merged$Action_Time=factor(AD_full_merged$Action_Time)
AD_full_merged$Action_Day=factor(AD_full_merged$Action_Day)
AD_full_merged$Last_Channel=factor(AD_full_merged$Last_Channel)

model <- unserialize(model)
AD_full_merged$probability=rxPredict(model,AD_full_merged,type="prob")[,2]

probability_max = aggregate(AD_full_merged$probability, by=list(AD_full_merged$Lead_Id), max)

probability_max_AD=merge(probability_max,AD_full_merged, by.x = c("Group.1","x"),  by.y = c("Lead_Id","probability"),  all.x = T)

colnames(probability_max_AD)[1] <- "Lead_Id"
colnames(probability_max_AD)[2] <- "probability"

library(data.table)
probability_max_AD <- data.table(probability_max_AD[order(probability_max_AD$Lead_Id),])

row_number <- sequence(data.frame(probability_max_AD[,length(Lead_Id),by=c("Lead_Id")])[,2])
probability_max_AD <- probability_max_AD[which(row_number==1),]


rf_output_unique <- unique(probability_max_AD)

final_output <- subset(rf_output_unique, select =  c("Lead_Id","Age","Annual_Income","Credit_Score","Product","Campaign_Name","Last_Channel","Action_Day","Action_Time","probability","Conversion_Flag"))
final_output$model_name <- c("RF")

}

if(best_model == "GBM")
{
AD_test <- InputDataSet

continuous_var <- c("No_Of_Dependents","Term","No_Of_People_Covered","Premium","Tenure_Of_Campaign","Comm_Frequency","sms_count","email_count","call_count")

categorical <-  names(AD_test[!(names(AD_test) %in% c(continuous_var,"Lead_Id","Conversion_Flag"))])

AD_test$Conversion_Flag <- factor(ifelse(AD_test$Conversion_Flag==1,"yes","no"))

########################################################### Creating dummy variables for categorical variables ###############

for(i in 1:length(categorical))
{
  unq <- unique(AD_test[,categorical[i]])
  for(j in 1:length(unq))
  {
  AD_test[,paste(categorical[i],j,sep = "_")] = as.numeric(AD_test[,categorical[i]] == unq[j])
  }
}

############################### Creating all possible combination of Channel,day & time ##############################################

Action_Day=data.frame(Action_Day=unique(AD_test$Action_Day))
Last_Channel=data.frame(Last_Channel=unique(AD_test$Last_Channel))
Action_Time=data.frame(Action_Time=unique(AD_test$Action_Time))

var_combo=merge(Action_Day,Last_Channel)
var_combo=merge(Action_Time,var_combo)

var_combo$Action_Time <- as.character(var_combo$Action_Time)
var_combo$Action_Day <- as.character(var_combo$Action_Day)
var_combo$Last_Channel <- as.character(var_combo$Last_Channel)

for(j in 1:3)
{  
  Unq_action_time <- unique(var_combo[,names(var_combo)[j]])
  for(i in 1:length(Unq_action_time))
  {
    var_combo[,paste(names(var_combo)[j],i,sep = "_")] = as.numeric(var_combo[,j] == Unq_action_time[i])
  }
}

var_combo <- var_combo[order(names(var_combo))]

################################ Finding the highest probability for every combination by target ##############################################

AD_test <- AD_test[-match(c("Action_Day","Action_Day_1","Action_Day_2","Action_Day_3",
                            "Last_Channel","Last_Channel_1","Last_Channel_2","Last_Channel_3",
                            "Action_Time","Action_Time_1","Action_Time_2","Action_Time_3"),names(AD_test))]

AD_full_merged <- merge(AD_test,var_combo,all = T)

model <- unserialize(model)
AD_full_merged$probability= data.frame(rxPredict(model,AD_full_merged,type="response"))[,2]

probability_max = aggregate(AD_full_merged$probability, by=list(AD_full_merged$Lead_Id), max)

probability_max_AD=merge(probability_max,AD_full_merged, by.x = c("Group.1","x"),  by.y = c("Lead_Id","probability"),  all.x = T)
colnames(probability_max_AD)[1] <- "Lead_Id"
colnames(probability_max_AD)[2] <- "probability"

library(data.table)
probability_max_AD <- data.table(probability_max_AD[order(probability_max_AD$Lead_Id),])

row_number <- sequence(data.frame(probability_max_AD[,length(Lead_Id),by=c("Lead_Id")])[,2])
probability_max_AD <- probability_max_AD[which(row_number==1),]

rf_output_unique <- unique(probability_max_AD)

final_output <- subset(rf_output_unique, select =  c("Lead_Id","Age","Annual_Income","Credit_Score","Product","Campaign_Name","Last_Channel","Action_Day","Action_Time","probability","Conversion_Flag"))
final_output$Conversion_Flag <- ifelse(final_output$Conversion_Flag == "yes",1,0)
final_output$model_name <- c("GBM")
}
OutputDataSet <- final_output
'
,@input_data_1 = @inquery
,@params = N'@model varbinary(max),@best_model varchar(50)'
,@model = @model
,@best_model = @best_model_name
;
