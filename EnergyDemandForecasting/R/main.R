####################################################################################################
##main.R: this is the main R script of the Energy Demand Forecasting template
####################################################################################################

####################################################################################################
##Settings
#In order to run this script, you need to set the values of the parameters in this section to your
#own values. 
####################################################################################################

#SQL database and login credentials. Please change this part to your own values.
#If you are using Windows Authentication, "user" and "password" are not needed.
#if you are using Windows Authentication, change authenticationFlag to "Windows"
authenticationFlag = "SQL" #Valid values: "Windows" or "SQL"
servername = "[servername],[port number]"
database = "[database name]"
user = "[user name]"
password = "[password]"
	
#Set working directory. Please change this to the main directory of the template
wd = "C:\\Users\\test"

####################################################################################################	
#Source function scripts.
####################################################################################################
source(file.path(wd,"R","dataPreparation.R"))
source(file.path(wd,"R","featureEngineering.R"))
source(file.path(wd,"R","trainModel.R"))

####################################################################################################	
#Set up SQL server compute context. This part just configure the sql compute context. We are still 
#in the default local compute context.
#We will swtich to SQL compute context after loading data into SQL tables
####################################################################################################
if (authenticationFlag == "Windows")
    {sqlConnString = paste("Driver=SQL Server;Server=",servername,";Database=",database,";trusted_connection=true",sep="")
    } else if (authenticationFlag == "SQL") 
      {sqlConnString = paste("Driver=SQL Server;Server=",servername,";Database=",database,";Uid=",user,";Pwd=",password, sep="")}
	
sqlCompute = RxInSqlServer(connectionString = sqlConnString)

sqlSettings = vector("list")
sqlSettings$connString = sqlConnString 

####################################################################################################
#load data into SQL tables.
####################################################################################################
rxSetComputeContext('local')
demandTable = "demandSample"
temperatureTable = "temperatureSample"
	
demandFile= RxTextData(file.path(wd,"Data","DemandHistory15Minutes.txt"))
temperatureFile= RxTextData(file.path(wd,"Data","TemperatureHistoryHourly.txt"))
	
demandSQL = RxSqlServerData(table=demandTable, connectionString = sqlConnString)
temperatureSQL = RxSqlServerData(table=temperatureTable, connectionString = sqlConnString)

rxDataStep(inData = demandFile, outFile = demandSQL,overwrite = TRUE)
rxDataStep(inData = temperatureFile, outFile = temperatureSQL,overwrite = TRUE)

####################################################################################################
##Data preperation and feature engineering
####################################################################################################

#Switch to sql compute context. From now on, all the executions will be done in the SQL server
rxSetComputeContext(sqlCompute)
	
#Set region and time frame
region="101"
startTime="2015-01-01 00:00:00"
scoreStartTime = "2015-12-31 00:00:00"
endTime = "2015-12-31 23:45:00"
	
#SQL table names
inputTable = paste("edfData",region,sep="")
filledNATable = paste("edfNAfilled",region,sep="")
basicFeaturesTable = paste("edfBasicFeatures",region,sep="")
allFeaturesTable = paste("edfAllFeatures",region,sep="")
predictionTable = paste("edfPrediction",region,sep="")
	
#Data preparation. Join demand and temperature table, and fill NA values.
dataPreparation(sqlSettings, filledNATable,region, startTime,endTime)
	
#Feature engineering. Compute basic features and lagging features
featureEngineering(sqlSettings,filledNATable,basicFeaturesTable,allFeaturesTable)

####################################################################################################	
##Train model
####################################################################################################
trainDataQuery = paste("select * from ",allFeaturesTable," where utcTimestamp<'",scoreStartTime,"'",sep="")
model = trainModel(sqlSettings,trainDataQuery)

####################################################################################################
##Score model
####################################################################################################
scoreDataQuery = paste("select * from ",allFeaturesTable," where utcTimestamp>='",scoreStartTime,"'",sep="")
scoreDataSQL=  RxSqlServerData(sqlQuery = scoreDataQuery,connectionString = sqlConnString)
edfPredictionsSQL =  RxSqlServerData(table = predictionTable,connectionString = sqlConnString)
rxPredict(model, data=scoreDataSQL, outData =edfPredictionsSQL, extraVarsToWrite=c("utcTimestamp","Load"),overwrite=TRUE)

####################################################################################################	
##model evaluation, compute MAPE (mean absolute percent error)
####################################################################################################
MAPE_Query = paste("select avg(abs(Load_Pred - Load)/Load) as mape from ",predictionTable,sep="")
MAPESQL = RxSqlServerData(sqlQuery=MAPE_Query, connectionString = sqlConnString)
MAPE = rxImport(inData = MAPESQL)
	
print(paste("The mean absolute percent error is ",MAPE$mape, sep=""))