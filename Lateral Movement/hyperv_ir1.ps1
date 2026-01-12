param (
    [ValidateRange(1,365)]
    [int]$TimeSpan = 30,

    [string]$OutputLog
)

# Default log file if none supplied
if (-not $OutputLog) {
    $OutputLog = (Get-Date -Format "yyyy_MM_dd_HHmmss") + ".log"
}

# Timing start
$StartTime = Get-Date
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

$CutOff = (Get-Date).AddDays(-$TimeSpan)

$VMs = Get-VM |
    Where-Object { $_.CreationTime -ge $CutOff } |
    Select-Object Name, State, Uptime, CreationTime |
    Sort-Object CreationTime

$VMs | Out-File $OutputLog

# Timing end
$Stopwatch.Stop()
$EndTime  = Get-Date
$Duration = $Stopwatch.Elapsed
$VmCount  = $VMs.Count

$Summary = @"
Execution Summary
---------------------------
Start Time        : $StartTime
End Time          : $EndTime
Duration          : $($Duration.ToString())
VMs Processed     : $VmCount
TimeSpan (Days)   : $TimeSpan
"@

$Summary | Tee-Object -FilePath $OutputLog -Append
