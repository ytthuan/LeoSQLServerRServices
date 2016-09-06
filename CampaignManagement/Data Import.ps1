write-host "program started"
# powershell -executionpolicy bypass -File ./asd.ps1

##########################################################################
# Function wrapper to invoke SQL command
##########################################################################
function ExecuteSQL
{
param(
[String]
$sqlscript
)
    #Write-Host "Invoke-Sqlcmd -ServerInstance $ServerName  -Database $DBName  -InputFile $sqlscript -QueryTimeout 200000"
    Invoke-Sqlcmd -ServerInstance $ServerName  -Database $DBName  -InputFile $sqlscript -QueryTimeout 200000
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
    Invoke-Sqlcmd -ServerInstance $ServerName  -Database $DBName $sqlquery -QueryTimeout 200000
}
##########################################################################
# Get the current SQL related parameters and set them to specified values
##########################################################################
function SetParamValues
{
param(
[String]
$targetDbname,
[String]
$targetUsername,
[String]
$targetPassword
)
    # Get the current parameter values
    $rUse = [regex]"^(USE)(.*)"
    $rdb = [regex]"^(\s*Database=)(.*)(;$)"
    $rUid = [regex]"^(\s*UID=)(.*)(;$)"
    $rPwd = [regex]'^(\s*PWD=)(.*)("$)'   
  
    $files = $filePath + "*.sql"
    $listfiles = Get-ChildItem $files -Recurse

    # Udpate the SQL related parameters in each SQL script file
    foreach ($file in $listfiles)
    {        
        (Get-Content $file) | Foreach-Object {
            $_ -replace $rUse, "`$1 [$targetDbname]" `
               -replace $rdb, "`$1$targetDbname`$3" `
               -replace $rUid, "`$1$targetUsername`$3" `
               -replace $rPwd, "`$1$targetPassword`$3"
        } | Set-Content $file
    }
}

##########################################################################
# Get the credential of SQL user
##########################################################################
$ServerName=Read-Host "Enter Server Name: "
$DBName=Read-Host "Enter Database Name: "
$schema=Read-Host "Enter Schema Name(eg: dbo):"

Write-Host -foregroundcolor 'green' ("Please Enter the Credentials for Database {0} of SQL Server {1}" -f $DBName, $ServerName)
$username =Read-Host 'Username:'
$pwd = Read-Host 'Password:' -AsSecureString
$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwd))


##########################################################################
# To create input table structure
##########################################################################
Write-Host -foregroundcolor 'green' ("Using SQL DB: {0} and User: {1}" -f $DBName, $username)
Write-Host  'Creating Input Dataset...'
Write-Host -ForeGroundColor 'green' ("Update SQL related parameters")
SetParamValues $DBName $username $password

$filePath = Read-Host "Enter the Full Path of File Location"
Write-Host -ForeGroundColor 'green' ("Running step0_table_structure_input_data.sql")
$script = $filePath + "\SQLR\step0_table_structure_input_data.sql"
Write-Host -ForeGroundColor 'magenta'("running SQL file "-f $script)
try
{
	ExecuteSQL $script
}
catch
{
	Write-Host -ForegroundColor DarkYellow "Exception While Loading step0_table_structure_input_data.sql:"
	Write-Host -ForegroundColor Red $Error[0].Exception 
	throw
}
##########################################################################
# Populate data from csv files
##########################################################################
try
{
	$allFiles=Get-ChildItem $filePath"\data" -Filter *.csv 
	foreach ( $fileName in $allFiles)
	{
		$fullFileName=$filePath+"\data\"+$fileName
		$tableName = $DBName +"."+ $schema +"."+ $fileName.ToString().Split('.')[0]
		Write-Host "Loading File $fullFileName"
		Write-Host -ForeGroundColor 'magenta'("    Populate SQL table: {0}..." -f $dataFile)
		Write-Host -ForeGroundColor 'magenta'("    Loading {0} to SQL table..." -f $tableName)
		bcp $tableName in $fullFileName -t ',' -S $ServerName -F 2 -C "RAW" -b 20000 -U $username -P $password -T -E -c
	}
}
catch
{
	Write-Host -ForegroundColor DarkYellow "Exception in Populating Data from CSV Files:"
	Write-Host -ForegroundColor Red $Error[0].Exception 
	throw
}
