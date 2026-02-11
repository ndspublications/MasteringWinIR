param (
    [int]$DaysBack = 30
)

# -------------------------
# Setup
# -------------------------
$startTimeGlobal = Get-Date
$startDate       = (Get-Date).AddDays(-$DaysBack)

#EXECUTABLES AND SCRIPTS CAN BE ADDED / REMOVED AT WILL
$privEscCmd = @(
    'whoami',
    'winpeas',
    'seatbelt',
    'powersploit',
    'mimikatz',
    'rundll32',
    'reg save',
    'token::',
    'privilege::',
    'getsystem'
)

$regex = ($privEscCmd -join '|')

$today = Get-Date -Format "dd_MM_yyyy"
$outputFile = "$today`_privescalation.log"

$totalFindings = 0
$stats = @()

# -------------------------
# Enumerate Logs
# -------------------------
$logs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IsEnabled -and
            $_.RecordCount -gt 0
        }

# -------------------------
# Begin Scan
# -------------------------
foreach ($log in $logs) {

    Write-Host "[+] Searching Windows Log: $($log.LogName)"

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $found = 0

    $results = Get-WinEvent -FilterHashtable @{
        LogName   = $log.LogName
        StartTime = $startDate
    } -ErrorAction SilentlyContinue -WarningAction SilentlyContinue |
    Where-Object {
        $_.Message -match $regex -or
        $_.ToXml() -match $regex
    }

    foreach ($event in $results) {
        $found++
        $totalFindings++

        $eventOutput = @"
[$($event.TimeCreated)]
Log: $($log.LogName)
EventID: $($event.Id)
----------------------------------------
$($event.Message)
----------------------------------------

"@
        Add-Content -Path $outputFile -Value $eventOutput
    }

    $sw.Stop()

    $stats += [PSCustomObject]@{
        LogName      = $log.LogName
        ScanTimeMs   = $sw.ElapsedMilliseconds
        FoundEntries = $found
    }
}

# -------------------------
# Final Statistics
# -------------------------
$endTimeGlobal = Get-Date
$totalDuration = ($endTimeGlobal - $startTimeGlobal)

Write-Host "`nInvestigation Statistics:"
Write-Host "----------------------------"

foreach ($s in $stats) {
    Write-Host ("{0}: {1} ms | Found Entries: {2}" -f `
        $s.LogName, $s.ScanTimeMs, $s.FoundEntries)
}

Write-Host "----------------------------"
Write-Host "Total Scan Time: $($totalDuration.TotalSeconds) seconds"
Write-Host "Total Entries Found: $totalFindings"
Write-Host "Output File: $outputFile"
