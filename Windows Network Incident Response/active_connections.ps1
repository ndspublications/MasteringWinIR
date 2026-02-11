$ScriptStart = Get-Date
$TimeStamp   = $ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile  = "network_process_connections_$TimeStamp.log"

Write-Host "Network Process Connection Enumeration"
Write-Host "--------------------------------------------"

$Connections = Get-NetTCPConnection -ErrorAction SilentlyContinue

$Results = @()

foreach ($Conn in $Connections) {

    $Process = Get-Process -Id $Conn.OwningProcess -ErrorAction SilentlyContinue

    if ($Process) {

        $Results += [PSCustomObject]@{
            PID            = $Process.Id
            ProcessName    = $Process.ProcessName
            ExecutablePath = $Process.Path
            StartTime      = $Process.StartTime
            LocalAddress   = $Conn.LocalAddress
            LocalPort      = $Conn.LocalPort
            RemoteAddress  = $Conn.RemoteAddress
            RemotePort     = $Conn.RemotePort
            State          = $Conn.State
        }
    }
}

# Group summary by PID
$Grouped = $Results | Group-Object PID | ForEach-Object {

    $Sample = $_.Group | Select-Object -First 1

    [PSCustomObject]@{
        PID             = $Sample.PID
        ProcessName     = $Sample.ProcessName
        ExecutablePath  = $Sample.ExecutablePath
        StartTime       = $Sample.StartTime
        TotalConnections= $_.Count
    }
}

$ScriptEnd = Get-Date
$Elapsed   = $ScriptEnd - $ScriptStart

$Summary = @"
Network Process Connection Report
--------------------------------------------
Script Start: $ScriptStart
Script End:   $ScriptEnd
Elapsed Time: $Elapsed
Total Active TCP Connections: $($Results.Count)
Total Unique Processes: $($Grouped.Count)
--------------------------------------------
"@

Write-Host $Summary
$Summary | Out-File $OutputFile

# Detailed connection view
Write-Host "`n--- Detailed Connections ---`n"
$Results | Sort-Object PID |
    Tee-Object -FilePath $OutputFile -Append |
    Format-Table -AutoSize

# Summary by process
Write-Host "`n--- Connection Summary by Process ---`n"
$Grouped | Sort-Object TotalConnections -Descending |
    Tee-Object -FilePath $OutputFile -Append |
    Format-Table -AutoSize

Write-Host "`nResults written to $OutputFile"