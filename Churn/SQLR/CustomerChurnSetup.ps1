<#
.SYNOPSIS
Script to train and test thecustomer churn template with SQL + MLS

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
[string]$Prompt,

[parameter(Mandatory=$false,ParameterSetName = "Train_test")]
[Int]
$ChurnPeriodVal = 21,
[parameter(Mandatory=$false,ParameterSetName = "Train_test")]
[Int]
$ChurnThresholdVal = 0
)

###Check to see if user is Admin

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
        [Security.Principal.WindowsBuiltInRole] "Administrator")
        
if ($isAdmin -eq 'True') {

    ##Change Values here for Different Solutions 
    $SolutionName = "Churn"
    $SolutionFullName = "SQL-Server-R-Services-Samples" 
    $Shortcut = $SolutionName+"Help.url"
    $DatabaseName = "Churn_R" 

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
    
    Write-Host -ForegroundColor 'green' ("###################################################################################################")
    Write-Host -ForeGroundColor 'green' ("This script will install ML Server sample solution $SolutionName")
    Write-Host -ForegroundColor 'green' ("###################################################################################################")

    Start-Transcript -Path $setupLog
    $startTime = Get-Date
    Write-Host 
    ("Start time: $startTime")

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
        CloneFromGit -SolutionFullName $SolutionFullName -solutionTemplatePath $solutionTemplatePath -SolutionPath $SolutionPath

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

    ##########################################################################
    # Update the churning related parameters 
    ##########################################################################
    function SetChurnParams
    {
        param(
        [Int]
        $churnPeriodVal,
        [Int]
        $churnThresholdVal
        )  
            $file = $scriptPath + "createDBTables.sql"
            $r = "^(\s*insert.*)(values)\s+(.*)"
            $pair = "($churnPeriodVal, $churnThresholdVal)"
            # Udpate the Database name 
            $content = Get-Content $file     
            $content | Foreach-Object {
                $_ -replace $r, "`$1 `$2 $pair"
            } | Set-Content $file
    }

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
    # Update the SQL scripts
    ##########################################################################
    SetChurnParams $ChurnPeriodVal $ChurnThresholdVal

    ##########################################################################
    # Create tables for train data and populate the table with csv files.
    ##########################################################################
    Write-Host -ForeGroundColor 'green' ("Step 1: Create and populate SQL tables in Database {0}" -f $DatabaseName)
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
            Write-Host -ForeGroundColor 'green' ("Creating SQL tables.")
            $script = $scriptPath + "createDBtables.sql"
            
            ExecuteSQLScript $script
    
            Write-Host -ForeGroundColor 'green' ("Populate SQL tables: Activities and Users")
            $dataList = "Activities", "Users"
		
		    # upload csv files into SQL tables
            foreach ($dataFile in $dataList)
            {
                $destination = $SolutionPath + "\data\" + $dataFile + ".csv"
                Write-Host -ForeGroundColor 'magenta'("    Populate SQL table: {0}..." -f $dataFile)
                $tableName = $DatabaseName + ".dbo." + $dataFile
                $tableSchema = $SolutionPath + "\data\" + $dataFile + ".xml"
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
    # Create and execute the stored procedure for feature engineering and tags
    ##########################################################################
    Write-Host -foregroundcolor 'green' ("Step 2: Data tagging and feature engineering")
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
        # create and execute the stored procedure for feature engineering
        $script = $scriptPath + "CreateFeatures.sql"
        ExecuteSQLScript $script
	

        # create and execute the stored procedure for tags
        $script = $scriptPath + "CreateTag.sql"
        ExecuteSQLScript $script
    }
    
    ###########################################################################
    # Create and execute the stored procedures for training an open-source R 
    # or Microsoft R model
    ###########################################################################
    Write-Host -foregroundcolor 'green' ("Step 3a: Training an open-source model")
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
        # create and execute the stored procedure for an open-source R model
        $script = $scriptPath + "TrainModelR.sql"
        ExecuteSQLScript $script
    }

    Write-Host -foregroundcolor 'green' ("Step 3b: Training a Microsoft R model (Rx)")
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
        # create and execute the stored procedure for a Microsoft R model
        $script = $scriptPath + "TrainModelRx.sql"
        ExecuteSQLScript $script
    }

    ###########################################################################
    # Create and execute the stored procedures for prediction based on 
    # previously trained open-source R or Microsoft R model
    ###########################################################################
    Write-Host -foregroundcolor 'green' ("Step 4a: Predicting based on the open-source model")
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
        # create and execute the stored procedure for an open-source R model
        $script = $scriptPath + "PredictR.sql"
        ExecuteSQLScript $script
    }

    Write-Host -foregroundcolor 'green' ("Step 4b: Predicting based on the Microsoft R model (Rx)")
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
        # create and execute the stored procedure for a Microsoft R model
        $script = $scriptPath + "PredictRx.sql"
        ExecuteSQLScript $script
    }

    Write-Host("")
    Write-Host -ForegroundColor 'green' ("###################################################################################################")
    Write-Host -ForeGroundColor 'green' ("Deployment completed succesfully! Please note the following important information:")
    Write-Host -ForeGroundColor 'green' ("Solution Name: $SolutionName")
    Write-Host -ForeGroundColor 'green' ("Links to solution directory and help page are on the Desktop")
    Write-Host -ForeGroundColor 'green' ("SQL Server: $serverName")
    Write-Host -ForeGroundColor 'green' ("Database: $databaseName")
    Write-Host -ForeGroundColor 'green' ("Thanks for installing this solution. Find more solutions at: $moreSolutionsURL")
    Write-Host -ForegroundColor 'green' ("###################################################################################################")
}
else {
    Write-Host ("To install this Solution you need to run Powershell as an Administrator. This program will close automatically in 20 seconds")
    Start-Sleep -s 20
    ## Close Powershell 
    Exit-PSHostProcess
    EXIT 
}