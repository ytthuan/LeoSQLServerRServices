<#
.SYNOPSIS
Script to trian and test thecustomer churn template with SQL + MRS

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

### DON'T FORGET TO CHANGE TO MASTER LATER...
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

$setupLog = "c:\tmp\"+$SolutionName+"_setup_log.txt"
Start-Transcript -Path $setupLog
$startTime = Get-Date
Write-Host 
("Start time: $startTime")

if ($SampleWeb -eq "Yes") 
    {
    if([string]::IsNullOrEmpty($username)) 
        {
        $Credential = $Host.ui.PromptForCredential("Need credentials", "Please supply an user name and password to configure SQL for mixed authentication.", "", "")
        $username = $credential.Username
        $password = $credential.GetNetworkCredential().password 
        }  
    }

##################################################################
##DSVM Does not have SQLServer Powershell Module Install or Update 
##################################################################
if (Get-Module -ListAvailable -Name SQLServer) 
{
Write-Host 
("Updating SQLServer Power Shell Module")    
Update-Module -Name "SQLServer" -MaximumVersion 21.0.17199
Import-Module -Name SqlServer -MaximumVersion 21.0.17199 -Force
}
Else 
{
Write-Host 
("Installing SQLServer Power Shell Module")  
Install-Module -Name SqlServer -RequiredVersion 21.0.17199 -Scope AllUsers -AllowClobber -Force
Import-Module -Name SqlServer -MaximumVersion 21.0.17199 -Force
}

##########################################################################
#Clone Data from GIT
##########################################################################
$clone = "git clone https://github.com/Microsoft/$SolutionFullName $solutionTemplatePath"
if (Test-Path $SolutionPath) { Write-Host "Solution has already been cloned"}
ELSE {Invoke-Expression $clone}


##########################################################################
#Install R packages if required
##########################################################################
If ($InstallR -eq 'Yes') {
    Write-Host 
    ("Installing R Packages")
    Set-Location "$SolutionPath\Resources\"
    # install R Packages
    Rscript packages.R 
}

##########################################################################
#Enabled FileStream if required
##########################################################################
## if FileStreamDB is Required Alter Firewall ports for 139 and 445
if ($EnableFileStream -eq 'Yes')
    {
    netsh advfirewall firewall add rule name="Open Port 139" dir=in action=allow protocol=TCP localport=139
    netsh advfirewall firewall add rule name="Open Port 445" dir=in action=allow protocol=TCP localport=445
    Write-Host 
    ("Firewall as been opened for filestream access")
    }
If ($EnableFileStream -eq 'Yes')
    {
    Set-Location "C:\Program Files\Microsoft\ML Server\PYTHON_SERVER\python.exe" 
    .\setup.py install
    Write-Host 
    ("Py Install has been updated to latest version")
    }

############################################################################################
#Configure SQL to Run our Solutions 
############################################################################################
##Get Server name if none was provided during setup

    if([string]::IsNullOrEmpty($serverName))   
    {$Query = "SELECT SERVERPROPERTY('ServerName')"
    $si = Invoke-Sqlcmd  -Query $Query
    $si = $si.Item(0)}
    else 
    {$si = $serverName}
    $serverName = $si

    Write-Host 
    ("Servername set to $serverName")


### Change Authentication From Windows Auth to Mixed Mode 
if ($IsMixedMode = 'Yes') {
    Invoke-Sqlcmd -Query "EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2;" -ServerInstance "LocalHost" 

    $Query = "CREATE LOGIN $username WITH PASSWORD=N'$password', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF"
    Invoke-Sqlcmd -Query $Query -ErrorAction SilentlyContinue

    $Query = "ALTER SERVER ROLE [sysadmin] ADD MEMBER $username"
    Invoke-Sqlcmd -Query $Query -ErrorAction SilentlyContinue
}
Write-Host 
    ("Configuring SQL to allow running of External Scripts")
### Allow Running of External Scripts , this is to allow R Services to Connect to SQL
    Invoke-Sqlcmd -Query "EXEC sp_configure  'external scripts enabled', 1"

### Force Change in SQL Policy on External Scripts 
    Invoke-Sqlcmd -Query "RECONFIGURE WITH OVERRIDE" 
    Write-Host 
    ("SQL Server Configured to allow running of External Scripts")

### Enable FileStreamDB if Required by Solution 
    if ($EnableFileStream -eq 'Yes') 
    {
# Enable FILESTREAM
        $instance = "MSSQLSERVER"
        $wmi = Get-WmiObject -Namespace "ROOT\Microsoft\SqlServer\ComputerManagement14" -Class FilestreamSettings | where-object {$_.InstanceName -eq $instance}
        $wmi.EnableFilestream(3, $instance)
        Stop-Service "MSSQ*" -Force
        Start-Service "MSSQ*"
 
        Set-ExecutionPolicy Unrestricted
        #Import-Module "sqlps" -DisableNameChecking
        Invoke-Sqlcmd "EXEC sp_configure filestream_access_level, 2"
        Invoke-Sqlcmd "RECONFIGURE WITH OVERRIDE"
        Stop-Service "MSSQ*"
        Start-Service "MSSQ*"
    }
    ELSE
    { 
    Write-Host 
    ("Restarting SQL Services")
    ### Changes Above Require Services to be cycled to take effect 
    ### Stop the SQL Service and Launchpad wild cards are used to account for named instances  
    Restart-Service -Name "MSSQ*" -Force
}

##########################################################################
# Install Power BI
##########################################################################
    Write-Host 
    ("Installing latest Power BI")
    #Download PowerBI Desktop installer
    Start-BitsTransfer -Source "https://go.microsoft.com/fwlink/?LinkId=521662&clcid=0x409" -Destination powerbi-desktop.msi
##Silently install PowerBI Desktop
    msiexec.exe /i powerbi-desktop.msi /qn /norestart  ACCEPT_EULA=1

    if (!$?) 
    {
    Write-Host -ForeGroundColor Red " Error installing Power BI Desktop. Please install latest Power BI manually."
    }


##########################################################################
# Create Shortcuts
##########################################################################
##Create Shortcuts and Autostart Help File 
Copy-Item "$SolutionPath\$Shortcut" C:\Users\Public\Desktop\
WsShell = New-Object -ComObject WScript.Shell
$shortcut = $WsShell.CreateShortcut($desktop + $checkoutDir + ".lnk")
$shortcut.TargetPath = $solutionPath
$shortcut.Save()








##########################################################################
# Script level variables
##########################################################################
$scriptPath = Get-Location
$filePath = $scriptPath.Path+ "\"
$parentPath = Split-Path -parent $scriptPath
$defaultDBName = "DefaultDBName"
##########################################################################
# Function wrapper to invoke SQL command
##########################################################################
function ExecuteSQL
{
param(
[String]
$sqlscript
)
    Invoke-Sqlcmd -ServerInstance $ServerName  -Database $DBName -Username $username -Password $password -InputFile $sqlscript -QueryTimeout 200000
}

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
    $file = $filePath + "createDBTables.sql"
    $r = "^(\s*insert.*)(values)\s+(.*)"
    $pair = "($churnPeriodVal, $churnThresholdVal)"
    # Udpate the Database name 
    $content = Get-Content $file     
    $content | Foreach-Object {
        $_ -replace $r, "`$1 `$2 $pair"
    } | Set-Content $file
}

##########################################################################
# Get the credential of SQL user
##########################################################################
Write-Host -foregroundcolor 'green' ("Please enter the credential for Database {0} of SQL server {1}" -f $DBName, $ServerName)
$username = Read-Host 'Username:'
$pwd = Read-Host 'Password:' -AsSecureString
$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwd))

##########################################################################
# Check if the SQL server exists
##########################################################################
$query = "IF NOT EXISTS(SELECT * FROM sys.databases WHERE NAME = '$DBName') CREATE DATABASE $DBName"
Invoke-Sqlcmd -ServerInstance $ServerName -Username $username -Password $password -Query $query -ErrorAction SilentlyContinue
if ($? -eq $false)
{
    Write-Host -ForegroundColor Red "Failed the test to connect to SQL server: $ServerName database: $DBName !"
    Write-Host -ForegroundColor Red "Please make sure: `n`t 1. SQL Server: $ServerName exists;
                                     `n`t 2. SQL user: $username has the right credential for SQL server access."
    exit
}

$query = "USE $DBName;"
Invoke-Sqlcmd -ServerInstance $ServerName -Username $username -Password $password -Query $query 

##########################################################################
# Update the SQL scripts
##########################################################################
SetChurnParams $ChurnPeriodVal $ChurnThresholdVal

##########################################################################
# Create tables for train data and populate the table with csv files.
##########################################################################
Write-Host -ForeGroundColor 'green' ("Step 1: Create and populate SQL tables in Database {0}" -f $DBName)
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 

if ($ans -eq 'y' -or $ans -eq 'Y')
{
    try
    {
        # create training and test tables
        Write-Host -ForeGroundColor 'green' ("Create SQL tables:")
        $script = $filePath + "createDBtables.sql"
        ExecuteSQL $script
    
        Write-Host -ForeGroundColor 'green' ("Populate SQL tables: Activities and Users")
        $dataList = "Activities", "Users"
		
		# upload csv files into SQL tables
        foreach ($dataFile in $dataList)
        {
            $destination = $parentPath + "/data/" + $dataFile + ".csv"
            Write-Host -ForeGroundColor 'magenta'("    Populate SQL table: {0}..." -f $dataFile)
            $tableName = $DBName + ".dbo." + $dataFile
            $tableSchema = $parentPath + "/data/" + $dataFile + ".xml"
            bcp $tableName format nul -c -x -f $tableSchema  -U $username -S $ServerName -P $password  -t ','
            Write-Host -ForeGroundColor 'magenta'("    Loading {0} to SQL table..." -f $dataFile)
            bcp $tableName in $destination -t ',' -S $ServerName -f $tableSchema -F 2 -C "RAW" -b 20000 -U $username -P $password 
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
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    # create and execute the stored procedure for feature engineering
    $script = $filePath + "CreateFeatures.sql"
    ExecuteSQL $script
	

    # create and execute the stored procedure for tags
    $script = $filePath + "CreateTag.sql"
    ExecuteSQL $script
}

###########################################################################
# Create and execute the stored procedures for training an open-source R 
# or Microsoft R model
###########################################################################
Write-Host -foregroundcolor 'green' ("Step 3a: Training an open-source model")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    # create and execute the stored procedure for an open-source R model
    $script = $filePath + "TrainModelR.sql"
    ExecuteSQL $script
}

Write-Host -foregroundcolor 'green' ("Step 3b: Training a Microsoft R model")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    # create and execute the stored procedure for a Microsoft R model
    $script = $filePath + "TrainModelRx.sql"
    ExecuteSQL $script
}

###########################################################################
# Create and execute the stored procedures for prediction based on 
# previously trained open-source R or Microsoft R model
###########################################################################
Write-Host -foregroundcolor 'green' ("Step 4a: Predicting based on the open-source model")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    # create and execute the stored procedure for an open-source R model
    $script = $filePath + "PredictR.sql"
    ExecuteSQL $script
}

Write-Host -foregroundcolor 'green' ("Step 4b: Predicting based on the Microsoft R model")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    # create and execute the stored procedure for a Microsoft R model
    $script = $filePath + "PredictRx.sql"
    ExecuteSQL $script
}
}
ELSE 
    {
    Write-Host ("To install this Solution you need to run Powershell as an Administrator. This program will close automatically in 20 seconds")
    Start-Sleep -s 20
    ## Close Powershell 
    Exit-PSHostProcess
    EXIT 
    }