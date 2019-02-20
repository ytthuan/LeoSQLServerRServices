<#
.SYNOPSIS
Script to train and test the retail forecasting template with SQL + MLS

.DESCRIPTION
This script will show the E2E work flow of Retail Forecasting machine learning
template with Microsoft SQL and ML services. 

For the detailed description, please read README.md.
#>



[CmdletBinding()]
param(
# SQL server address]
[parameter(Mandatory=$false,Position=1)]
[ValidateNotNullOrEmpty()] 
[String]    
$serverName = "",

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
        
if ($isAdmin -eq 'True')
{
    ##Change Values here for Different Solutions 
    $SolutionName = "RetailForecasting"
    $SolutionFullName = "SQL-Server-R-Services-Samples" 
    $Shortcut = $SolutionName+"Help.url"
    $DatabaseName = "RetailForecasting_R" 

    $Branch = "master" 
    $InstallR = 'Yes'  ## If Solution has a R Version this should be 'Yes' Else 'No'
    $InstallPy = 'No' ## If Solution has a Py Version this should be 'Yes' Else 'No'
    $SampleWeb = 'No' ## If Solution has a Sample Website  this should be 'Yes' Else 'No' 
    $EnableFileStream = 'No' ## If Solution Requires FileStream DB this should be 'Yes' Else 'No'
    $IsMixedMode = 'Yes' ##If solution needs mixed mode this should be 'Yes' Else 'No'
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

    ##########################################################################
    # Get connection string function
    ##########################################################################
    function GetConnectionString
    {
        if($IsMixedMode.ToUpper() -eq "YES") {
            $connectionString = "Driver=SQL Server;Server=$serverName;Database=$DatabaseName;UID=$username;PWD=$password"
        }
        else {
            $connectionString = "Driver=SQL Server;Server=$servername;Database=$DatabaseName;Trusted_Connection=Yes"
        }
        $connectionString
    }
    
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
        InstallRPackages -SolutionPath $SolutionPath

    ##########################################################################
    #Enabled FileStream if required
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
    # Construct the SQL connection strings
    ##########################################################################
        $connectionString = GetConnectionString

    ############################################################################
    # Create tables for times series data and populate with data from csv files.
    ############################################################################
        Write-Host -ForeGroundColor 'green' ("Step 0: Create and populate times series data in Database {0}" -f $DBName)
        if($Prompt -ne 'N') {
            #Prompt user
            $ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
            if ($ans -eq 'E' -or $ans -eq 'e')
            {
                return
            } 
        }
        else {
            #skip prompting since $Prompt -eq 'N' and set answer to 'y' to continue
            $ans = 'y'
        }
        if ($ans -eq 'y' -or $ans -eq 'Y')
        {
            try
            {
                # create training and test tables
                Write-Host -ForeGroundColor 'green' ("Create SQL tables: forecastinginput and forecasting_personal_income:")
                $script = $scriptPath + "create_table.sql"
                ExecuteSQLScript $script
    
                Write-Host -ForeGroundColor 'green' ("Populate SQL tables: PM_train, PM_test and PM_truth")
                $dataList = "forecastinginput", "forecasting_personal_income"
		
		        # upload csv files into SQL tables
                foreach ($dataFile in $dataList)
                {
                    $destination = $SolutionData + $dataFile + ".csv"
                    Write-Host -ForeGroundColor 'magenta'("    Populate SQL table: {0}..." -f $dataFile)
                    $tableName = $DatabaseName + ".dbo." + $dataFile
                    $tableSchema = $SolutionData + $dataFile + ".xml"
                    ExecuteBCP("bcp $tableName format nul -c -x -f $tableSchema -t ','")
                    Write-Host -ForeGroundColor 'magenta'("    Loading {0} to SQL table..." -f $dataFile)
                    ExecuteBCP("bcp $tableName in $destination -t ',' -f $tableSchema -F 2 -C 'RAW' -b 20000")
                    Write-Host -ForeGroundColor 'magenta'("    Done...Loading {0} to SQL table..." -f $dataFile)
                }
            }
            catch
            {
                Write-Host -ForegroundColor DarkYellow "Exception in populating train and test database tables:"
                Write-Host -ForegroundColor Red $Error[0].Exception 
                throw
            }
        }

    ##########################################################################
    # Create and execute the stored procedure for data preprocessing
    ##########################################################################
        Write-Host -ForeGroundColor 'green' ("Step 1: Data preprocessing")
        if($Prompt -ne 'N') {
            #Prompt user
            $ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
            if ($ans -eq 'E' -or $ans -eq 'e')
            {
                return
            } 
        }
        else {
            #skip prompting since $Prompt -eq 'N' and set answer to 'y' to continue
            $ans = 'y'
        }
        if ($ans -eq 'y' -or $ans -eq 'Y')
        {
            try
            {
                # create the stored procedure to preprocess the data
                Write-Host -ForeGroundColor 'magenta'("    Create SQL stored procedure for data preprocessing...")
                $script = $scriptPath + "data_preprocess.sql"
                ExecuteSQLScript $script

                # execute the data preprocessing
                Write-Host -ForeGroundColor 'magenta'("    Execute data preprocessing...")
                $testLength = 52        
                $query = "EXEC data_preprocess $testLength, '$connectionString'"
                ExecuteSQL $query        
            }
            catch
            {
                Write-Host -ForegroundColor DarkYellow "Exception in data preprocessing:"
                Write-Host -ForegroundColor Red $Error[0].Exception 
                throw
            }
        }

    ################################################################################
    # Create and execute the stored procedures for time series forecasting
    ################################################################################
        Write-Host -ForeGroundColor 'green' ("Step 2: Training/Testing: time series models")
        if($Prompt -ne 'N') {
            #Prompt user
            $ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
            if ($ans -eq 'E' -or $ans -eq 'e')
            {
                return
            } 
        }
        else {
            #skip prompting since $Prompt -eq 'N' and set answer to 'y' to continue
            $ans = 'y'
        }
        if ($ans -eq 'y' -or $ans -eq 'Y')
        {
            try
            {
                # creat the stored procedure for time series models
                Write-Host -ForeGroundColor 'magenta'("    Create and upload the stored procedures for time series models...")        
                $script = $scriptPath + "time_series_forecasting.sql"
                ExecuteSQLScript $script

                Write-Host -ForeGroundColor 'green' ("    Execute the stored procedures for time series model: ets")        
                $testLength = 52
                $modelName = "ets"
                $testtype = "test"
                $query = "EXEC time_series_forecasting $testLength, $modelName, '$connectionString', $testtype"
                ExecuteSQL $query
                Write-Host -ForeGroundColor 'green' ("    Execute the stored procedures for time series model: ets......Done!")
                Write-Host -ForeGroundColor 'green' ("    Execute the stored procedures for time series model: snaive")
                $modelName = "snaive"
                $query = "EXEC time_series_forecasting $testLength, $modelName, '$connectionString', $testtype"
                ExecuteSQL $query
                Write-Host -ForeGroundColor 'green' ("    Execute the stored procedures for time series model: snaive......Done!")
                Write-Host -ForeGroundColor 'green' ("    Execute the stored procedures for time series model: arima")
                $modelName = "arima"
                $query = "EXEC time_series_forecasting $testLength, $modelName, '$connectionString', $testtype"
                ExecuteSQL $query
                Write-Host -ForeGroundColor 'green' ("    Execute the stored procedures for time series model: arima......Done!")
                Write-Host -ForeGroundColor 'magenta'("    Time series models...Done!")
            }
            catch
            {
                Write-Host -ForegroundColor DarkYellow "Exception in time series models:"
                Write-Host -ForegroundColor Red $Error[0].Exception 
                throw
            }
        }
    
    ################################################################################
    # Create and execute the stored procedures for feature engineering
    ################################################################################
        Write-Host -ForeGroundColor 'green' ("Step 3: Feature engineering")
        if($Prompt -ne 'N') {
            #Prompt user
            $ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
            if ($ans -eq 'E' -or $ans -eq 'e')
            {
                return
            } 
        }
        else {
            #skip prompting since $Prompt -eq 'N' and set answer to 'y' to continue
            $ans = 'y'
        }
        if ($ans -eq 'y' -or $ans -eq 'Y')
        {
            try
            {
                # creat the stored procedure for binary class models
                Write-Host -ForeGroundColor 'magenta'("    Create and upload the stored procedures for feature engineering...")
                $script = $scriptPath + "feature_engineering.sql"    
                ExecuteSQLScript $script

                $script = $scriptPath + "generate_train.sql"    
                ExecuteSQLScript $script

                $script = $scriptPath + "generate_test.sql"    
                ExecuteSQLScript $script

                Write-Host -ForeGroundColor 'magenta'("    Execute the stored procedures for feature engineering...")  
                $testLength = 52             
                $query = "EXEC feature_engineering '$connectionString', $testLength"
                ExecuteSQL $query
                Write-Host -ForeGroundColor 'magenta'("    Feature engineering for regression models...Done!")

                Write-Host -ForeGroundColor 'magenta'("    Generate train dataset...")
                $numFolds = 3        
                $query = "EXEC generate_train '$connectionString', $numFolds, $testLength"
                ExecuteSQL $query
                Write-Host -ForeGroundColor 'magenta'("    Generate train dataset...Done!")

                Write-Host -ForeGroundColor 'magenta'("    Generate test dataset...")       
                $query = "EXEC generate_test '$connectionString', $testLength"
                ExecuteSQL $query
                Write-Host -ForeGroundColor 'magenta'("    Generate test dataset...Done!")

            }
            catch
            {
                Write-Host -ForegroundColor DarkYellow "Exception in feature engineeing for regression models:"
                Write-Host -ForegroundColor Red $Error[0].Exception 
                throw
            }
        }
    ##########################################################################
    # Create and execute the stored procedures for training regression models
    ##########################################################################
        Write-Host -ForeGroundColor 'green' ("Step 4: Training Regression models")
        if($Prompt -ne 'N') {
            #Prompt user
            $ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
            if ($ans -eq 'E' -or $ans -eq 'e')
            {
                return
            } 
        }
        else {
            #skip prompting since $Prompt -eq 'N' and set answer to 'y' to continue
            $ans = 'y'
        }
        if ($ans -eq 'y' -or $ans -eq 'Y')
        {
            try
            {
                # Create the stored procedure for regression models
                Write-Host -ForeGroundColor 'magenta'("    Create and upload the stored procedures for training regression models...")
                $script = $scriptPath + "train_regression_btree.sql"
                ExecuteSQLScript $script
                $script = $scriptPath + "train_regression_rf.sql"
                ExecuteSQLScript $script
                Write-Host -ForeGroundColor 'magenta'("    Create and upload the stored procedures for training regression modelss...Done!")               

                # Train the regression models and collect results and metrics
                Write-Host -ForeGroundColor 'magenta'("    Training regression model with boosted decision tree...")
                $numFolds = 3
                $query = "EXEC train_regression_btree '$connectionString', $numFolds"
                ExecuteSQL $query
                Write-Host -ForeGroundColor 'magenta'("    Training regression model with boosted decision tree...Done!")

                Write-Host -ForeGroundColor 'magenta'("    Training regression model with random forest...")
                $query = "EXEC train_regression_rf '$connectionString', $numFolds"
                ExecuteSQL $query
                Write-Host -ForeGroundColor 'magenta'("    Training regression model with random forest...Done!")
            }
            catch
            {
                Write-Host -ForegroundColor DarkYellow "Exception in training regression models:"
                Write-Host -ForegroundColor Red $Error[0].Exception 
            }
        }

    ##########################################################################
    # Create and execute the stored procedures for testing regression models
    ##########################################################################
        Write-Host -ForeGroundColor 'green' ("Step 5: Testing/evaluating Regression models")
        if($Prompt -ne 'N') {
            #Prompt user
            $ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
            if ($ans -eq 'E' -or $ans -eq 'e')
            {
                return
            } 
        }
        else {
            #skip prompting since $Prompt -eq 'N' and set answer to 'y' to continue
            $ans = 'y'
        }
        if ($ans -eq 'y' -or $ans -eq 'Y')
        {
            try
            {
                # Create the stored procedure for testing regression models
                Write-Host -ForeGroundColor 'magenta'("    Create and upload the stored procedures for testing regression models...")
                $script = $scriptPath + "test_regression_models.sql"
                ExecuteSQLScript $script
                Write-Host -ForeGroundColor 'magenta'("    Create and upload the stored procedures for testing regression models...Done!")               

                # Test and evaluate the regression models and collect results and metrics
                Write-Host -ForeGroundColor 'magenta'("    Testing and evaluating regression model...")
                $query = "EXEC test_regression_models '$connectionString'"
                ExecuteSQL $query
                Write-Host -ForeGroundColor 'magenta'("    Testing and evaluating regression model...Done!")
            }
            catch
            {
                Write-Host -ForegroundColor DarkYellow "Exception in testing and evaluating regression models:"
                Write-Host -ForegroundColor Red $Error[0].Exception 
            }   
        }
    ##########################################################################
    # Score the time series
    ##########################################################################
        Write-Host -ForeGroundColor 'green'("Step 6: Time Series Scoring...")
        try
        { 
            $testLength = 4
            $ID1 = 2
            $ID2 = 1
            # create the stored procedure to preprocess the data
            Write-Host -ForeGroundColor 'magenta'("    Create SQL stored procedure for data preprocessing...")
            $script = $scriptPath + "data_preprocess_score.sql"
            ExecuteSQLScript $script
            # execute the data preprocessing
            Write-Host -ForeGroundColor 'magenta'("    Execute data preprocessing...")                
            $query = "EXEC data_preprocess_score $testLength, $ID1, $ID2, '$connectionString'"
            ExecuteSQL $query
            $modelName = "arima"
            $testtype = "prod"
            $query = "EXEC time_series_forecasting $testLength, $modelName, '$connectionString', $testtype"  
            ExecuteSQL $query    		
            # execute the feature engineering for data to be scored
            Write-Host -ForeGroundColor 'magenta'("    Execute feature engineering for scoring with regression model...")
            $query = "EXEC feature_engineering '$connectionString', $testLength"
            ExecuteSQL $query
            Write-Host -ForeGroundColor 'magenta'("    Feature engineering for scoring with regression model...Done!")

            Write-Host -ForeGroundColor 'magenta'("    Generate train dataset...")
            $numFolds = 1        
            $query = "EXEC generate_train '$connectionString', $numFolds, $testLength"
            ExecuteSQL $query
            Write-Host -ForeGroundColor 'magenta'("    Generate train dataset...Done!")

            Write-Host -ForeGroundColor 'magenta'("    Generate test dataset...")       
            $query = "EXEC generate_test '$connectionString', $testLength"
            ExecuteSQL $query
            Write-Host -ForeGroundColor 'magenta'("    Generate test dataset...Done!")

            # Create the stored procedure for scoring regression models
            Write-Host -ForeGroundColor 'magenta'("    Create and upload the stored procedures for scoring regression models...")
            $script = $scriptPath + "score_regression_rf.sql"
            ExecuteSQLScript $script
            Write-Host -ForeGroundColor 'magenta'("    Create and upload the stored procedures for scoring regression models...Done!")               

            # Execute the scoring script
            Write-Host -ForeGroundColor 'magenta'("    Scoring regression model...")
            # The optimized parameters from the training
            $nTree = 90
            $maxDepth = 48
            $query = "EXEC score_regression_rf '$connectionString', $nTree, $maxDepth"
            ExecuteSQL $query
            Write-Host -ForeGroundColor 'magenta'("    Scoring regression model...Done!")

            Write-Host -ForeGroundColor 'green'("Scoring finished successfully!")
            return
        }
        catch
        {
            Write-Host -ForegroundColor DarkYellow "Exception in scoring maintenance data:"
            Write-Host -ForegroundColor Red $Error[0].Exception 
        }

    WriteThanksMessage -SolutionName $SolutionName -servername $serverName -databaseName $DatabaseName -moreSolutionsURL $moreSolutionsURL

}
else {
    Write-Host ("To install this Solution you need to run Powershell as an Administrator. This program will close automatically in 20 seconds")
    Start-Sleep -s 20
    ## Close Powershell 
    Exit-PSHostProcess
    EXIT 
}