
--################################################# Validating RF & GBM Models ###################################################

drop table if exists model_statistics;

create table model_statistics
(
model_name varchar(20),
accuracy float,
auc float
);

DECLARE @inquery NVARCHAR(max) = N'select * from cm_AD_test ';
declare @model_rf varbinary(max) = (select model from [model_rf]);
declare @model_bt varbinary(max) = (select model from [model_gbm]);

insert into model_statistics

EXEC sp_execute_external_script @language = N'R',
                                  @script = N'

###### RF Prediction

local <- RxLocalSeq()
rxSetComputeContext(local)

Input <- InputDataSet
prediction_df <- Input

forest_model <- unserialize(forest_model)
prediction_df$probs <- rxPredict(forest_model,prediction_df, type="prob")[,2]


###### prediction

cut_off <- median(prediction_df$probs)

prediction_df$Prediction_flag = 0
prediction_df$Prediction_flag[prediction_df$probs>cut_off] = 1

agg <- aggregate(prediction_df["Conversion_Flag"],
        by =list(Conversion_Flag=prediction_df$Conversion_Flag,Prediction_flag=prediction_df$Prediction_flag),
        length)

s=0
for(i in 1:nrow(agg))
{
if(agg[,1][i] == agg[,2][i])
{
s = s + agg[,3][i] 
}
}

accuracy = (s/sum(agg[,3]))*100


library(ROCR)

pred <- prediction(prediction_df$Prediction_flag,prediction_df$Conversion_Flag)
auc = as.numeric(performance(pred,"auc")@y.values)
#auc_output <- as.data.frame(auc)

model <- c("Random Forest")
r_f = data.frame(model)
r_f$accuracy = accuracy
r_f$auc <- auc
############################################################# GBM #################################################################


###################################################################################################################################
########### Making necessary changes to datasets for running GBM as it accepts only continous and dummies.
###################################################################################################################################

prediction_df <- Input

continuous_var <- c("No_Of_Dependents","Term","No_Of_People_Covered","Premium","Tenure_Of_Campaign","Comm_Frequency","sms_count","email_count","call_count")

categorical <-  names(prediction_df[!(names(prediction_df) %in% c(continuous_var,"Lead_Id","Conversion_Flag"))])

for(i in 1:length(categorical))
{
  unq <- unique(prediction_df[,categorical[i]])
  for(j in 1:length(unq))
  {
    prediction_df[,paste(categorical[i],j,sep = "_")] = as.numeric(prediction_df[,categorical[i]] == unq[j])
  }
}

btree_model <- unserialize(btree_model)


#### prediciting

prediction_df$probs <- rxPredict(btree_model,prediction_df, type="prob")[,2]

cut_off <- median(prediction_df$probs)

prediction_df$Prediction_flag = 0
prediction_df$Prediction_flag[prediction_df$probs>cut_off] = 1

agg <- aggregate(prediction_df["Conversion_Flag"],
        by =list(Conversion_Flag=prediction_df$Conversion_Flag,Prediction_flag=prediction_df$Prediction_flag),
        length)

s=0
for(i in 1:nrow(agg))
{
if(agg[,1][i] == agg[,2][i])
{
s = s + agg[,3][i] 
}
}

accuracy = (s/sum(agg[,3]))*100


library(ROCR)

pred <- prediction(prediction_df$Prediction_flag,prediction_df$Conversion_Flag)
auc = as.numeric(performance(pred,"auc")@y.values)
#auc_output <- as.data.frame(auc)

model <- c("GBM")
gbm = data.frame(model)
gbm$accuracy = accuracy
gbm$auc <- auc

model <- rbind(r_f,gbm)

OutputDataSet <- model
'
,@input_data_1 = @inquery
,@params = N'@forest_model varbinary(max), @btree_model varbinary(max)'
,@forest_model = @model_rf
,@btree_model = @model_bt


select * 
from model_statistics