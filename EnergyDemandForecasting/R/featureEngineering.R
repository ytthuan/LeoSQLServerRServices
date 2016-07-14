####################################################################################################
##featureEngineering.R: this script computes features including month of year, day of week, hour of
#day, Fourier components, lags, etc.
####################################################################################################

featureEngineering = function(sqlSettings, filledNATable,basicFeaturesTable,allFeaturesTable)
{
	
	sqlConnString = sqlSettings$connString
	
	#data source: table containing results after filling NA values
	filledNASQL = RxSqlServerData(table = filledNATable,connectionString = sqlConnString)
	#data source: table containing basic features
	basicFeaturesSQL = RxSqlServerData(table = basicFeaturesTable,connectionString = sqlConnString)
	#data source: table containing all features
	allFeaturesSQL = RxSqlServerData(table = allFeaturesTable,connectionString = sqlConnString)
	
	#compute basic features
	rxDataStep(inData = filledNASQL, outFile= basicFeaturesSQL,transformFunc = computeNonLagFeatures, overwrite=TRUE)
	
	#compute lagging features
	rxExec(computeLagFeatures,inData = basicFeaturesSQL, outData = allFeaturesSQL)

}


####################################################################################################
#function computing non-lag features
####################################################################################################
computeNonLagFeatures = function(data) {	
	data$hourofday = (as.POSIXlt(data$utcTimestamp,tz="GMT", format="%Y-%m-%d %H:%M:%S"))$hour
    data$dayofweek = (as.POSIXlt(data$utcTimestamp,tz="GMT", format="%Y-%m-%d %H:%M:%S"))$wday
    data$monofyear = (as.POSIXlt(data$utcTimestamp,tz="GMT", format="%Y-%m-%d %H:%M:%S"))$mon+1
    data$weekend = data$dayofweek==6 | data$dayofweek==0
    data$businesstime = data$hourofday>=8 & data$hourofday<=18
    data$ismorning = data$hourofday>=5 & data$hourofday<=8
    data$LinearTrend=floor(((1:length(data$utcTimestamp))-1)/24)/365.25
	t = floor(((1:length(data$utcTimestamp))-1)/24)
	for (s in 1:2){
		data[[paste("WKFreqCos", toString(s), sep="")]] = cos(t*2*pi*s/365.25)*data$weekend
		data[[paste("WKFreqSin", toString(s), sep="")]] = sin(t*2*pi*s/365.25)*data$weekend
    
		data[[paste("WDFreqCos", toString(s), sep="")]] = cos(t*2*pi*s/365.25)*(1-data$weekend)
		data[[paste("WDFreqSin", toString(s), sep="")]] = sin(t*2*pi*s/365.25)*(1-data$weekend)
	}
	return(data)	
}

####################################################################################################
#function computing lagging features
####################################################################################################
computeLagFeatures = function(inData,outData) {
	shift = function(lag, x){c(rep(NA, lag), head(x,-lag))}
	shift = Vectorize(shift, vectorize.args = "lag")

	addlags = function(lags, df, var){
	res = shift(lags, x=df[,var])
	colnames(res) = paste("lag", lags, sep = "")
	return(cbind(df,res))
	}

	data = rxImport(inData)
	nlags = c(24,25,26,27,28,31,36,40,48,72,96)
	
	data = addlags(nlags, data, var = "Load")
	
	#upload results to SQL table
	rxDataStep(inData = data, outFile = outData, overwrite = TRUE) 
}