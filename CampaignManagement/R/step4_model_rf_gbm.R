
##########################################################################################################################################
## This R script will do the following:
## 1. Two models will be trained: RF & GBM
## 2. Validate RF & GBM to choose best model based on AUC
## 3. Score data using the best model
## Input : train, test and scored dataset.
## Output: Lead Scored data to SQL Server
##########################################################################################################################################


library("RevoScaleR")
##########################################################################################################################################

## Compute context

connection_string <- "Driver=SQL Server;Server=[SQL Server Name];Database=[Database Name];UID=[User ID];PWD=[User Password]"

sql <- RxInSqlServer(connectionString = connection_string)
local <- RxLocalSeq()


##########################################################################################################################################
##													RF Model Training
##########################################################################################################################################

rxSetComputeContext(sql)


############################################################################
newclass <- c(
    No_Of_Dependents="factor",
    Term="factor",
    No_Of_People_Covered="factor",
    Premium="factor",
    Call_For_Action="factor",
    Tenure_Of_Campaign="factor",
    Action_Day="factor",
    Conversion_Flag="factor"
)
CM_AD_Train <- RxSqlServerData(table = "CM_AD_Train", stringsAsFactors = T, 
    connectionString = connection_string, colClasses = newclass
    )

############################################################# RF #####################################################################

#########################################################   RF Training   #################################################################

independent <- rxGetVarNames(CM_AD_Train)
independent <- independent[!(independent %in% c("Conversion_Flag","Lead_Id"))]

formula <- as.formula(paste("Conversion_Flag~", paste(independent, collapse = "+")))


rxSetComputeContext(sql)
RF_AD_Full <- rxDForest(formula = formula,
                        data = CM_AD_Train,
                        blocksPerRead = 10000,
                        nTree = 500, mTry = 5, cp = 0.00005, importance = TRUE)

####Variable has been reduced using importance parameter in rxBTrees  

#########################################################   RF Prediction   #################################################################

Input <- RxSqlServerData(table = "CM_AD_Test", stringsAsFactors = T,connectionString = connection_string)

prediction_df <- rxImport(inData = Input, stringsAsFactors = T,outFile = NULL)

rxSetComputeContext(local)

forest_model <- RF_AD_Full

x<- rxPredict(forest_model,prediction_df, type="prob")

prediction_df$probs <- x$X1_prob

######################################################### Accuracy calculation ##############################################################

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

####################################################### AUC #############################################################################3

library(ROCR)

pred <- prediction(prediction_df$probs,prediction_df$Conversion_Flag)
auc = as.numeric(performance(pred,"auc")@y.values)

model <- c("Random Forest")
r_f = data.frame(model)
r_f$accuracy = accuracy
r_f$auc <- auc


##########################################################################################################################################
##													GBM Model Training
##########################################################################################################################################

##################################################### Train data for GBM  #################################################################
#### Making necessary changes to train data for GBM as it accepts only continuous and dummies

continuous_var <- c("No_Of_Dependents","Term","No_Of_People_Covered","Premium","Tenure_Of_Campaign","Comm_Frequency","Sms_Count","Email_Count","Call_Count")

categorical <-  names(AD_train[!(names(AD_train) %in% c(continuous_var,"Lead_Id","Conversion_Flag"))])

for(i in 1:length(categorical))
{
  unq <- unique(AD_train[,categorical[i]])
  for(j in 1:length(unq))
  {
    AD_train[,paste(categorical[i],j,sep = "_")] = as.numeric(AD_train[,categorical[i]] == unq[j])
  }
}

#########################################################   GBM Training   #################################################################

dependent="Conversion_Flag"
independent = names(AD_train[!(names(AD_train) %in% c(categorical,"Lead_Id",dependent))])

AD_train$Conversion_Flag <- factor(ifelse(AD_train$Conversion_Flag==1,"yes","no"))

formula=as.formula(paste(paste(dependent,"~"), paste(independent, collapse = "+")))

boosted_model <- rxBTrees(formula = formula,
                          data = AD_train,
                          learningRate = 0.2,
                          minSplit = 10,
                          minBucket = 10,
                          cp = 0.005,
                          nTree = 500,
                          seed = 5,
                          importance=TRUE,
                          lossFunction = "multinomial",
                          computeContext="RxLocalParallel")
####Variable has been reduced using importance parameter in rxBTrees

##################################################### Test data for GBM  #################################################################

Input <- RxSqlServerData(table = "CM_AD_Test", stringsAsFactors = T,connectionString = connection_string)

prediction_df <- rxImport(inData = Input, stringsAsFactors = F,outFile = NULL)

#### Making necessary changes to datasets for running GBM as it accepts only continuous and dummies.
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

btree_model <- boosted_model

#########################################################   GBM Prediction   #################################################################
x <- rxPredict(btree_model,prediction_df, type="prob")

prediction_df$probs <- x$yes_prob

############################################################ Accuracy #######################################################################
cut_off <- median(prediction_df$probs)

prediction_df$Prediction_flag = 0
prediction_df$Prediction_flag[prediction_df$probs>cut_off] = 1

agg <- aggregate(prediction_df["Conversion_Flag"],
                 by =list(Conversion_Flag=prediction_df$Conversion_Flag,
                          Prediction_flag=prediction_df$Prediction_flag),length)


s=0
for(i in 1:nrow(agg))
{
  if(agg[,1][i] == agg[,2][i])
  {
    s = s + agg[,3][i] 
  }
}

accuracy = (s/sum(agg[,3]))*100

################################################################### AUC #######################################################################3
library(ROCR)

pred <- prediction(prediction_df$Prediction_flag,prediction_df$Conversion_Flag)
auc = as.numeric(performance(pred,"auc")@y.values)

model <- c("GBM")
gbm = data.frame(model)
gbm$accuracy = accuracy
gbm$auc <- auc

model_table <- rbind(r_f,gbm)


#################################################################################################

#### Scoring the Best model determined by the AUC #############################

ans <- ifelse(model_table$model[max(model_table$auc)==model_table$auc] == "Random Forest","RF","GBM")

  if(ans == "RF")
  {
  
  rxSetComputeContext(sql)
  
  CM_AD <- RxSqlServerData(table = "CM_AD", stringsAsFactors = T,connectionString = connection_string)
  
  AD_full <- rxImport(inData = CM_AD, stringsAsFactors = T,outFile = NULL)
  
  ## Creating all possible combination of Channel, Day & Time
  Action_Day=data.frame(Action_Day=unique(AD_full$Action_Day))
  Last_Channel=data.frame(Last_Channel=unique(AD_full$Last_Channel))
  Action_Time=data.frame(Action_Time=unique(AD_full$Action_Time))
  
  var_combo=merge(Action_Day,Last_Channel)
  var_combo=merge(Action_Time,var_combo)
  
  ## Finding the highest probability for every combination by target 
  
  AD_full_merged=merge(AD_full[-match(c("Action_Day","Last_Channel","Action_Time"),names(AD_full))],var_combo)
  
  AD_full_merged$Action_Time=factor(AD_full_merged$Action_Time)
  AD_full_merged$Action_Day=factor(AD_full_merged$Action_Day)
  AD_full_merged$Last_Channel=factor(AD_full_merged$Last_Channel)
  
  rxSetComputeContext(local)
  
  model <- forest_model
  
  ## Predicting from the scored dataset 
  
  x= rxPredict(model,AD_full_merged,type="prob")
  
  AD_full_merged$probability <- x$X1_prob
  
  library(data.table)
  
  AD_full_merged_1 <- data.table(AD_full_merged)
  
  probability_max = data.frame(AD_full_merged_1[,max(probability), by=c("Lead_Id")])
  
  probability_max_AD=merge(probability_max,AD_full_merged, by.x = c("Lead_Id","V1"),  by.y = c("Lead_Id","probability"),  all.x = T)
  
  colnames(probability_max_AD)[1] <- "Lead_Id"
  colnames(probability_max_AD)[2] <- "probability"
  
  ## Finding the max probability of combinations per lead
  
  probability_max_AD <- data.table(probability_max_AD[order(probability_max_AD$Lead_Id),])
  
  row_number <- sequence(data.frame(probability_max_AD[,length(Lead_Id),by=c("Lead_Id")])[,2])
  
  probability_max_AD <- probability_max_AD[which(row_number==1),]
  
  rf_output_unique <- unique(probability_max_AD)
  
  final_output <- subset(rf_output_unique, select =  c("Lead_Id","Age","Annual_Income","Credit_Score","Product","Campaign_Name","Last_Channel","Action_Day","Action_Time","probability","Conversion_Flag"))
  
  final_output$model_name <- c("RF")
  
  names(final_output) <- c("Lead_Id","Age","Annual_Income","Credit_Score","Product","Campaign_Name","Recommended_Channel","Recommended_Day_Of_Week","Recommended_Time_Of_Day","Probability","conversion_flag","Model_name")
  
  
  }

if(ans == "GBM") ##GBM

  {
  
  rxSetComputeContext(sql)
  
  CM_AD <- RxSqlServerData(table = "CM_AD", stringsAsFactors = T,connectionString = connection_string)
  
  AD_test <- rxImport(inData = CM_AD, stringsAsFactors = T,outFile = NULL)
  
  continuous_var <- c("No_Of_Dependents","Term","No_Of_People_Covered","Premium","Tenure_Of_Campaign","Comm_Frequency","sms_count","email_count","call_count")
  
  categorical <-  names(AD_test[!(names(AD_test) %in% c(continuous_var,"Lead_Id","Conversion_Flag"))])
  
  AD_test$Conversion_Flag <- factor(ifelse(AD_test$Conversion_Flag==1,"yes","no"))
  
  #### Creating dummy variables for categorical variables
  
  for(i in 1:length(categorical))
  {
    unq <- unique(AD_test[,categorical[i]])
    for(j in 1:length(unq))
    {
      AD_test[,paste(categorical[i],j,sep = "_")] = as.numeric(AD_test[,categorical[i]] == unq[j])
    }
  }
  
  #### Creating all possible combination of Channel,day & time 
  
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
  
  ################################ Finding the highest probability for every combination by target #############################################
  
  AD_test <- AD_test[-match(c("Action_Day","Action_Day_1","Action_Day_2","Action_Day_3",
                              "Last_Channel","Last_Channel_1","Last_Channel_2","Last_Channel_3",
                              "Action_Time","Action_Time_1","Action_Time_2","Action_Time_3"),names(AD_test))]
  
  AD_full_merged <- merge(AD_test,var_combo,all = T)
  
  model <- btree_model
  
  rxSetComputeContext(local)
  
  ## Finding the probability for all combinations
  
  AD_full_merged$probability = rxPredict(model,AD_full_merged,type="response")[,2]
  
  library(data.table)
  
  AD_full_merged_1 <- data.table(AD_full_merged)
  
  probability_max = data.frame(AD_full_merged_1[,max(probability), by=c("Lead_Id")])
  
  probability_max_AD=merge(probability_max,AD_full_merged, by.x = c("Lead_Id","V1"),  by.y = c("Lead_Id","probability"),  all.x = T)
  
  colnames(probability_max_AD)[1] <- "Lead_Id"
  colnames(probability_max_AD)[2] <- "probability"
  
  ## Finding the max probability of combinations per lead
  
  probability_max_AD <- data.table(probability_max_AD[order(probability_max_AD$Lead_Id),])
  
  row_number <- sequence(data.frame(probability_max_AD[,length(Lead_Id),by=c("Lead_Id")])[,2])
  
  probability_max_AD <- probability_max_AD[which(row_number==1),]
  
  rf_output_unique <- unique(probability_max_AD)
  
  final_output <- subset(rf_output_unique, select =  c("Lead_Id","Age","Annual_Income","Credit_Score","Product","Campaign_Name","Last_Channel","Action_Day","Action_Time","probability","Conversion_Flag"))
  
  final_output$model_name <- c("GBM")
  
  names(final_output) <- c("Lead_Id","Age","Annual_Income","Credit_Score","Product","Campaign_Name","Recommended_Channel","Recommended_Day_Of_Week","Recommended_Time_Of_Day","Probability","conversion_flag","Model_name")
  
  }

######### Creating lead_scored_dataset by combining lead_demography and final_output
rxSetComputeContext(sql)
l_demography <- RxSqlServerData(table = "lead_demography", stringsAsFactors = T,connectionString = connection_string) 
  
lead_demography <- rxImport(inData = l_demography, stringsAsFactors = T,outFile = NULL)
  
rxSetComputeContext(local)
  
Lead_Scored_Dataset_R <- merge(final_output, lead_demography, by.x = "Lead_Id", by.y = "Lead_Id")
  
Lead_Scored_Dataset_R <- subset(Lead_Scored_Dataset_R, select = c("Lead_Id","Age.x","Annual_Income.x","Credit_Score.x","Product","Campaign_Name","Recommended_Channel","Recommended_Day_Of_Week","Recommended_Time_Of_Day","Probability","conversion_flag","Model_name","State"))
  
names(Lead_Scored_Dataset_R) <- c("Lead ID","Age","Annual Income","Credit_Score","Product",
                                    "Campaign Name","Channel","Day of Week","Time of Day",
                                    "Conv Probability","Converts","Model_name","State")

###############################################################################################################################################  
  
##Writing data back to the Server 
  
lead_scored_dataset_columns <- c(Lead_ID = "character",
                                 Age = "character",
                                 Annual_Income = "character",
                                 Credit_Score = "character",
                                 Product =  "character",
                                 Campaign_Name =  "character",
                                 Channel =  "character",
                                 Day_of_Week =  "character",
                                 Time_of_Day =  "character",
                                 Conv_Probability =  "character",
                                 Converts =  "character",
                                 Model_name =  "character",
                                 State =  "character")


Lead_Scored_Dataset <- RxSqlServerData(table = "Lead_Scored_Dataset",connectionString = connection_string,colClasses = lead_scored_dataset_columns)

rxSetComputeContext(local)

rxDataStep(inData = Lead_Scored_Dataset_R,outFile = Lead_Scored_Dataset,overwrite = T)

