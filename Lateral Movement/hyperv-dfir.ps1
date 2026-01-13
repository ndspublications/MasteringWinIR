#DFIR SCRIPT THAT OUTPUTS THE INFORMATION FROM EVENT VIEWER HYPERV
#IN A SLOG CALLED YYYY_MM_DD_HHMMSS_HYPERV.log

param (
    [int]$TimeSpan = 30   # Days (default = last 30 days)
)

# ---------------------------
# Execution timing
# ---------------------------
$execStart  = Get-Date
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# ---------------------------
# Log time window
# ---------------------------
$logStart = (Get-Date).AddDays(-$TimeSpan)
$logEnd   = Get-Date

# ---------------------------
# Output file
# ---------------------------
$timestamp = Get-Date -Format "yyyy_MM_dd_HHmmss"
$outFile   = "$timestamp_HYPERV.log"

# ---------------------------
# Event IDs (wide net)
# ---------------------------
$eventIds = @(
    12000,12010,12020,13002,
    18304,2014,16641,18601,
    3086,18500,18609,18504,
    18506,18606,12148,12582
)

# ---------------------------
# XPath filter (engine-side)
# ---------------------------
$xpath = "*[System[(" +
    ($eventIds | ForEach-Object { "EventID=$_"} -join " or ") +
")]]"

# ---------------------------
# Collect events
# ---------------------------
$events = Get-WinEvent `
    -LogName "Microsoft-Windows-Hyper-V-VMMS*" `
    -FilterXPath $xpath |
    Where-Object {
        $_.TimeCreated -ge $logStart -and
        $_.TimeCreated -le $logEnd
    }

# ---------------------------
# Stop timing
# ---------------------------
$stopwatch.Stop()
$execEnd = Get-Date

# ---------------------------
# Execution summary
# ---------------------------
@"
Execution Summary
---------------------------
Execution Start : $execStart
Execution End   : $execEnd
Execution Time  : $($stopwatch.ElapsedMilliseconds) ms
Log Time Window : Last $TimeSpan days
Log Range       : $logStart -> $logEnd
Events Found    : $($events.Count)

"@ | Out-File -FilePath $outFile -Encoding UTF8

# ---------------------------
# Event output
# ---------------------------
$events |
Select TimeCreated, Id, Message |
Format-Table -Wrap |
Out-File -FilePath $outFile -Append -Encoding UTF8
