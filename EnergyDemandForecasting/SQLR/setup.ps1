[CmdletBinding()]
Param(
   [Parameter()]
   [Alias("subscriptionID")]
   [string]$global:subscriptionID
)

#function for checking whether a string exists in a file
function CheckStringInFile([string]$fileName, [string]$wordToFind){
	$file = Get-Content $fileName
	$containsWord = $file | %{$_ -match $wordToFind}
	If($containsWord -contains $true)
	{
		return "true"
	}
	return "false"	
}

#function for checking if a server, database, user exists
function CheckExist([string]$sqlFile, [string]$logFile, [string]$SqlServer, [string]$WindowsORSQLAuthenticationFlag, [string]$dbName, [string]$global:userName, [string]$global:passWord, [string]$wordToFind){

	
	if($WindowsORSQLAuthenticationFlag -eq 'Yes')
	{	
		sqlcmd.exe -S $SqlServer -E -i $sqlFile -v DBName=$dbName -o $logFile 	
	}
	else
	{
		sqlcmd.exe -S $SqlServer -U $global:userName -P $global:passWord -i $sqlFile -v DBName=$dbName -o $logFile 			
	}
	$wordExist = CheckStringInFile $logFile $wordToFind
	if($wordExist -eq "true")
	{
		return "false"
	}
	return "true"
}

#function asking user to input login credentials to access the database	
function InputCredential ([string] $Windowsflag)
{
	if ($Windowsflag -eq "NO")
	{
		$global:userName = Read-Host -Prompt 'Input Username'
		while($global:userName -eq "")
		{
			$global:userName = Read-Host -Prompt 'Input Username'
		}	
		$global:passWord = Read-Host -Prompt 'Input Password'
		while($global:passWord -eq "")
		{
			$global:passWord = Read-Host -Prompt 'Input Password'
		}
	}else
	{
		$global:userName="N/A"
		$global:passWord="N/A"
	}	
}

##start of main script
#initial setups
$storePreference = $Global:VerbosePreference
	
$Global:VerbosePreference = "SilentlyContinue"
$setupDate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
$setupDate2 = ((get-date).ToUniversalTime()).ToString("yyyyMMddHHmmss")
Write-Host "Deploy Start Date = $setupDate ..."
write-host "$PSScriptRoot"

$path = $PSScriptRoot + "\\\logs\\" + $setupDate2
if (-Not (Test-Path  ($path)))	
{	
	New-Item -ItemType directory -force -Path $path | out-null
}

$global:logFile = $path + "\\setup.log"

echo "Setup Logs" > $global:logfile
echo "Deploy Start Date = $setupDate" > $global:logfile
echo "-------------------------------------------------------" >> $global:logfile

#Ask user to input sql server and database information
$WindowsORSQLAuthenticationFlag = Read-Host "Do you want to use Windows Authentication? Yes or No (If No, SQL Server Authentication will be selected)"

while("yes","no" -notcontains $WindowsORSQLAuthenticationFlag)
{
	$WindowsORSQLAuthenticationFlag = Read-Host "Do you want to use Windows Authentication? Yes or No (If No, SQL Server Authentication will be selected)"
}
$WindowsORSQLAuthenticationFlag = $WindowsORSQLAuthenticationFlag.ToUpper()

$dbConnection="Failed"
$SqlServer = Read-Host -Prompt 'Input Sql server name'

while($SqlServer -eq "")
{
	$SqlServer = Read-Host -Prompt 'Input Sql server name'
}

$dbName = Read-Host -Prompt 'Input Database Name'
while($dbName -eq "")
{
	$dbName = Read-Host -Prompt 'Input Database Name'
}	

#Ask user to input login credential to access the database
InputCredential $WindowsORSQLAuthenticationFlag

#check to see if the server exists
write-host "Checking the server existing or not ..." -ForegroundColor White
$sqlFile = $PSScriptRoot + "\src\sql\Check_Server.sql"	
$logFile = $path + "\\check_server_exist.log"	

$serverExist1 = CheckExist $sqlFile $logFile $SqlServer $WindowsORSQLAuthenticationFlag $dbName $global:userName $global:passWord "Could not open a connection to SQL Server"

if ($WindowsORSQLAuthenticationFlag -eq "NO")
{
	$serverExist2 = CheckExist $sqlFile $logFile $SqlServer $WindowsORSQLAuthenticationFlag $dbName $global:userName $global:passWord "A connection attempt failed"
	}
else
{
	$serverExist2 = CheckExist $sqlFile $logFile $SqlServer $WindowsORSQLAuthenticationFlag $dbName $global:userName $global:passWord "The login is from an untrusted domain and cannot be used with Windows authentication"
}

while(($serverExist1 -ne "true") -Or ($serverExist2 -ne "true"))
{
	if ($WindowsORSQLAuthenticationFlag -eq "NO")
	{
		write-host "The server doest NOT exist, please make sure it exists and re-input" -ForegroundColor Red
		$SqlServer = Read-Host -Prompt 'Input Sql server name'

		$serverExist1 = CheckExist $sqlFile $logFile $SqlServer $WindowsORSQLAuthenticationFlag $dbName $global:userName $global:passWord "Could not open a connection to SQL Server"
		$serverExist2 = CheckExist $sqlFile $logFile $SqlServer $WindowsORSQLAuthenticationFlag $dbName $global:userName $global:passWord "A connection attempt failed"
	}
	else
	{
		if ($serverExist2 -ne "true")
		{
			write-host "The server could NOT take Windows Authentication , please exit and re-run by provide database credential" -ForegroundColor Red
			exit
		}
		elseif ($serverExist1 -ne "true")
		{
			write-host "The server doest NOT exist, please make sure it exists and re-input" -ForegroundColor Red
		}
		$SqlServer = Read-Host -Prompt 'Input Sql server name'
	
		$serverExist1 = CheckExist $sqlFile $logFile $SqlServer $WindowsORSQLAuthenticationFlag $dbName $global:userName $global:passWord "Could not open a connection to SQL Server"
		$serverExist2 = CheckExist $sqlFile $logFile $SqlServer $WindowsORSQLAuthenticationFlag $dbName $global:userName $global:passWord "The login is from an untrusted domain and cannot be used with Windows authentication"
	}
}	
write-host "The server exists" -ForegroundColor Green

#check to see if the database exists
write-host "Checking the database existing or not ..." -ForegroundColor White
$sqlFile = $PSScriptRoot + "\src\sql\Check_Database.sql"	
$logFile = $path + "\\check_db_exist.log"	

$loginSucceed = CheckExist $sqlFile $logFile $SqlServer $WindowsORSQLAuthenticationFlag $dbName $global:userName $global:passWord "Login failed for user"	
while($loginSucceed -ne "true")
{
	if ($WindowsORSQLAuthenticationFlag -eq "NO")
	{	
		write-host "The login to server and database failed, please make sure they are correct and re-input" -ForegroundColor Red
		$dbName = Read-Host -Prompt 'Input Database Name'
		$global:userName = Read-Host -Prompt 'Input Username'
		$global:passWord = Read-Host -Prompt 'Input Password'
		$loginSucceed = CheckExist $sqlFile $logFile $SqlServer $WindowsORSQLAuthenticationFlag $dbName $global:userName $global:passWord "Login failed for user"	
	}
	else{
		$global:userName = "N/A"
		$global:passWord = "N/A"
	}
}	

$dbExist = CheckExist $sqlFile $logFile $SqlServer $WindowsORSQLAuthenticationFlag $dbName $global:userName $global:passWord "does not exist"
if($dbExist -ne "true")
{
	$createDB = Read-Host "The database $dbName doest NOT exist, do you like it to be created automatically? Yes or No"

	while("yes","no" -notcontains $createDB)
	{
		$createDB = Read-Host "The database $dbName doest NOT exist, do you like it to be created automatically? Yes or No"
	}
}
else
{
	$createDB = "No"
	write-host "The database exists. We recommend that you have an empty database, otherwise the same tables and other same database objects for this demo will be wiped off " -ForegroundColor Yellow		
}

$createDB = $createDB.ToUpper()

if($dbExist -ne "true" -and $createDB -eq "NO")
{
	while($dbExist -ne "true")
	{
		$dbName = Read-Host -Prompt 'Input Database Name'
		if ($WindowsORSQLAuthenticationFlag -eq "YES")
		{	
			sqlcmd.exe -S $SqlServer -E -i $sqlFile -v DBName = $dbName -o $logFile  	
		}
		else{
			sqlcmd.exe -S $SqlServer -U $global:userName -P $global:passWord -i $sqlFile -v DBName = $dbName -o $logFile  	
		}
		$dbExist = CheckExist $sqlFile $logFile $SqlServer $WindowsORSQLAuthenticationFlag $dbName $global:userName $global:passWord "does not exist"
	}
}
elseif ($dbExist -ne "true" -and $createDB -eq "YES")
{
	$sqlFile = $PSScriptRoot + "\src\sql\create_database.sql"	
	$logFile = $path + "\\create_database.log"
	write-host "The database $dbName doest NOT exist, it will be created automatically" -ForegroundColor Red

	if ($WindowsORSQLAuthenticationFlag -eq "YES")
	{	
		sqlcmd.exe -S $SqlServer -E -i $sqlFile -v DBName = $dbName -o $logFile	
	}
	Else
	{
		sqlcmd.exe -S $SqlServer -U $global:userName -P $global:passWord -i $sqlFile -v DBName = $dbName -o $logFile
	}
}

#create database objects: tables and stored procedures
$logFile = $path + "\MRSSqlDB_creation.log"	

write-host "creating tables and other database objects ..." -ForegroundColor white		

$sqlFile1 = $PSScriptRoot + "\src\sql\MRSSqlDB_creation.sql"
$sqlFile2 = $PSScriptRoot + "\src\sql\usp_dataSimulators.sql"
$sqlFile3 = $PSScriptRoot + "\src\sql\usp_featureEngineering.sql"
$sqlFile4 = $PSScriptRoot + "\src\sql\usp_trainModel.sql"
$sqlFile5 = $PSScriptRoot + "\src\sql\usp_GenerateHistorcialData.sql"
$sqlFile6 = $PSScriptRoot + "\src\sql\usp_persistModel.sql"
$sqlFile7 = $PSScriptRoot + "\src\sql\usp_predictDemand.sql"
$sqlFile8 = $PSScriptRoot + "\src\sql\usp_energyDemandForecastMain.sql"
$sqlFile9 = $PSScriptRoot + "\src\sql\usp_create_and_delete_jobs.sql"	

if ($WindowsORSQLAuthenticationFlag -eq "YES")
{
	sqlcmd.exe -S $SqlServer -E -i $sqlFile1 -d $dbName -o $logFile -v WindowsAuth=$WindowsORSQLAuthenticationFlag DBName=$dbName
	sqlcmd.exe -S $SqlServer -E -i $sqlFile2 -d $dbName >> $logFile
	sqlcmd.exe -S $SqlServer -E -i $sqlFile3 -d $dbName >> $logFile 
	sqlcmd.exe -S $SqlServer -E -i $sqlFile4 -d $dbName >> $logFile 
	sqlcmd.exe -S $SqlServer -E -i $sqlFile5 -d $dbName >> $logFile 
	sqlcmd.exe -S $SqlServer -E -i $sqlFile6 -d $dbName >> $logFile 
	sqlcmd.exe -S $SqlServer -E -i $sqlFile7 -d $dbName >> $logFile 
	sqlcmd.exe -S $SqlServer -E -i $sqlFile8 -d $dbName >> $logFile 
	sqlcmd.exe -S $SqlServer -E -i $sqlFile9 -d $dbName >> $logFile    	
}
else{
	sqlcmd.exe -S $SqlServer -U $global:userName -P $global:passWord -i $sqlFile1 -d $dbName -o $logFile -v WindowsAuth=$WindowsORSQLAuthenticationFlag DBName=$dbName
	sqlcmd.exe -S $SqlServer -U $global:userName -P $global:passWord -i $sqlFile2 -d $dbName >> $logFile
	sqlcmd.exe -S $SqlServer -U $global:userName -P $global:passWord -i $sqlFile3 -d $dbName >> $logFile
	sqlcmd.exe -S $SqlServer -U $global:userName -P $global:passWord -i $sqlFile4 -d $dbName >> $logFile
	sqlcmd.exe -S $SqlServer -U $global:userName -P $global:passWord -i $sqlFile5 -d $dbName >> $logFile
	sqlcmd.exe -S $SqlServer -U $global:userName -P $global:passWord -i $sqlFile6 -d $dbName >> $logFile
	sqlcmd.exe -S $SqlServer -U $global:userName -P $global:passWord -i $sqlFile7 -d $dbName >> $logFile
	sqlcmd.exe -S $SqlServer -U $global:userName -P $global:passWord -i $sqlFile8 -d $dbName >> $logFile
	sqlcmd.exe -S $SqlServer -U $global:userName -P $global:passWord -i $sqlFile9 -d $dbName >> $logFile  	
}

$wordExist1 = CheckStringInFile $logFile "Cannot drop"
$wordExist2 = CheckStringInFile $logFile "already an object named"

if(($wordExist1 -eq "true") -Or ($wordExist2 -eq "true"))
{
	write-host "Errors when create tables and other database objects, please check log file $logFile" -ForegroundColor Red
	return
}

write-host "Successfully created tables and other objects" -ForegroundColor Green	

#bulk load seed data to two tables
$DBtableDemand = "$dbName.dbo.DemandSeed"
$DBtableTemperature = "$dbName.dbo.TemperatureSeed"
$demandSeedFile = $PSScriptRoot + "\..\data\DemandHistory15Minutes.txt"	
$temperatureSeedFile = $PSScriptRoot + "\..\data\TemperatureHistoryHourly.txt"	

write-host "Bulk loading seed data into tables..." -ForegroundColor white	
if ($WindowsORSQLAuthenticationFlag -eq "YES")
{
	bcp $DBtableDemand IN $demandSeedFile -S $SqlServer -F2 -T -c -h TABLOCK -b 100000 2>&1 3>&1 4>&1 1>>$global:logfile
	bcp $DBtableTemperature IN $temperatureSeedFile -S $SqlServer -F2 -T -c -h TABLOCK -b 100000 2>&1 3>&1 4>&1 1>>$global:logfile
}
else
{
	bcp $DBtableDemand IN $demandSeedFile -S $SqlServer -U $userName -P $passWord -F2 -c -h TABLOCK -b 100000 2>&1 3>&1 4>&1 1>>$global:logfile
	bcp $DBtableTemperature IN $temperatureSeedFile -S $SqlServer -U $userName -P $passWord -F2 -c -h TABLOCK -b 100000 2>&1 3>&1 4>&1 1>>$global:logfile
}

write-host "Successfully loaded seed data into tables" -ForegroundColor Green	

#call stored procedure to generate history data
write-host "Generating historical data from seed data ..." -ForegroundColor white	
$sqlFile = $PSScriptRoot + "\src\sql\MRSSqlDB_GenerateHistorialData.sql"
$logFile = $path + "\MRSSqlDB_GenerateHistorialData.log"

if ($WindowsORSQLAuthenticationFlag -eq "YES")
{
	sqlcmd.exe -S $SqlServer -E -i $sqlFile -v DBName=$dbName -o $logFile  	
}
else{
	sqlcmd.exe -S $SqlServer -U $global:userName -P $global:passWord -i $sqlFile -v DBName=$dbName -o $logFile  	
}

write-host "Successfully generated historical data" -ForegroundColor Green	

#create SQL Server Agent jobs
$sqlFile = $PSScriptRoot + "\src\sql\MRSSqlDB_create_job.sql"	
$logFile = $path + "\MRSSqlDB_create_job.log"	

write-host "Scheduling jobs for data simulator which will run every 15 minutes to generate Demand data and run hourly to generate Temperature data from seed data ..." -ForegroundColor white	
if($SqlServer.contains(","))
{
	$server = ($SqlServer.Split(","))[0]
	$port = ($SqlServer.Split(","))[1]
	sqlcmd.exe -S $SqlServer -U $global:userName -P $global:passWord -i $sqlFile -v Servername = $server -v Port=$port -v DBName = $dbName -v Username = $global:userName -v Pswd = $global:passWord WindowsAuth= $WindowsORSQLAuthenticationFlag -o $logFile  	

	if ($WindowsORSQLAuthenticationFlag -eq "YES")
	{
		sqlcmd.exe -S $SqlServer -E -i $sqlFile -v Servername = $server -v Port=$port -v DBName = $dbName -v Username = $global:userName -v Pswd = $global:passWord WindowsAuth= $WindowsORSQLAuthenticationFlag -o $logFile  	
	}
	else{
		sqlcmd.exe -S $SqlServer -U $global:userName -P $global:passWord -i $sqlFile -v Servername = $server -v Port=$port -v DBName = $dbName -v Username = $global:userName -v Pswd = $global:passWord WindowsAuth= $WindowsORSQLAuthenticationFlag -o $logFile  	
	}
}
else
{
	$server = $SqlServer
	$port = "NA"
	if ($WindowsORSQLAuthenticationFlag -eq "YES")
	{
		sqlcmd.exe -S $SqlServer -E -i $sqlFile -v Servername = $server -v Port=$port -v DBName = $dbName -v Username = $global:userName -v Pswd = $global:passWord -v WindowsAuth=$WindowsORSQLAuthenticationFlag -o $logFile  		
	}
	else{
		sqlcmd.exe -S $SqlServer -U $global:userName -P $global:passWord -i $sqlFile -v Servername = $server -v Port=$port -v DBName = $dbName -v Username = $global:userName -v Pswd = $global:passWord -v WindowsAuth=$WindowsORSQLAuthenticationFlag -o $logFile  	
	}
}

$setupDate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
Write-Host "Deploy Completed Date = $setupDate" -ForegroundColor Green

$Global:VerbosePreference = $storePreference






