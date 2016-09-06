
--################################################# RF Model Training ###################################################

drop table if exists model_rf

create table model_rf
(
model_no int not null identity,
model varbinary(max)
)

insert into model_rf

EXEC sp_execute_external_script @language = N'R',
                                  @script = N'
################################################# Connecting to table ###################################################

local <- RxLocalSeq()
rxSetComputeContext(local)

CM_AD_100K <- InputDataSet

AD_full <- CM_AD_100K

################################################# Checking class of the variables ###################################################
sapply(AD_full,class)

AD_full$No_Of_Dependents=factor(AD_full$No_Of_Dependents)
AD_full$Term=factor(AD_full$Term)
AD_full$No_Of_People_Covered=factor(AD_full$No_Of_People_Covered)
AD_full$Premium=factor(AD_full$Premium)
AD_full$Call_For_Action=factor(AD_full$Call_For_Action)
AD_full$Tenure_Of_Campaign=factor(AD_full$Tenure_Of_Campaign)
AD_full$Action_Day=factor(AD_full$Action_Day)
AD_full$Conversion_Flag=factor(AD_full$Conversion_Flag)

############################################################# RF #####################################################################

dependent="Conversion_Flag"

independent=names(AD_full)[!(names(AD_full) %in% c(dependent,"Lead_Id"))]

formula=reformulate(independent,dependent)

#####################################################################################################
####Variable selection using importance parameter in rxDForest
#####################################################################################################

RF_AD_Full <- rxDForest(formula = formula,data = AD_full[-match("Lead_Id",names(AD_full))],nTree = 500,mTry = 5,cp=0,importance =TRUE)

model <- data.frame(payload = as.raw(serialize(RF_AD_Full, connection=NULL)))

' 
, @input_data_1 = N'SELECT * FROM cm_AD_train'
, @output_data_1_name = N'model'
