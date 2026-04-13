param (
    [int]$Days,
    [datetime]$StartDate,
    [datetime]$EndDate = (Get-Date),
    [string]$LogonType
)

# -----------------------------
# INTERACTIVE MODE (if no params)
# -----------------------------
if (-not $Days -and -not $StartDate) {

    Write-Host "==== Audit Options ====" -ForegroundColor Cyan

    $Days = Read-Host "How many days ago? (Default: 30)"
    if (-not $Days) { $Days = 30 }

    Write-Host ""
    Write-Host "Select Logon Type:"
    Write-Host "A) Interactive (2)"
    Write-Host "B) Network (3)"
    Write-Host "C) RemoteInteractive / RDP (10)"
    Write-Host "D) Batch (4)"
    Write-Host "E) Service (5)"
    Write-Host "F) All"

    $Choice = Read-Host "Enter choice (A-F)"

    switch ($Choice.ToUpper()) {
        "A" { $LogonType = 2 }
        "B" { $LogonType = 3 }
        "C" { $LogonType = 10 }
        "D" { $LogonType = 4 }
        "E" { $LogonType = 5 }
        default { $LogonType = "ALL" }
    }

    $StartDate = (Get-Date).AddDays(-[int]$Days)
}

# -----------------------------
# TIMER START
# -----------------------------
$ScriptStart = Get-Date

Write-Host "`nRunning audit..."
Write-Host "Date Range: $StartDate -> $EndDate"
Write-Host "Logon Type: $LogonType"
Write-Host ""

# -----------------------------
# NEW USERS (4720)
# -----------------------------
$NewUsers = Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    ID = 4720
    StartTime = $StartDate
    EndTime = $EndDate
} -ErrorAction SilentlyContinue | ForEach-Object {
    [PSCustomObject]@{
        TimeCreated = $_.TimeCreated
        CreatedUser = $_.Properties[0].Value
        Creator     = $_.Properties[4].Value
    }
}

# -----------------------------
# NEW SHARES (5142)
# -----------------------------
$NewShares = Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    ID = 5142
    StartTime = $StartDate
    EndTime = $EndDate
} -ErrorAction SilentlyContinue | ForEach-Object {
    [PSCustomObject]@{
        TimeCreated = $_.TimeCreated
        ShareName   = $_.Properties[0].Value
        SharePath   = $_.Properties[1].Value
        Creator     = $_.Properties[4].Value
    }
}

# -----------------------------
# LOGINS (4624)
# -----------------------------
$Logins = Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    ID = 4624
    StartTime = $StartDate
    EndTime = $EndDate
} -ErrorAction SilentlyContinue | ForEach-Object {
    $type = $_.Properties[8].Value

    if ($LogonType -ne "ALL" -and $type -ne [int]$LogonType) {
        return
    }

    [PSCustomObject]@{
        TimeCreated = $_.TimeCreated
        User        = $_.Properties[5].Value
        Domain      = $_.Properties[6].Value
        LogonType   = $type
        SourceIP    = $_.Properties[18].Value
    }
}

# -----------------------------
# COUNTS
# -----------------------------
$TotalLogins = $Logins.Count
$TotalUsers = $NewUsers.Count
$TotalShares = $NewShares.Count

# -----------------------------
# TIMER END
# -----------------------------
$ScriptEnd = Get-Date
$RunTime = $ScriptEnd - $ScriptStart

# -----------------------------
# SUMMARY
# -----------------------------
Write-Host "========== AUDIT SUMMARY ==========" -ForegroundColor Cyan
Write-Host "Total Logins: $TotalLogins"
Write-Host "Total Newly Created Users: $TotalUsers"
Write-Host "Total Newly Created Shares: $TotalShares"
Write-Host ""
Write-Host "Start Date: $StartDate"
Write-Host "End Date: $EndDate"
Write-Host "Number of Days: $Days"
Write-Host "Total Time Run: $RunTime"
Write-Host "==================================="

# -----------------------------
# OUTPUT DETAILS
# -----------------------------
Write-Host "`n--- New Users ---" -ForegroundColor Yellow
$NewUsers | Format-Table -AutoSize

Write-Host "`n--- New Shares ---" -ForegroundColor Yellow
$NewShares | Format-Table -AutoSize

Write-Host "`n--- Logins ---" -ForegroundColor Yellow
$Logins | Format-Table -AutoSize
