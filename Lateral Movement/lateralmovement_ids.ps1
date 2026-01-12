<#
Correlates Windows event logs associated with lateral movement,
remote execution, service creation, scheduled tasks, registry
modifications, and PowerShell remoting.

Scope:
- Read-only event log collection
- No active probing
- Designed for IR timeline reconstruction
#>

param (
    [ValidateSet(30,60,90)]
    [int]$Days = 30,

    [string]$OutputLog
)

# Default log file
if (-not $OutputLog) {
    $OutputLog = (Get-Date -Format "yyyy_MM_dd_HHmmss") + "_lateral_movement.log"
}

# Timing start
$StartTime = Get-Date
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

$StartWindow = (Get-Date).AddDays(-$Days)

# Event ID map derived from table
$EventIDMap = @{
    Security = @(
        4624,   # Logon (Type 3, 10)
        4625,   # Failed logon
        4688,   # Process creation
        4697,   # Service installation
        4698,   # Scheduled task creation
        4702,   # Scheduled task update
        4657    # Registry modification
    )
    System = @(
        7045    # Service creation
    )
    MicrosoftWindowsPowerShell = @(
        4103,   # Module logging
        4104    # Script block logging
    )
}

$Results = @()

foreach ($Log in $EventIDMap.Keys) {
    foreach ($EventID in $EventIDMap[$Log]) {
        try {
            $Events = Get-WinEvent -FilterHashtable @{
                LogName   = $Log
                Id        = $EventID
                StartTime = $StartWindow
            } -ErrorAction SilentlyContinue

            foreach ($Event in $Events) {
                $Results += [PSCustomObject]@{
                    TimeCreated = $Event.TimeCreated
                    LogName     = $Log
                    EventID     = $Event.Id
                    Provider    = $Event.ProviderName
                    Computer    = $Event.MachineName
                    Message     = ($Event.Message -replace "`r|`n"," ")
                }
            }
        }
        catch {
            continue
        }
    }
}

# Output results
$Results |
Sort-Object TimeCreated |
Out-File $OutputLog

# Timing end
$Stopwatch.Stop()
$EndTime  = Get-Date
$Duration = $Stopwatch.Elapsed
$Count    = $Results.Count

# Summary block
$Summary = @"
Execution Summary
---------------------------
Start Time        : $StartTime
End Time          : $EndTime
Duration          : $($Duration.ToString())
Records Collected : $Count
Lookback (Days)   : $Days
"@

$Summary | Tee-Object -FilePath $OutputLog -Append
