#This script will search interesting powershell events on a system of interest
#the timerange is 30 days. You should dial this in to how you perform your own
#investigations 

# ================================
# PowerShell IR Event Collection
# Last 30 Days
# ================================

$logName = "Microsoft-Windows-PowerShell/Operational"

# IR-relevant Event IDs
$interestingEventIds = @(
    400,   # Engine Start
    403,   # Engine Stop
    4103,  # Module Loggsing
    4104,  # Script Block Logging
    600,   # Provider Lifecycle
    800,   # Pipeline Execution
    409,   # Provider Warning
    410,   # Engine Warning
    8193,  # Remoting Error
    8194   # Remoting Session Failure
)

# Time window
$startTime = (Get-Date).AddDays(-30)

# Query events
$events = Get-WinEvent -FilterHashtable @{
    LogName   = $logName
    StartTime = $startTime
} | Where-Object {
    $interestingEventIds -contains $_.Id
}

$results = $events | Select-Object `
    TimeCreated,
    Id,
    LevelDisplayName,
    ProviderName,
    MachineName,
    @{ Name = "User"; Expression = { $_.UserId } },
    Message

$results | Format-Table -Wrap

