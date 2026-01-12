# Correlates virtual machines created within a defined time span and
# captures hypervisor-exposed IP address information to support
# blast-radius analysis and SIEM correlation.

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

# Collect VMs created within timeframe
$VMs = Get-VM |
    Where-Object { $_.CreationTime -ge $CutOff }

# Correlate VM → Network Metadata
$VMDetails = foreach ($VM in $VMs) {
    $NetAdapters = Get-VMNetworkAdapter -VMName $VM.Name -ErrorAction SilentlyContinue

    foreach ($Adapter in $NetAdapters) {
        [PSCustomObject]@{
            VMName       = $VM.Name
            State        = $VM.State
            CreationTime = $VM.CreationTime
            SwitchName   = $Adapter.SwitchName
            IPAddresses  = ($Adapter.IPAddresses -join ", ")
        }
    }
}

# Output VM detail data
$VMDetails |
Sort-Object CreationTime |
Format-Table -AutoSize |
Out-File $OutputLog

# Timing end
$Stopwatch.Stop()
$EndTime  = Get-Date
$Duration = $Stopwatch.Elapsed
$VmCount  = $VMs.Count

# Execution summary
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
