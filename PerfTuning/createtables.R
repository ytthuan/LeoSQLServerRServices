####################################################################################################
# This script can be used to create airline and airlineWithIntCol tables needed to run perf tuning tests.
####################################################################################################

# Set Database information
options(sqlConnString = "Driver=SQL Server;Server=.;Database=PerfTuning;Trusted_Connection=TRUE;")
sqlConnString <- getOption("sqlConnString") # required option

# Directory where the scripts and data are.
options(dir = "e:/perftuning")
dir <- getOption("dir")

if (!file.exists(dir))
{
	stop( "dir does not exist");
}

dataDir <- file.path(dir, "Data")
if (!file.exists(dataDir))
{
	stop( "dataDir does not exist");
}

# Indicate what tables to create
airline <- "airline" # Regular
airlineWithIntCol <- "airlineWithIntCol" # DaysOfWeek as int
airlineWithIndex <- "airlineWithIndex" # clustered id index added
airlineWithPageCompression <- "airlineWithPageCompression" # Compression Enabled
airlineWithRowCompression <- "airlineWithRowCompression"
airlineColumnar <- "airlineColumnar" # columnar table

# This script can create some tables. See .sql files to create other tables.
tables <- c(airline, airlineWithIntCol)

# Drop Tables before creating them.
# cat ("ConnString", sqlConnString, "\n")
for(tbl in tables) {
	cat("dropping existing table ", tbl, "\n")
	if (rxSqlServerTableExists(tbl, connectionString = sqlConnString))     
	{
		rxSqlServerDropTable(tbl, connectionString = sqlConnString) 
	}
}

# Data Files
airlineXdfFile <- file.path(dataDir, "airline10M.xdf" )
airlineCleanedCSVFile <- file.path(dataDir, "airline-cleanded-10M.csv" )  # used for bulk insert into columnar table using TSQL script.

# XDF Objects
airlineXdf <- RxXdfData(airlineXdfFile)
airlineCleanedCSV <- RxTextData(airlineCleanedCSVFile) # Not used in this script

# SQL Sources
rowsPerRead = 500000
airlineTable <- RxSqlServerData(table=airline, connectionString = sqlConnString, rowsPerRead = rowsPerRead, verbose =1)
airlineTableWithIntCol <- RxSqlServerData(table=airlineWithIntCol, connectionString = sqlConnString, rowsPerRead = rowsPerRead, verbose =1)

varsToKeep <- c("CRSDepTime", "CRSArrTime", "CRSElapsedTime", "ArrTime", "Month", "Year", "DayOfWeek", "DayofMonth", "Origin", "Dest", "FlightNum", "ArrDelay", "DepDelay", "DepTime")

# Create the tables
if (airline %in% tables)
{
  cat("creating table airline\n")
	rxDataStep(inData = airlineXdf, 
	           outFile = airlineTable, 
	           #varsToKeep = varsToKeep,
	           rowsPerRead = rowsPerRead,
	           overwrite=TRUE, 
	           reportProgress=1) 
}

if (airlineWithIntCol %in% tables) {
  cat("creating table airlineWithIntCol\n")
  rxDataStep(inData = airlineXdf, 
             outFile = airlineTableWithIntCol, overwrite=TRUE, 
             transforms = list( DayOfWeek = as.integer(DayOfWeek), rowNum = .rxStartRow : (.rxStartRow + .rxNumRows - 1) ),
             #varsToKeep = varsToKeep,
             rowsPerRead = rowsPerRead,
             reportProgress=1) 
}

# see sql scripts for other tables
