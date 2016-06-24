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
[ValidateNotNullOrEmpty()]
[String]
$DBName = "",

# Switch to preventive maintenance scoring 
[parameter(Mandatory=$false,ParameterSetName = "Train_test")]
[ValidateNotNullOrEmpty()]
[Switch]
$Score
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
# Get the credential of SQL user
##########################################################################
Write-Host -foregroundcolor 'green' ("Please enter the credential for Database {0} of SQL server {1}" -f $dbname, $server)
$username = Read-Host 'Username:'
$pwd = Read-Host 'Password:' -AsSecureString
$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwd))
##########################################################################
# Online scoring 
##########################################################################
if($Score -eq $true)
{
    Write-Host -ForeGroundColor 'green'("Scoring transaction data...")
    Read-Host "Press any key to continue..."
    try
    {
        Write-Host -ForegroundColor 'Magenta'("Process the raw data...")
        $script = $filepath + "CreateScoreTable.sql"
        ExecuteSQL $script
        $dataToScore = '6C0E80FA-6988-4823-B0F5-BA49EBCBD99E,A1688852564389340,120.10945,239,BRL,"",20130401,2932,21,A,P,"","","",
                        201.8,minas gerais,30000-000,br,False,"",pt-BR,CREDITCARD,VISA,"","","",30170-000,MG,BR,"","","","","","",
                        M,"",1,0,"","","",30170-000,"",MG,BR,"",1,False,0.000694444444444444,0,0,0,"",0'

        [Collections.Generic.List[String]]$listStrs = $dataToScore.Split(",")
        $listStrs.Add($listStrs[7].PadLeft(5, '0'))
        #Dummy label value
        $listStrs.Add(1)
        $listStrs.RemoveAt(7)

        # Insert the transaction data into table
        $vals = "'" + $listStrs[0] + "'"
        for ($i = 1; $i -lt $listStrs.Count; $i++)
        {
            $vals = $vals + "," + "'" + $listStrs[$i] + "'"
        }
        $table = "sql_scoring"
        $colQuery = "SELECT * FROM $DBName.INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '$table'"
        $colLists = ExecuteSQLQuery $colQuery
        $colNames = ($colLists[0..55] | Select -ExpandProperty COLUMN_NAME) -join ","
        $query = "TRUNCATE TABLE $table;INSERT INTO $table ($colNames) VALUES ($vals);"
        ExecuteSQLQuery $query

        # Execute the Predicting on the raw data
        Write-Host -ForegroundColor 'Magenta'("Predict the transaction data...")
        $query = "EXEC PredictR '$table'"
        ExecuteSQLQuery $query

        # Get the score result
        Write-Host -ForegroundColor 'Magenta'("Retrieve the score...")
        $scoreTable = "sql_predict_score"
        $query = "SELECT * FROM $scoreTable"
        # Display the score to console
        $result = ExecuteSQLQuery $query
        $table = @()
        $obj = New-Object System.Object
        $obj | Add-Member -type NoteProperty -name AccountID -value $result.accountID
        $obj | Add-Member -type NoteProperty -Name TransactionDate -Value $result.transactionDate
        $obj | Add-Member -type NoteProperty -Name TransactionAmountUSD -Value $result.transactionAmountUSD
        $obj | Add-Member -type NoteProperty -Name Score -Value $result.Score
        $table += $obj
        $table | Format-Table –AutoSize
        Write-Host -ForegroundColor 'green'("Done...Online scoring!")
        exit
    }
    catch
    {
        Write-Host -ForegroundColor DarkYellow "Exception in scoring raw data:"
        Write-Host -ForegroundColor Red $Error[0].Exception 
        exit
    }
}

##########################################################################
# Create tables for train and test and populate with data from csv files.
##########################################################################
Write-Host -foregroundcolor 'green' ("Step 0: Create and populate untagged and fraud tables in Database" -f $dbname)
$ans = Read-Host 'Continue [y|Y], Exit [e|E]?'
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
$ans = Read-Host 'Continue [y|Y], Exit [e|E]?'
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
$ans = Read-Host 'Continue [y|Y], Exit [e|E]?'
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
$ans = Read-Host 'Continue [y|Y], Exit [e|E]?'
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
$ans = Read-Host 'Continue [y|Y], Exit [e|E]?'
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
$ans = Read-Host 'Continue [y|Y], Exit [e|E]?'
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
$ans = Read-Host 'Continue [y|Y], Exit [e|E]?'
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
    $param = $DBName + ".dbo.sql_tagged_testing"
    $query = "EXEC PredictR '$param'"
    #Write-Host $query
    ExecuteSQLQuery $query
}

##########################################################################
# Create and execute the stored procedure for Evalutation
##########################################################################

Write-Host -foregroundcolor 'green' ("Step 7: Evaluation")
$ans = Read-Host 'Continue [y|Y], Exit [e|E]?'
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
