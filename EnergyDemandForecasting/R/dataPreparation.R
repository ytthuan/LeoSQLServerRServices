####################################################################################################
##dataPrepration.R: this script fills missing values in the data
####################################################################################################
dataPreparation = function(sqlSettings,outputTable,region,startTime,endTime)
{
	sqlConnString = sqlSettings$connString
	
	#drop table if already exists
	if (rxSqlServerTableExists(inputTable,connectionString=sqlConnString)) {rxSqlServerDropTable(inputTable,connectionString=sqlConnString)}
	
	#join demand table and temperature table and save results to table edfData***
	dataQuery = paste("select a.utcTimestamp as utcTimestamp, a.region as region, a.Load as Load, b.temperature as temperature from (select * from demandSample where region=",region," and utcTimeStamp>='",startTime,"' and utcTimeStamp<='",endTime,"') as a join(select utcTimestamp, region, temperature from temperatureSample where region = ",region," and utcTimestamp >='",startTime,"' and utcTimestamp <= '",endTime,"') as b on a.utcTimestamp = b.utcTimestamp order by a.utcTimestamp",sep="")
	
	#create sql server data sources
 	inputDataSQL = RxSqlServerData(sqlQuery = dataQuery, connectionString = sqlConnString)
	outputDataSQL =  RxSqlServerData(table = outputTable,connectionString = sqlConnString)
	
	#fill NA values in the data
	rxExec(fillNA,inData = inputDataSQL, outData = outputDataSQL)
	
}

fillNA = function (inData,outData)
	{	
		
		#Convert input data into data frame
		data=rxImport(inData)
		
		#Create full time series by filling in missing timestamps
		data$utcTimestamp = as.POSIXlt(data$utcTimestamp,tz="GMT", format="%Y-%m-%d %H:%M:%S")
		minTime=min(data$utcTimestamp)
		maxTime=max(data$utcTimestamp)
		resolution = difftime("2015-11-01 05:00:00 UTC", "2015-11-01 04:00:00 UTC")
		fullTime = seq(from=minTime, to=maxTime, by=resolution)
		fullTimedf = data.frame(utcTimestamp = fullTime)
		fullTimedf$utcTimestamp=as.character(fullTimedf$utcTimestamp)
		data$utcTimestamp=as.character(data$utcTimestamp)
		newdata = merge(fullTimedf, data, by.x = 'utcTimestamp',by.y = 'utcTimestamp', all=TRUE)

		# fill in missing value based on previous day same hour's Load
		for (i in 25:nrow(newdata)){
			if (is.na(newdata$Load[i])) 
			{newdata$Load[i] = newdata$Load[i-24]}
		}
		for (i in 25:nrow(newdata)){
			if (is.na(newdata$temperature[i])) 
			{newdata$temperature[i] = newdata$temperature[i-24]}
		}
 		
		#upload results to SQL table
        rxDataStep(inData = newdata, outFile = outData, overwrite = TRUE) 

	}