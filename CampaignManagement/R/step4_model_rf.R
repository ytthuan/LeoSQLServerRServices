
##########################################################################################################################################
## This R script Modified to use SQL context, and stops after training the RF model.
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
system.time(
    RF_AD_Full <- rxDForest(formula = formula,
                        data = CM_AD_Train,
                        blocksPerRead = 10000,
                        nTree = 75, mTry = 5, cp = 0.00005, importance = TRUE)
)

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

