
--################################################# GBM Model Training ###################################################

drop table if exists model_gbm;

create table model_gbm
(
model_no int not null identity,
model varbinary(max)
)

insert into model_gbm

EXEC sp_execute_external_script @language = N'R',
                                  @script = N'	
################################################# Connecting to table ###################################################	

local <- RxLocalSeq()
rxSetComputeContext(local)

AD_train <- InputDataSet

################################################# Checking class of the variables ###################################################

AD_train$Call_For_Action=factor(AD_train$Call_For_Action)
AD_train$Tenure_Of_Campaign=factor(AD_train$Tenure_Of_Campaign)
AD_train$Action_Day=factor(AD_train$Action_Day)
AD_train$Conversion_Flag=factor(AD_train$Conversion_Flag)

################################Creating Dummy Variables###########################################################################

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

###############################GBM model###########################################################################################

dependent="Conversion_Flag"
independent = names(AD_train[!(names(AD_train) %in% c(categorical,"Lead_Id",dependent))])

AD_train$Conversion_Flag <- factor(ifelse(AD_train$Conversion_Flag==1,"yes","no"))

formula=as.formula(paste(paste(dependent,"~"), paste(independent, collapse = "+")))

#####################################################################################################
####Variable selection using importance parameter in rxBTrees
#####################################################################################################

boosted_model <- rxBTrees(formula = formula,
                          data = AD_train,
                          learningRate = 0.000005,
                          minSplit = 10,
                          minBucket = 10,
						  cp = 0.005,
                          nTree = 500,
                          seed = 5,
						  importance=TRUE,
                          lossFunction = "multinomial",
						  computeContext="RxLocalParallel")
model <- data.frame(payload = as.raw(serialize(boosted_model, connection=NULL)))'

, @input_data_1 = N'SELECT * FROM cm_AD_train'
, @output_data_1_name = N'model'
