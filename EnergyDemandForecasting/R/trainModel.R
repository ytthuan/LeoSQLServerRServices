####################################################################################################
##trainModel.R: this function trains a random regression forest model
####################################################################################################
trainModel = function(sqlSettings,input)
{
	sqlConnString = sqlSettings$connString
	
	edfFeaturesTrainSQL =  RxSqlServerData(sqlQuery = input,connectionString = sqlConnString)
	
	#create training formula
	labelVar = "Load"
	featureVars = rxGetVarNames(edfFeaturesTrainSQL)
	featureVars = featureVars[which((featureVars!=labelVar)&(featureVars!="region")&(featureVars!="utcTimestamp"))]
	formula = as.formula(paste(paste(labelVar,"~"),paste(featureVars,collapse="+")))
	
	#train regression forest model
	regForest = rxDForest(formula, data = edfFeaturesTrainSQL)	
	
	return(regForest)
	}