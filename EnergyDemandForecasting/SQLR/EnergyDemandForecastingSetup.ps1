<#
.SYNOPSIS
Script to train and test the energy demand forecasting template with SQL + MLS

.DESCRIPTION
This script will show the E2E work flow of energy demand forecasting machine learning
template with Microsoft SQL 2016 or later and Microsoft ML services. 

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
    
    WriteInstallStartMessage -SolutionName $SolutionName

    Start-Transcript -Path $setupLog
    $startTime = Get-Date
    Write-Host ("Start time: $startTime")
    
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
        ChangeAuthenticationFromWindowsToMixed -servername $servername -IsMixedMode $IsMixedMode -username $username -password $password

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
    
        Write-Host "Successfully loaded seed data into tables" -ForegroundColor Green	

    ##########################################################################
    # call stored procedure to generate history data
    ##########################################################################
    
        Write-Host "Generating historical data from seed data ..." -ForegroundColor white	
        $sqlFile = $scriptPath + "\src\sql\MRSSqlDB_GenerateHistorialData.sql"
    
        ExecuteSQLScript -scriptfile $sqlFile

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
        
        Invoke-Sqlcmd -ServerInstance $serverName -Database $DatabaseName -InputFile $sqlFile -Variable $varArray
    
    ##########################################################################
    # start SQL Agent
    ##########################################################################  
    Get-Service -computer $serverName SQLSERVERAGENT | Restart-Service
    
    WriteThanksMessage -SolutionName $SolutionName -servername $serverName -databaseName $DatabaseName -moreSolutionsURL $moreSolutionsURL

}
else {
    Write-Host ("To install this Solution you need to run Powershell as an Administrator. This program will close automatically in 20 seconds")
    Start-Sleep -s 20
    ## Close Powershell 
    Exit-PSHostProcess
    EXIT 
}