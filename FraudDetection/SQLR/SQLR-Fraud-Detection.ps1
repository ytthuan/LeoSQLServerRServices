<#
.SYNOPSIS
Script to trian and test the fraud detection template with SQL + MRS

.DESCRIPTION
This script will show the E2E work flow of fraud detection machine learning
templates with Microsoft SQL 2016 and Microsoft R services. 

Switch parameter SetParmOnly allows you to reset the SQL database name.

For the detailed description, please read README.md.
#>
[CmdletBinding()]
param(
# SQL server address
[parameter(Mandatory=$true,ParameterSetName = "Train_test")]
[ValidateNotNullOrEmpty()] 
[String]    
$ServerName = "",

# SQL server database name
[parameter(Mandatory=$true,ParameterSetName = "Train_test")]
[parameter(Mandatory=$true,ParameterSetName = "SetParam")]
[ValidateNotNullOrEmpty()]
[String]
$DBName = "",

# Switch to preventive maintenance scoring 
[parameter(Mandatory=$true,ParameterSetName = "SetParam")]
[ValidateNotNullOrEmpty()]
[Switch]
$SetParamOnly
)

##########################################################################
# Script level variables
##########################################################################
$scriptPath = Get-Location
$filePath = $scriptPath.Path+ "\"
$parentPath = Split-Path -parent $scriptPath
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
# Function wrapper to invoke SQL query
##########################################################################
function ExecuteSQLQuery
{
param(
[String]
$sqlquery
)
    Invoke-Sqlcmd -ServerInstance $ServerName  -Database $DBName -Username $username -Password $password -Query $sqlquery -QueryTimeout 200000
}
##########################################################################
# Update the SQL database name which will be used for workflow
##########################################################################
function SetParamValue
{
param(
[String]
$targetDbname
)
    # Get the current parameter values
    $rUse = [regex]"\s*use\s+\[(.*)\]$"
    $file = $filePath + "Step0_CreateTables.sql" 
    $content = Get-Content $file
    $matches = $rUse.Matches($content[0])
        
    if ($matches.Count -eq 0)
    {
        Write-Host -foregroundcolor 'red' ("Please check the file $file starts with use [DatabaseName]")
        return  
    }
  
    $currentDbname = $matches.Groups[1].Value

    $files = $filePath + "*.sql"
    $listfiles = Get-ChildItem $files -Recurse

    # Udpate the SQL related parameters in each SQL script file
    foreach ($file in $listfiles)
    {        
        (Get-Content $file) | Foreach-Object {
            $_ -replace $currentDbname, $targetDbname
        } | Set-Content $file
    }
}

##########################################################################
# Set the SQL Database name
##########################################################################
if($SetParamOnly -eq $true)
{
    Write-Host -ForeGroundColor 'green'("Set the SQL Database name...")
    Read-Host "Press any key to continue..."
    SetParamValue $DBName
    exit
}

##########################################################################
# Get the credential of SQL user
##########################################################################
Write-Host -foregroundcolor 'green' ("Please enter the credential for Database {0} of SQL server {1}" -f $dbname, $server)
$username = Read-Host 'Username:'
$pwd = Read-Host 'Password:' -AsSecureString
$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwd))
##########################################################################
# Update the SQL scripts
##########################################################################
Write-Host -foregroundcolor 'green' ("Using SQL DB: {0} and User: {1}?" -f $DBName, $username)
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'

if ($ans -eq 'y' -or $ans -eq 'Y')
{
    Write-Host -ForeGroundColor 'green' ("Update SQL related parameters in all SQL scripts...")
    SetParamValue $DBName
    Write-Host -ForeGroundColor 'green' ("Done...Update SQL related parameters in all SQL scripts")
}

##########################################################################
# Create tables for train and test and populate with data from csv files.
##########################################################################
Write-Host -foregroundcolor 'green' ("Step 0: Create and populate untagged and fraud tables in Database" -f $dbname)
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    $untagged_data = $parentPath + "/data/" + "Online Fraud- Untagged Transactions.csv" 
    $fraud_data = $parentPath + "/data/" + "Online Fraud- Fraud Transactions.csv" 
    $untagged_tbname = "untaggedData"
    $untagged_tbname_schema = $parentPath + "/data/" + "untaggedData_schema.xml"
    $fraud_tbname = "fraud"
    $fraud_tbname_schema = $parentPath + "/data/" + "fraud_schema.xml"
    # create untagged and fraud tables
    $script = $filepath + "Step0_CreateTables.sql"
    ExecuteSQL $script

    # upload untagged data to untagged table
    $untagged_db_tb = $DBName + ".dbo." + $untagged_tbname
    bcp $untagged_db_tb format nul -c -x -f $untagged_tbname_schema  -U $username -S $ServerName -P $password -t ','
    bcp $untagged_db_tb in $untagged_data -f $untagged_tbname_schema -t "," -S $ServerName -U $username -P  $password -F 2 -C "RAW" -b 200000

    # upload fraud data to fraud table 
    $fraud_db_tb = $dbname + ".dbo." + $fraud_tbname
    bcp $fraud_db_tb format nul -c -x -f $fraud_tbname_schema  -U $username -S $ServerName -P $password -t ','
    bcp $fraud_db_tb in $fraud_data -f $fraud_tbname_schema -t "," -S $ServerName -U $username -P  $password -F 2 -C "RAW" -b 8640
}

##########################################################################
# Create and execute the stored procedure for tagging
##########################################################################
Write-Host -foregroundcolor 'green' ("Step 1: Tagging on account level")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    # create the stored procedure for tagging
    $script = $filepath + "Step1_Tagging.sql"
    ExecuteSQL $script

    # execute the tagging
    $query = "EXEC Tagging"
    ExecuteSQLQuery $query
}

##########################################################################
# Create and execute the stored procedure for preprocessing
##########################################################################

Write-Host -foregroundcolor 'green' ("Step 2: Preprocess the data")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    # create the ultility procedure
    $script = $filepath + "FillMissing.sql"
    ExecuteSQL $script

    # create the stored procedure for Preprocess
    $script = $filepath + "Step2_Preprocess.sql"
    ExecuteSQL $script

    # execute the Preprocess
    $query = "EXEC Preprocess"
    ExecuteSQLQuery $query
}

##########################################################################
# Create and execute the stored procedure for creating risk tables
##########################################################################

Write-Host -foregroundcolor 'green' ("Step 3: Create risk tables")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    # create the ultility procedure
    $script = $filepath + "CreateRiskTable.sql"
    ExecuteSQL $script

    # create stored procedure for generating all risk tables
    $script = $filepath + "Step3_CreateRiskTables.sql"
    ExecuteSQL $script

    # execute the procedure
    $query = "EXEC CreateRiskTable_ForAll"
    ExecuteSQLQuery $query
}

##########################################################################
# Create the stored procedure for feature engineering for training
##########################################################################

Write-Host -foregroundcolor 'green' ("Step 4: Feature engineering for training")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    # create the ultility procedures
    $script = $filepath + "AssignRisk.sql"
    ExecuteSQL $script
    $script = $filepath + "FillNA.sql"
    ExecuteSQL $script
    $script = $filepath + "FeatureEngineer.sql"
    ExecuteSQL $script

    # create the stored procedure for FeatureEngineering for training
    $script = $filepath + "Step4_FeatureEngineerForTraining.sql"
    ExecuteSQL $script

    # execute the FeatureEngineering for training
    $query = "EXEC FeatureEngineer_ForTraining"
    ExecuteSQLQuery $query
}

##########################################################################
# Create and execute the stored procedure for Training
##########################################################################

Write-Host -foregroundcolor 'green' ("Step 5: Model training")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    # create the stored procedure for Training
    $script = $filepath + "Step5_Training.sql"
    ExecuteSQL $script

    # execute the Training
    $query = "EXEC TrainModelR"
    ExecuteSQLQuery $query
}

##########################################################################
# Create and execute the stored procedure for Predicting
##########################################################################

Write-Host -foregroundcolor 'green' ("Step 6: Scoring on test set")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    # create the stored procedure for Predicting
    $script = $filepath + "Step6_Prediction.sql"
    ExecuteSQL $script

    # execute the Predicting
    $param = "select * from " + $DBName + ".dbo.sql_tagged_testing"
    $query = "EXEC PredictR '$param'"
    #Write-Host $query
    ExecuteSQLQuery $query
}

##########################################################################
# Create and execute the stored procedure for Evalutation
##########################################################################

Write-Host -foregroundcolor 'green' ("Step 7: Evaluation")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 
if ($ans -eq 'y' -or $ans -eq 'Y')
{
    # create the stored procedure for Evaluation
    $script = $filepath + "Step7_Evaluation.sql"
    ExecuteSQL $script
    $script = $filepath + "Step7_Evaluation_AUC.sql"
    ExecuteSQL $script

    # execute the Evaluation
    $query = "EXEC EvaluateR"
    ExecuteSQLQuery $query
    $query = "EXEC EvaluateR_auc"
    ExecuteSQLQuery $query
}

Write-Host -foregroundcolor 'green'("Workflow finished successfully!")
