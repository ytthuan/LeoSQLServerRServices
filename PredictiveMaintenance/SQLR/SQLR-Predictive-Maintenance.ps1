<#
.SYNOPSIS
Script to trian and test the preventive maintenance template with SQL + MRS

.DESCRIPTION
This script will show the E2E work flow of Preventive Maintenance machine learning
templates with Microsoft SQL 2016 and Microsoft R services. 

Switch parameter Score allows you to score the production data with seleted model
Switch parameter ResetParmOnly allows you to reset the SQL related credentials

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
# Get connection string
##########################################################################
function GetConnectionString
{
    $connectionString = "Driver=SQL Server;Server=$ServerName;Database=$DBName;UID=$username;PWD=$password"
    $connectionString
}

##########################################################################
# Get the credential of SQL user
##########################################################################
Write-Host -foregroundcolor 'green' ("Please enter the credential for Database {0} of SQL server {1}" -f $DBName, $ServerName)
$username = Read-Host 'Username:'
$pwd = Read-Host 'Password:' -AsSecureString
$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwd))

##########################################################################
# Construct the SQL connection strings
##########################################################################
$connectionString = GetConnectionString

##########################################################################
# Check the SQL server or database exists
##########################################################################
Invoke-Sqlcmd -ServerInstance $ServerName -Username $username -Password $password -Query "use $DBName" -ErrorAction SilentlyContinue
if ($? -eq $false)
{
    Write-Host -ForegroundColor Red "Failed the test to connect to SQL server: $ServerName database: $DBName !"
    Write-Host -ForegroundColor Red "Plese make sure: `n`t 1. SQL Server: $ServerName exists;
                                     `n`t 2. SQL database: $DBName exists;
                                     `n`t 3. SQL user: $username has the right credential for SQL server access."
    exit
}

##########################################################################
# Score the maintenance data which is in SQL table PM_score
##########################################################################
if($score -eq $true)
{
    Write-Host -ForeGroundColor 'green'("Scoring maintenance data...")
    Read-Host "Press any key to continue..."
    try
    {
		# create score table
        Write-Host -ForeGroundColor 'green' ("Create SQL tables: PM_Score:")
        $script = $filePath + "DataProcessing\create_table_score.sql"
        ExecuteSQL $script
    
        # upload data to be scored to SQL table
        Write-Host -ForeGroundColor 'green' ("Populate SQL tables: PM_Score")
        $dataFile = "PM_Score"
        $destination = $parentPath + "/data/" + $dataFile + ".csv"
        Write-Host -ForeGroundColor 'magenta'("    Populate SQL table: {0}..." -f $dataFile)
        $tableName = $DBName + ".dbo." + $dataFile
        $tableSchema = $parentPath + "/data/" + $dataFile + ".xml"
        bcp $tableName format nul -c -x -f $tableSchema  -U $username -S $ServerName -P $password  -t ','
        Write-Host -ForeGroundColor 'magenta'("    Loading {0} to SQL table..." -f $dataFile)
        bcp $tableName in $destination -t ',' -S $ServerName -f $tableSchema -F 1 -C "RAW" -b 20000 -U $username -P $password
		
        # execute the feature engineering for data to be scored
        Write-Host -ForeGroundColor 'magenta'("    Execute feature engineering for score dataset...")
		Read-Host "Press any key to continue..."
        #$script = $filePath + "FeatureEngineering/execute_feature_engineering_scoring.sql"
        $datasetType = 'score'
        $query = "EXEC feature_engineering $datasetType, '$connectionString'"
        ExecuteSQLQuery $query

        # score the regression model and collect results
        Write-Host -ForeGroundColor 'magenta'("    Create and execute scoring with selected regression model...")
		Read-Host "Press any key to continue..."
        $script = $filePath + "Regression/score_regression_model.sql"
        ExecuteSQL $script
        #$script = $filePath + "Regression/execute_score_reg_model.sql"
        $model = 'regression_btree'
        $query = "EXEC score_regression_model $model, '$connectionString'"
        ExecuteSQLQuery $query

        # score the binary classification model and collect results
        Write-Host -ForeGroundColor 'magenta'("    Create and execute scoring with selected binary classification model...")
		Read-Host "Press any key to continue..."
        $script = $filePath + "BinaryClassification/score_binaryclass_model.sql"
        ExecuteSQL $script
        #$script = $filePath + "BinaryClassification/execute_score_bclass_model.sql"
        $model = 'binaryclass_btree'
        $query = "EXEC score_binaryclass_model $model, '$connectionString'"
        ExecuteSQLQuery $query

        # score the multi-class classification model and collect results
        Write-Host -ForeGroundColor 'magenta'("    Create and execute scoring with selected multi-class classification model...")
		Read-Host "Press any key to continue..."
        $script = $filePath + "MultiClassification/score_multiclass_model.sql"
        ExecuteSQL $script
        #$script = $filePath + "MultiClassification/execute_score_mclass_model.sql"
        $model = 'multiclass_btree'
        $query = "EXEC score_multiclass_model $model, '$connectionString'"
        ExecuteSQLQuery $query

        Write-Host -ForeGroundColor 'green'("Scoring finished successfully!")
        return
    }
    catch
    {
        Write-Host -ForegroundColor DarkYellow "Exception in scoring maintenance data:"
        Write-Host -ForegroundColor Red $Error[0].Exception 
    }
}
##########################################################################
# Create tables for train and test and populate with data from csv files.
##########################################################################
Write-Host -ForeGroundColor 'green' ("Step 1: Create and populate train and test tables in Database {0}" -f $DBName)
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
        Write-Host -ForeGroundColor 'green' ("Create SQL tables: PM_train, PM_test, PM_truth and PM_models:")
        $script = $filePath + "DataProcessing\create_table.sql"
        ExecuteSQL $script
    
        Write-Host -ForeGroundColor 'green' ("Populate SQL tables: PM_train, PM_test and PM_truth")
        $dataList = "PM_Train", "PM_test", "PM_Truth"
		
		# upload csv files into SQL tables
        foreach ($dataFile in $dataList)
        {
            $destination = $parentPath + "/data/" + $dataFile + ".csv"
            Write-Host -ForeGroundColor 'magenta'("    Populate SQL table: {0}..." -f $dataFile)
            $tableName = $DBName + ".dbo." + $dataFile
            $tableSchema = $parentPath + "/data/" + $dataFile + ".xml"
            bcp $tableName format nul -c -x -f $tableSchema  -U $username -S $ServerName -P $password  -t ','
            Write-Host -ForeGroundColor 'magenta'("    Loading {0} to SQL table..." -f $dataFile)
            bcp $tableName in $destination -t ',' -S $ServerName -f $tableSchema -F 1 -C "RAW" -b 20000 -U $username -P $password
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
# Create and execute the stored procedure for data labeling and 
# feature engineering
##########################################################################
Write-Host -ForeGroundColor 'green' ("Step 2: Data labeling and feature engineering")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 

if ($ans -eq 'y' -or $ans -eq 'Y')
{
    try
    {
        # creat the stored procedure for data labeling
        Write-Host -ForeGroundColor 'magenta'("    Create SQL stored procedure for data labeling...")
        $script = $filePath + "DataProcessing/data_labeling.sql"
        ExecuteSQL $script

        # execute the feature engineering for training data
        Write-Host -ForeGroundColor 'magenta'("    Data labeling for training dataset...")
        $datasetType = 'train'
        $query = "EXEC data_labeling $datasetType, '$connectionString'"
        ExecuteSQLQuery $query

        # execute the feature engineering for testing data
        Write-Host -ForeGroundColor 'magenta'("    Data labeling for testing dataset...")
        $datasetType = 'test'
        $query = "EXEC data_labeling $datasetType, '$connectionString'"
        ExecuteSQLQuery $query

        # creat the stored procedure for feature engineering
        Write-Host -ForeGroundColor 'magenta'("    Create SQL stored procedure for feature engineering...")
        $script = $filePath + "DataProcessing/feature_engineering.sql"
        ExecuteSQL $script

        # execute the feature engineering for training data
        Write-Host -ForeGroundColor 'magenta'("    Execute feature engineering for training dataset...")
        $datasetType = 'train'
        $query = "EXEC feature_engineering $datasetType, '$connectionString'"
        ExecuteSQLQuery $query

        # execute the feature engineering for testing data
        Write-Host -ForeGroundColor 'magenta'("    Execute feature engineering for testing dataset...")
        $datasetType = 'test'
        $query = "EXEC feature_engineering $datasetType, '$connectionString'"
        ExecuteSQLQuery $query
    }
    catch
    {
        Write-Host -ForegroundColor DarkYellow "Exception in data labeling and feature engineering:"
        Write-Host -ForegroundColor Red $Error[0].Exception 
        throw
    }
}

################################################################################
# Create and execute the stored procedures for regression models
################################################################################
Write-Host -ForeGroundColor 'green' ("Step 3a Training/Testing: Regression models")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 

if ($ans -eq 'y' -or $ans -eq 'Y')
{
    try
    {
        # creat the stored procedure for regression models
        Write-Host -ForeGroundColor 'magenta'("    Create and upload the stored procedures for Regression models...")
        $regression = $filePath + "Regression/*_regression_*.sql"
        Get-ChildItem $regression | ForEach-Object -Process {Invoke-Sqlcmd -ServerInstance $ServerName  -Database $DBName -Username $username -Password $password -InputFile $_.FullName -QueryTimeout 200000}

        $modelNames = @("regression_btree","regression_rf","regression_glm","regression_nn")
        foreach ($modelName in $modelNames) {
            Write-Host -ForeGroundColor 'magenta'("    Training Regression model: $modelName...")
            $query = "EXEC train_regression_model $modelName"
            ExecuteSQLQuery $query
            Write-Host -ForeGroundColor 'magenta'("    Training Regression model: $modelName...Done!")
        }

        Read-Host "Press any key to continue for model testing..."

        Write-Host -ForeGroundColor 'green' ("Step 3a Testing: Regression models")

        # test the binaryclass models and collect results and metrics
        Write-Host -ForeGroundColor 'magenta'("    Testing Regression models...")
        $models = "'regression_rf', 'regression_btree', 'regression_glm', 'regression_nn'"
        $query = "EXEC test_regression_models $models, '$connectionString'"
        ExecuteSQLQuery $query
        Write-Host -ForeGroundColor 'magenta'("    Testing Regression models...Done!")
    }
    catch
    {
        Write-Host -ForegroundColor DarkYellow "Exception in training and testing regression models:"
        Write-Host -ForegroundColor Red $Error[0].Exception 
        throw
    }
}
################################################################################
# Create and execute the stored procedures for binary-class models
################################################################################
Write-Host -ForeGroundColor 'green' ("Step 3b Training/Testing: Binary classification models")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 

if ($ans -eq 'y' -or $ans -eq 'Y')
{
    try
    {
        # creat the stored procedure for binary class models
        Write-Host -ForeGroundColor 'magenta'("    Create and upload the stored procedures for training Binary classificaiton models...")
        $binaryclass = $filePath + "BinaryClassification/*_binaryclass_*.sql"
        Get-ChildItem $binaryclass | ForEach-Object -Process {Invoke-Sqlcmd -ServerInstance $ServerName  -Database $DBName -Username $username -Password $password -InputFile $_.FullName -QueryTimeout 200000}

        $modelNames = @("binaryclass_btree","binaryclass_rf","binaryclass_logit","binaryclass_nn")
        foreach ($modelName in $modelNames) {
            Write-Host -ForeGroundColor 'magenta'("    Training Binary classification model: $modelName...")
            $query = "EXEC train_binaryclass_model '$modelName'"
            ExecuteSQLQuery $query
            Write-Host -ForeGroundColor 'magenta'("    Training Binary classification model: $modelName...Done!")
        }

        Read-Host "Press any key to continue for model testing..."

        # test the binaryclass models and collect results and metrics
        Write-Host -ForeGroundColor 'magenta'("    Testing Binary classification models...")
        $models = "'binaryclass_rf', 'binaryclass_btree', 'binaryclass_logit', 'binaryclass_nn'"
        $query = "EXEC test_binaryclass_models $models, '$connectionString'"
        ExecuteSQLQuery $query
        Write-Host -ForeGroundColor 'magenta'("    Testing Binary classification models...Done!")
    }
    catch
    {
        Write-Host -ForegroundColor DarkYellow "Exception in training and testing binary classification models:"
        Write-Host -ForegroundColor Red $Error[0].Exception 
        throw
    }
}
##########################################################################
# Create and execute the stored procedures for multi-class models
##########################################################################
Write-Host -ForeGroundColor 'green' ("Step 3c Training: Multi-classification models")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 

if ($ans -eq 'y' -or $ans -eq 'Y')
{
    try
    {
        # Create the stored procedure for multi class models
        Write-Host -ForeGroundColor 'magenta'("    Create and upload the stored procedures for training Multi-classificaiton models...")
        $multiclass = $filePath + "MultiClassification/*_multiclass_*.sql"
        Get-ChildItem $multiclass | ForEach-Object -Process {Invoke-Sqlcmd -ServerInstance $ServerName  -Database $DBName -Username $username -Password $password -InputFile $_.FullName -QueryTimeout 200000}

        $modelNames = @("multiclass_btree","multiclass_rf","multiclass_mn","multiclass_nn")
        foreach ($modelName in $modelNames) {
            Write-Host -ForeGroundColor 'magenta'("    Training Multi classification model: $modelName...")
            $query = "EXEC train_multiclass_model $modelName"
            ExecuteSQLQuery $query
            Write-Host -ForeGroundColor 'magenta'("    Training Multi classification model: $modelName...Done!")
        }

        Read-Host "Press any key to continue..."

        # test the multiclass models and collect results and metrics
        Write-Host -ForeGroundColor 'magenta'("    Testing Multi-classificaiton models...")
        $models = "'multiclass_rf', 'multiclass_btree', 'multiclass_nn', 'multiclass_mn'"
        $query = "EXEC test_multiclass_models $models, '$connectionString'"
        ExecuteSQLQuery $query
        Write-Host -ForeGroundColor 'magenta'("    Testing Multi-classificaiton models...Done!")
        Write-Host -ForeGroundColor 'green'("Workflow finished successfully!")
    }
    catch
    {
        Write-Host -ForegroundColor DarkYellow "Exception in training and testing multiclass classification models:"
        Write-Host -ForegroundColor Red $Error[0].Exception 
    }
}