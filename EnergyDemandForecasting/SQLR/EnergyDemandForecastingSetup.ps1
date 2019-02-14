<#
.SYNOPSIS
Script to train and test the energy demand forecasting template with SQL + MLS

.DESCRIPTION
This script will show the E2E work flow of customer churn machine learning
templates with Microsoft SQL 2016 or later and Microsoft ML services. 

Switch parameter ResetParmOnly allows you to reset the SQL database name.

For the detailed description, please read README.md.
#>
[CmdletBinding()]
param(
[parameter(Mandatory=$false, Position=1)]
[ValidateNotNullOrEmpty()] 
[string]$serverName,

[parameter(Mandatory=$false, Position=2)]
[ValidateNotNullOrEmpty()] 
[string]$username,

[parameter(Mandatory=$false, Position=3)]
[ValidateNotNullOrEmpty()] 
[string]$password,

[parameter(Mandatory=$false, Position=4)]
[ValidateNotNullOrEmpty()] 
[string]$Prompt
)

#function for checking whether a string exists in a file
<#function CheckStringInFile([string]$fileName, [string]$wordToFind){
	$file = Get-Content $fileName
	$containsWord = $file | %{$_ -match $wordToFind}
	If($containsWord -contains $true)
	{
		return "true"
	}
	return "false"	
}#>

#function for checking if a server, database, user exists
<#function CheckExist([string]$sqlFile, [string]$logFile, [string]$SqlServer, [string]$WindowsORSQLAuthenticationFlag, [string]$dbName, [string]$global:userName, [string]$global:passWord, [string]$wordToFind){

	
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
}#>

#function asking user to input login credentials to access the database	
<#function InputCredential ([string] $Windowsflag)
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
}#>

###Check to see if user is Admin

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
        [Security.Principal.WindowsBuiltInRole] "Administrator")

if ($isAdmin -eq 'True') {

    ##Change Values here for Different Solutions 
    $SolutionName = "EnergyDemandForecasting"
    $SolutionFullName = "SQL-Server-R-Services-Samples" 
    $Shortcut = $SolutionName+"Help.url"
    $DatabaseName = "EnergyDemandForecasting_R" 

    $Branch = "master" 
    $InstallR = 'Yes'  ## If Solution has a R Version this should be 'Yes' Else 'No'
    $InstallPy = 'No' ## If Solution has a Py Version this should be 'Yes' Else 'No'
    $SampleWeb = 'No' ## If Solution has a Sample Website  this should be 'Yes' Else 'No' 
    $EnableFileStream = 'No' ## If Solution Requires FileStream DB this should be 'Yes' Else 'No'
    $IsMixedMode = 'No' ##If solution needs mixed mode this should be 'Yes' Else 'No'
    $Prompt = 'N'

    ###These probably don't need to change , but make sure files are placed in the correct directory structure 
    $solutionTemplateName = "Solutions"
    $solutionTemplatePath = "C:\" + $SolutionFullName
    $checkoutDir = $SolutionName
    $SolutionPath = $solutionTemplatePath + '\' + $checkoutDir
    $desktop = "C:\Users\Public\Desktop\"
    $scriptPath = $SolutionPath + "\SQLR\"
    $SolutionData = $SolutionPath + "\Data\"
    $moreSolutionsURL = "https://github.com/Microsoft/ML-Server/"
    $setupLog = "c:\tmp\"+$SolutionName+"_setup_log.txt"
    $installerFunctionsFileName = "installer_functions.ps1"
    $installerFunctionsURL = "https://raw.githubusercontent.com/Microsoft/ML-Server/master/$installerFunctionsFileName"
    $installerFunctionsFile = "$PSScriptRoot\$installerFunctionsFileName"

    Write-Host -ForegroundColor 'green' ("###################################################################################################")
    Write-Host -ForeGroundColor 'green' ("This script will install ML Server sample solution $SolutionName")
    Write-Host -ForegroundColor 'green' ("###################################################################################################")

    Start-Transcript -Path $setupLog
    $startTime = Get-Date
    Write-Host ("Start time: $startTime")

    ##########################################################################
    # Including function wrapper library
    ##########################################################################
    try {
        if (Test-Path $installerFunctionsFile) {
            Remove-Item $installerFunctionsFile
        }
        Invoke-WebRequest -uri $installerFunctionsURL -OutFile $installerFunctionsFile
        .($installerFunctionsFile)
    }
    catch {
        Write-Host -ForegroundColor Red "Error while loading supporting PowerShell Scripts."
        Write-Host -ForegroundColor Red $_Exception
        EXIT
    }
    
    Write-Host -Foregroundcolor green ("Performing set up.")

    ##################################################################
    ##DSVM Does not have SQLServer Powershell Module Install or Update 
    ##################################################################
        InstallOrUpdateSQLServerPowerShellModule

    ##########################################################################
    ##Clone Data from GIT
    ##########################################################################
        CloneFromGIT -SolutionFullName $SolutionFullName, -solutionTemplatePath $solutionTemplatePath -SolutionPath $SolutionPath


    ##########################################################################
    #Install R packages if required
    ##########################################################################
        If ($InstallR -eq 'Yes') {
            Write-Host("Installing R Packages")
            Set-Location "$SolutionPath\Resources\"
            # install R Packages
            Rscript packages.R 
        }

    ##########################################################################
    #Enable FileStream if required
    ##########################################################################
        ## if FileStreamDB is Required Alter Firewall ports for 139 and 445
        If ($EnableFileStream -eq 'Yes') {
            netsh advfirewall firewall add rule name="Open Port 139" dir=in action=allow protocol=TCP localport=139
            netsh advfirewall firewall add rule name="Open Port 445" dir=in action=allow protocol=TCP localport=445
            Write-Host("Firewall as been opened for filestream access")
        }
        If ($EnableFileStream -eq 'Yes') {
            Set-Location "C:\Program Files\Microsoft\ML Server\PYTHON_SERVER\python.exe" 
            .\setup.py install
            Write-Host ("Py Install has been updated to latest version")
        }

    ############################################################################################
    #Configure SQL to Run our Solutions 
    ############################################################################################
        ##Get Server name if none was provided during setup

        if([string]::IsNullOrEmpty($serverName)) {
            $Query = "SELECT SERVERPROPERTY('ServerName')"
            $si = Invoke-Sqlcmd -Query $Query
            $si = $si.Item(0)
        }
        else {
            $si = $serverName
        }
        $serverName = $si
        Write-Host("Servername set to $serverName")


        ### Change Authentication From Windows Auth to Mixed Mode 
        if ($IsMixedMode -eq 'Yes') {
            if([string]::IsNullOrEmpty($username) -or [string]::IsNullOrEmpty($password)) {
                $Credential = $Host.ui.PromptForCredential("Need credentials", "Please supply an user name and password to configure SQL for mixed authentication.", "", "")
                $username = $credential.Username
                $password = $credential.GetNetworkCredential().password 
            }
            Write-Host("Configuring SQL to used Mixed Authentication mode")
            Invoke-Sqlcmd -Query "EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2;" -ServerInstance "LocalHost" 
            Write-Host("Creating login for user $username")
            $Query = "CREATE LOGIN $username WITH PASSWORD=N'$password', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF"
            ExecuteSQL -query $Query -dbName "master"
            Write-Host("Adding $username to [sysadmin] role")
            $Query = "ALTER SERVER ROLE [sysadmin] ADD MEMBER $username"
            ExecuteSQL -query $Query -dbName "master"
            
        }
        Write-Host("Configuring SQL to allow running of External Scripts")
        ### Allow Running of External Scripts , this is to allow R Services to Connect to SQL
        ExecuteSQL -query "EXEC sp_configure  'external scripts enabled', 1" -dbName "master"

        ### Force Change in SQL Policy on External Scripts 
        ExecuteSQL -query "RECONFIGURE WITH OVERRIDE" -dbName "master"
        Write-Host("SQL Server Configured to allow running of External Scripts")

        ### Enable FileStreamDB if Required by Solution 
        if ($EnableFileStream -eq 'Yes') {
            # Enable FILESTREAM
            $instance = "MSSQLSERVER"
            $wmi = Get-WmiObject -Namespace "ROOT\Microsoft\SqlServer\ComputerManagement14" -Class FilestreamSettings | where-object {$_.InstanceName -eq $instance}
            $wmi.EnableFilestream(3, $instance)
            Stop-Service "MSSQ*" -Force
            Start-Service "MSSQ*"
 
            Set-ExecutionPolicy Unrestricted
            #Import-Module "sqlps" -DisableNameChecking
            ExecuteSQL -query "EXEC sp_configure filestream_access_level, 2" -dbName "master"
            ExecuteSQL -query "RECONFIGURE WITH OVERRIDE" -dbName "master"
            Stop-Service "MSSQ*"
            Start-Service "MSSQ*"
        }
        else { 
            Write-Host("Restarting SQL Services")
            ### Changes Above Require Services to be cycled to take effect 
            ### Stop the SQL Service and Launchpad wild cards are used to account for named instances  
            Restart-Service -Name "MSSQ*" -Force
        }

    ##########################################################################
    # Install Power BI
    ##########################################################################
    InstallPowerBI

    ##########################################################################
    # Create Shortcuts
    ##########################################################################
        ##Create Shortcuts and Autostart Help File 
        $shortcutpath = $scriptPath+$Shortcut
        Copy-Item $shortcutpath C:\Users\Public\Desktop\
        Copy-Item $shortcutpath "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\"
        $WsShell = New-Object -ComObject WScript.Shell
        $shortcut = $WsShell.CreateShortcut($desktop + $checkoutDir + ".lnk")
        $shortcut.TargetPath = $solutionPath
        $shortcut.Save()
        Write-Host("Shortcuts made on Desktop")

    
    ##start of main script
    #initial setups
    <#
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
    #>

    ##########################################################################
    # Check if the SQL server and database exists
    ##########################################################################
        $query = "IF NOT EXISTS(SELECT * FROM sys.databases WHERE NAME = '$DatabaseName') CREATE DATABASE $DatabaseName"
        #Invoke-Sqlcmd -ServerInstance $serverName -Username $username -Password $password -Query $query -ErrorAction SilentlyContinue
        ExecuteSQL -query $query -dbName "master"
        if ($? -eq $false)
        {
            Write-Host -ForegroundColor Red "Failed the test to connect to SQL server: $serverName database: $DatabaseName !"
            Write-Host -ForegroundColor Red "Please make sure: `n`t 1. SQL Server: $serverName exists;
                                             `n`t 2. The current user has the right credential for SQL server access."
            exit
        }
        $query = "USE $DatabaseName;"
        ExecuteSQL -query $query -dbName "master"
        Write-Host("Using database $DatabaseName")

    <#
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
    #>

    ##########################################################################
    # Create database objects: tables and stored procedures
    ##########################################################################
        Write-Host -Foregroundcolor green ("creating tables and other database objects ...")

        $sqlFile1 = $scriptPath + "src\sql\MRSSqlDB_creation.sql"
        $sqlFile2 = $scriptPath + "src\sql\usp_dataSimulators.sql"
        $sqlFile3 = $scriptPath + "src\sql\usp_featureEngineering.sql"
        $sqlFile4 = $scriptPath + "src\sql\usp_trainModel.sql"
        $sqlFile5 = $scriptPath + "src\sql\usp_GenerateHistorcialData.sql"
        $sqlFile6 = $scriptPath + "src\sql\usp_persistModel.sql"
        $sqlFile7 = $scriptPath + "src\sql\usp_predictDemand.sql"
        $sqlFile8 = $scriptPath + "src\sql\usp_energyDemandForecastMain.sql"
        $sqlFile9 = $scriptPath + "src\sql\usp_create_and_delete_jobs.sql"	

        if($IsMixedMode.ToUpper() -eq "NO") {
            $WindowsAuth = "YES"
        }
        else {
            $WindowsAuth = "NO"
        }

        $varArray = "dbName=$DatabaseName","WindowsAuth=$WindowsAuth"
        ExecuteSQLScript -scriptfile $sqlFile1 -Variable $varArray
        ExecuteSQLScript -scriptfile $sqlFile2 
        ExecuteSQLScript -scriptfile $sqlFile3 
        ExecuteSQLScript -scriptfile $sqlFile4 
        ExecuteSQLScript -scriptfile $sqlFile5 
        ExecuteSQLScript -scriptfile $sqlFile6 
        ExecuteSQLScript -scriptfile $sqlFile7 
        ExecuteSQLScript -scriptfile $sqlFile8 
        ExecuteSQLScript -scriptfile $sqlFile9 

    <#if ($WindowsORSQLAuthenticationFlag -eq "YES")
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
    #>
    <#
    $wordExist1 = CheckStringInFile $logFile "Cannot drop"
    $wordExist2 = CheckStringInFile $logFile "already an object named"

    if(($wordExist1 -eq "true") -Or ($wordExist2 -eq "true"))
    {
	    write-host "Errors when create tables and other database objects, please check log file $logFile" -ForegroundColor Red
	    return
    }
    #>

        Write-Host "Successfully created tables and other objects" -ForegroundColor Green	

    ##########################################################################
    # bulk load seed data to two tables
    ##########################################################################
    
        $DBtableDemand = "$DatabaseName.dbo.DemandSeed"
        $DBtableTemperature = "$DatabaseName.dbo.TemperatureSeed"
        $demandSeedFile = $SolutionData +"DemandHistory15Minutes.txt"	
        $temperatureSeedFile = $SolutionData + "TemperatureHistoryHourly.txt"	

        Write-Host "Bulk loading seed data into tables..." -ForegroundColor Green

        ExecuteBCP("bcp $DBtableDemand IN $demandSeedFile -F2 -c -h TABLOCK -b 100000")
        ExecuteBCP("bcp $DBtableTemperature IN $temperatureSeedFile -F2 -c -h TABLOCK -b 100000")
    
    <#if ($WindowsORSQLAuthenticationFlag -eq "YES")
    {
	    bcp $DBtableDemand IN $demandSeedFile -S $SqlServer -F2 -T -c -h TABLOCK -b 100000 2>&1 3>&1 4>&1 1>>$global:logfile
	    bcp $DBtableTemperature IN $temperatureSeedFile -S $SqlServer -F2 -T -c -h TABLOCK -b 100000 2>&1 3>&1 4>&1 1>>$global:logfile
    }
    else
    {
	    bcp $DBtableDemand IN $demandSeedFile -S $SqlServer -U $userName -P $passWord -F2 -c -h TABLOCK -b 100000 2>&1 3>&1 4>&1 1>>$global:logfile
	    bcp $DBtableTemperature IN $temperatureSeedFile -S $SqlServer -U $userName -P $passWord -F2 -c -h TABLOCK -b 100000 2>&1 3>&1 4>&1 1>>$global:logfile
    }#>

        Write-Host "Successfully loaded seed data into tables" -ForegroundColor Green	

    ##########################################################################
    # call stored procedure to generate history data
    ##########################################################################
    
        Write-Host "Generating historical data from seed data ..." -ForegroundColor white	
        $sqlFile = $scriptPath + "\src\sql\MRSSqlDB_GenerateHistorialData.sql"
    
        ExecuteSQLScript -scriptfile $sqlFile

    <#$logFile = $path + "\MRSSqlDB_GenerateHistorialData.log"

    if ($WindowsORSQLAuthenticationFlag -eq "YES")
    {
	    sqlcmd.exe -S $SqlServer -E -i $sqlFile -v DBName=$dbName -o $logFile  	
    }
    else{
	    sqlcmd.exe -S $SqlServer -U $global:userName -P $global:passWord -i $sqlFile -v DBName=$dbName -o $logFile  	
    }
    #>

        Write-Host "Successfully generated historical data" -ForegroundColor Green	

    ##########################################################################
    # create SQL Server Agent jobs
    ##########################################################################
        write-host "Scheduling jobs for data simulator which will run every 15 minutes to generate Demand data and run hourly to generate Temperature data from seed data ..." -ForegroundColor white	
        $sqlFile = $scriptPath + "\src\sql\MRSSqlDB_create_job.sql"
        if(-Not $password) {
            $password = 'doesnotmatter'
        }
        
        $varArray = "ServerName=$serverName","DBName=$DatabaseName","Pswd=$password","WindowsAuth=$WindowsAuth"
        

        #sqlcmd -S jterhdsvm -E -i MRSSqlDB_create_job.sql -v DBName=EnergyDemandForecasting_R -v ServerName=jterhdsvm -v Port=1433 -v Pswd=doesnotmatter -v WindowsAuth=YES
        #ExecuteSQLScript -scriptfile $sqlFile -Variable $varArray
        Invoke-Sqlcmd -ServerInstance $serverName -Database $DatabaseName -InputFile $sqlFile -Variable $varArray
    
    ##########################################################################
    # start SQL Agent
    ##########################################################################  
    Get-Service -computer $serverName SQLSERVERAGENT | Restart-Service
    
    WriteThanksMessage

}
else {
    Write-Host ("To install this Solution you need to run Powershell as an Administrator. This program will close automatically in 20 seconds")
    Start-Sleep -s 20
    ## Close Powershell 
    Exit-PSHostProcess
    EXIT 
}