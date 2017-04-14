$count = 1
$TotalRows = 1100000
$vServerName = "SQLRTUTORIAL"
$vDatabaseName = "ResumeMatching"

$num_workload_group = 4
$batch_per_load = 2
$model = "rxBTrees"
$projectId = 1000001

$Start = 0
$Increment = $TotalRows/($num_workload_group*$batch_per_load)
$End = $Start+$Increment-1
$EndCtr = 0


Write-Host "Starting the prediction jobs for Project [$projectId]..."
while (($EndCtr -le $TotalRows) -and ($count -le $num_workload_group))
{
    # Set application name for SQLCMD command using the loop counter.
    # In SQL Server side, the resource governor classifier function will
    # assign the correct workload group (which represents a resource pool and
    # external resource pool pair)
    [string] $AppName = "$count - PredictionJob"

    # Generate two script blocks containing the SQLCMD command.
    # The wrapper stored procedure simply invokes the scoring procedure in a loop.
    $SqlScript = [ScriptBlock]::Create("Invoke-SqlCmd -Server `"" + $vServerName + "`" -Query `"EXEC score_for_matching_batch " + $model + ", " + $projectId + ", " + $Start + ", " + $End + ", 0.51`" -Database `"$vDatabaseName`" -QueryTimeout 0 -HostName `"$AppName`"")
    Start-Job -ScriptBlock $SqlScript
    $EndCtr += $Increment
    $Start += $Increment
    $End += $Increment

    if ($batch_per_load -ge 2) {
        $SqlScript = [ScriptBlock]::Create("Invoke-SqlCmd -Server `"" + $vServerName + "`" -Query `"EXEC score_for_matching_batch " + $model + ", " + $projectId + ", " + $Start + ", " + $End + ", 0.51`" -Database `"$vDatabaseName`" -QueryTimeout 0 -HostName `"$AppName`"")
        Start-Job -ScriptBlock $SqlScript
        $EndCtr += $Increment
        $Start += $Increment
        $End += $Increment
    }

    if ($batch_per_load -ge 3) {
        $SqlScript = [ScriptBlock]::Create("Invoke-SqlCmd -Server `"" + $vServerName + "`" -Query `"EXEC score_for_matching_batch " + $model + ", " + $projectId + ", " + $Start + ", " + $End + ", 0.51`" -Database `"$vDatabaseName`" -QueryTimeout 0 -HostName `"$AppName`"")
        Start-Job -ScriptBlock $SqlScript
        $EndCtr += $Increment
        $Start += $Increment
        $End += $Increment
    }
    
    if ($batch_per_load -ge 4) {
        $SqlScript = [ScriptBlock]::Create("Invoke-SqlCmd -Server `"" + $vServerName + "`" -Query `"EXEC score_for_matching_batch " + $model + ", " + $projectId + ", " + $Start + ", " + $End + ", 0.51`" -Database `"$vDatabaseName`" -QueryTimeout 0 -HostName `"$AppName`"")
        Start-Job -ScriptBlock $SqlScript
        $EndCtr += $Increment
        $Start += $Increment
        $End += $Increment
    }

    if ($batch_per_load -ge 5) {
        $SqlScript = [ScriptBlock]::Create("Invoke-SqlCmd -Server `"" + $vServerName + "`" -Query `"EXEC score_for_matching_batch " + $model + ", " + $projectId + ", " + $Start + ", " + $End + ", 0.51`" -Database `"$vDatabaseName`" -QueryTimeout 0 -HostName `"$AppName`"")
        Start-Job -ScriptBlock $SqlScript
        $EndCtr += $Increment
        $Start += $Increment
        $End += $Increment
    }

    $count += 1
}