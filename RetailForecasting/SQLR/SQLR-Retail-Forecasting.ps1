<#
.SYNOPSIS
Script to trian, test and evaluate the retail forecasting template with SQL + MRS

.DESCRIPTION
This script will show the E2E work flow of retail forecasting machine learning
templates with Microsoft SQL 2016 and Microsoft R services. 

For the detailed description, please read README.md.
#>
[CmdletBinding()]
param(
# SQL server
[parameter(Mandatory=$true,ParameterSetName = "Train_test")]
[ValidateNotNullOrEmpty()] 
[String]    
$ServerName = "",

# SQL server database name
[parameter(Mandatory=$true,ParameterSetName = "Train_test")]
[ValidateNotNullOrEmpty()]
[String]
$DBName = "",

# Switch for time series scoring
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
# Construct the SQL connection strings
##########################################################################
$connectionString = GetConnectionString
##########################################################################
# Score the time series
##########################################################################
if($score -eq $true)
{
    Write-Host -ForeGroundColor 'green'("Time Series Scoring...")
    try
    { 
        $testLength = 4
        $ID1 = 2
        $ID2 = 1
        # creat the stored procedure to preprocess the data
        Write-Host -ForeGroundColor 'magenta'("    Create SQL stored procedure for data preprocessing...")
        $script = $filePath + "data_preprocess_score.sql"
        ExecuteSQL $script
        # execute the data preprocessing
        Write-Host -ForeGroundColor 'magenta'("    Execute data preprocessing...")                
        $query = "EXEC data_preprocess_score $testLength, $ID1, $ID2, '$connectionString'"
        ExecuteSQLQuery $query
        $modelName = "arima"
        $testtype = "prod"
        $query = "EXEC time_series_forecasting $testLength, $modelName, '$connectionString', $testtype"  
        ExecuteSQLQuery $query    		
        # execute the feature engineering for data to be scored
        Write-Host -ForeGroundColor 'magenta'("    Execute feature engineering for scoring with regression model...")
        $query = "EXEC feature_engineering '$connectionString', $testLength"
        ExecuteSQLQuery $query
        Write-Host -ForeGroundColor 'magenta'("    Feature engineering for scoring with regression model...Done!")

        Write-Host -ForeGroundColor 'magenta'("    Generate train dataset...")
        $numFolds = 1        
        $query = "EXEC generate_train '$connectionString', $numFolds, $testLength"
        ExecuteSQLQuery $query
        Write-Host -ForeGroundColor 'magenta'("    Generate train dataset...Done!")

        Write-Host -ForeGroundColor 'magenta'("    Generate test dataset...")       
        $query = "EXEC generate_test '$connectionString', $testLength"
        ExecuteSQLQuery $query
        Write-Host -ForeGroundColor 'magenta'("    Generate test dataset...Done!")

        # Create the stored procedure for scoring regression models
        Write-Host -ForeGroundColor 'magenta'("    Create and upload the stored procedures for scoring regression models...")
        $script = $filePath + "score_regression_rf.sql"
        ExecuteSQL $script
        Write-Host -ForeGroundColor 'magenta'("    Create and upload the stored procedures for scoring regression models...Done!")               

        # Execute the scoring script
        Write-Host -ForeGroundColor 'magenta'("    Scoring regression model...")
        # The optimized parameters from the training
        $nTree = 90
        $maxDepth = 48
        $query = "EXEC score_regression_rf '$connectionString', $nTree, $maxDepth"
        ExecuteSQLQuery $query
        Write-Host -ForeGroundColor 'magenta'("    Scoring regression model...Done!")

        Write-Host -ForeGroundColor 'green'("Scoring finished successfully!")
        return
    }
    catch
    {
        Write-Host -ForegroundColor DarkYellow "Exception in scoring maintenance data:"
        Write-Host -ForegroundColor Red $Error[0].Exception 
    }
}
############################################################################
# Create tables for times series data and populate with data from csv files.
############################################################################
Write-Host -ForeGroundColor 'green' ("Step 0: Create and populate times series data in Database {0}" -f $DBName)
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
        Write-Host -ForeGroundColor 'green' ("Create SQL tables: forecastinginput and forecasting_personal_income:")
        $script = $filePath + "create_table.sql"
        ExecuteSQL $script
    
        Write-Host -ForeGroundColor 'green' ("Populate SQL tables: PM_train, PM_test and PM_truth")
        $dataList = "forecastinginput", "forecasting_personal_income"
		
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
# Create and execute the stored procedure for data preprocessing
##########################################################################
Write-Host -ForeGroundColor 'green' ("Step 1: Data preprocessing")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 

if ($ans -eq 'y' -or $ans -eq 'Y')
{
    try
    {
        # creat the stored procedure to preprocess the data
        Write-Host -ForeGroundColor 'magenta'("    Create SQL stored procedure for data preprocessing...")
        $script = $filePath + "data_preprocess.sql"
        ExecuteSQL $script

        # execute the data preprocessing
        Write-Host -ForeGroundColor 'magenta'("    Execute data preprocessing...")
        $testLength = 52        
        $query = "EXEC data_preprocess $testLength, '$connectionString'"
        ExecuteSQLQuery $query        
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
Write-Host -ForeGroundColor 'green' ("Step 2 Training/Testing: time series models")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 

if ($ans -eq 'y' -or $ans -eq 'Y')
{
    try
    {
        # creat the stored procedure for time series models
        Write-Host -ForeGroundColor 'magenta'("    Create and upload the stored procedures for time series models...")        
        $script = $filePath + "time_series_forecasting.sql"
        ExecuteSQL $script

        Write-Host -ForeGroundColor 'green' ("    Execute the stored procedures for time series model: ets")        
        $testLength = 52
        $modelName = "ets"
        $testtype = "test"
        $query = "EXEC time_series_forecasting $testLength, $modelName, '$connectionString', $testtype"
        ExecuteSQLQuery $query
        Write-Host -ForeGroundColor 'green' ("    Execute the stored procedures for time series model: ets......Done!")
        Write-Host -ForeGroundColor 'green' ("    Execute the stored procedures for time series model: snaive")
        $modelName = "snaive"
        $query = "EXEC time_series_forecasting $testLength, $modelName, '$connectionString', $testtype"
        ExecuteSQLQuery $query
        Write-Host -ForeGroundColor 'green' ("    Execute the stored procedures for time series model: snaive......Done!")
        Write-Host -ForeGroundColor 'green' ("    Execute the stored procedures for time series model: arima")
        $modelName = "arima"
        $query = "EXEC time_series_forecasting $testLength, $modelName, '$connectionString', $testtype"
        ExecuteSQLQuery $query
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
Write-Host -ForeGroundColor 'green' ("Step 3 Feature engineering")
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
        Write-Host -ForeGroundColor 'magenta'("    Create and upload the stored procedures for feature engineering...")
        $script = $filePath + "feature_engineering.sql"    
        ExecuteSQL $script

        $script = $filePath + "generate_train.sql"    
        ExecuteSQL $script

        $script = $filePath + "generate_test.sql"    
        ExecuteSQL $script

        Write-Host -ForeGroundColor 'magenta'("    Execute the stored procedures for feature engineering...")  
        $testLength = 52             
        $query = "EXEC feature_engineering '$connectionString', $testLength"
        ExecuteSQLQuery $query
        Write-Host -ForeGroundColor 'magenta'("    Feature engineering for regression models...Done!")

        Write-Host -ForeGroundColor 'magenta'("    Generate train dataset...")
        $numFolds = 3        
        $query = "EXEC generate_train '$connectionString', $numFolds, $testLength"
        ExecuteSQLQuery $query
        Write-Host -ForeGroundColor 'magenta'("    Generate train dataset...Done!")

        Write-Host -ForeGroundColor 'magenta'("    Generate test dataset...")       
        $query = "EXEC generate_test '$connectionString', $testLength"
        ExecuteSQLQuery $query
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
Write-Host -ForeGroundColor 'green' ("Step 4 Training: Regression models")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 

if ($ans -eq 'y' -or $ans -eq 'Y')
{
    try
    {
        # Create the stored procedure for regression models
        Write-Host -ForeGroundColor 'magenta'("    Create and upload the stored procedures for training regression models...")
        $script = $filePath + "train_regression_btree.sql"
        ExecuteSQL $script
        $script = $filePath + "train_regression_rf.sql"
        ExecuteSQL $script
        Write-Host -ForeGroundColor 'magenta'("    Create and upload the stored procedures for training regression modelss...Done!")               

        # Train the regression models and collect results and metrics
        Write-Host -ForeGroundColor 'magenta'("    Training regression model with boosted decision tree...")
        $numFolds = 3
        $query = "EXEC train_regression_btree '$connectionString', $numFolds"
        ExecuteSQLQuery $query
        Write-Host -ForeGroundColor 'magenta'("    Training regression model with boosted decision tree...Done!")

        Write-Host -ForeGroundColor 'magenta'("    Training regression model with random forest...")
        $query = "EXEC train_regression_rf '$connectionString', $numFolds"
        ExecuteSQLQuery $query
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
Write-Host -ForeGroundColor 'green' ("Step 5 Testing/evaluating: Regression models")
$ans = Read-Host 'Continue [y|Y], Exit [e|E], Skip [s|S]?'
if ($ans -eq 'E' -or $ans -eq 'e')
{
    return
} 

if ($ans -eq 'y' -or $ans -eq 'Y')
{
    try
    {
        # Create the stored procedure for testing regression models
        Write-Host -ForeGroundColor 'magenta'("    Create and upload the stored procedures for testing regression models...")
        $script = $filePath + "test_regression_models.sql"
        ExecuteSQL $script
        Write-Host -ForeGroundColor 'magenta'("    Create and upload the stored procedures for testing regression models...Done!")               

        # Test and evaluate the regression models and collect results and metrics
        Write-Host -ForeGroundColor 'magenta'("    Testing and evaluating regression model...")
        $query = "EXEC test_regression_models '$connectionString'"
        ExecuteSQLQuery $query
        Write-Host -ForeGroundColor 'magenta'("    Testing and evaluating regression model...Done!")
    }
    catch
    {
        Write-Host -ForegroundColor DarkYellow "Exception in testing and evaluating regression models:"
        Write-Host -ForegroundColor Red $Error[0].Exception 
    }   
}
Write-Host -ForeGroundColor 'green'("Workflow finished successfully!")