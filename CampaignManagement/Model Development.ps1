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
# Running SQL Queries
##########################################################################

Write-Host -foregroundcolor 'green' ("Using SQL DB: {0} and User: {1}?" -f $DBName, $username)
$ans = Read-Host 'Do You Want to Continue the Model Devolopment (Any Existing Databse Objects Will be Replaced) - Yes [y|Y], No [n|N]?'
if ($ans -eq 'N' -or $ans -eq 'n')
{
    return
} 

if ($ans -eq 'y' -or $ans -eq 'Y')
{
	$filePath = Read-Host "Enter the Full Path of File Location"
	 
##########################################################################
# Training Models - RF & GBM
##########################################################################

try 
	{
	$allsqlFiles=Get-ChildItem $filePath"\SQLR" -Filter step5*.sql
	foreach ( $sqlFile in $allsqlFiles)
			{	
				$fullFileName=$filePath+"\SQLR\"+$sqlFile
				Write-Host -ForeGroundColor 'magenta'("    running {0} to SQL table..." -f $fullFileName)
				ExecuteSQL $fullFileName
			}
	}
catch
	{
		Write-Host -ForegroundColor DarkYellow "Exception While Loading step5*.sql Files:" 
		Write-Host -ForegroundColor Red $Error[0].Exception 
		throw
	}
	 
	 
##########################################################################
# Models Comparison
##########################################################################

try 
	{
	$allsqlFiles=Get-ChildItem $filePath"\SQLR" -Filter step6*.sql
	foreach ( $sqlFile in $allsqlFiles)
			{	
				$fullFileName=$filePath+"\SQLR\"+$sqlFile
				Write-Host -ForeGroundColor 'magenta'("    running {0} to SQL table..." -f $fullFileName)
				ExecuteSQL $fullFileName
			}
	}
catch
	{
		Write-Host -ForegroundColor DarkYellow "Exception While Loading step6_models_comparision.sql:" 
		Write-Host -ForegroundColor Red $Error[0].Exception 
		throw
	}

}
 
Write-Host "Exiting from program"

