# NOTE:
# This script detects:
# - New group creation
# - Users added to groups
# - Users removed from groups
#
# Requires: "Security Group Management" auditing enabled

param (
    [int]$Days,
    [datetime]$StartDate,
    [datetime]$EndDate = (Get-Date)
)

# -----------------------------
# INTERACTIVE MODE
# -----------------------------
if (-not $Days -and -not $StartDate) {

    Write-Host "==== Group Change Hunt Options ====" -ForegroundColor Cyan

    $Days = Read-Host "How many days ago? (Default: 30)"
    if (-not $Days) { $Days = 30 }

    $StartDate = (Get-Date).AddDays(-[int]$Days)
}

# -----------------------------
# AUDIT POLICY CHECK
# -----------------------------
$AuditCheck = auditpol /get /subcategory:"Security Group Management" 2>$null

if ($AuditCheck -notmatch "Success") {
    Write-Host "[WARNING] Security Group Management auditing is NOT fully enabled." -ForegroundColor Red
    Write-Host "[WARNING] Group change events may not be logged." -ForegroundColor Red
}

# -----------------------------
# DATE HANDLING
# -----------------------------
if (-not $StartDate) {
    $StartDate = (Get-Date).AddDays(-$Days)
}

$ScriptStart = Get-Date

Write-Host "`n[+] Group & Membership Change Detector Running..." -ForegroundColor Cyan
Write-Host "Date Range: $StartDate -> $EndDate"
Write-Host ""

# -----------------------------
# EVENT IDS
# -----------------------------
$AddEvents    = @(4728, 4732, 4756)
$RemoveEvents = @(4729, 4733, 4757)
$CreateEvents = @(4727, 4731, 4754)

$AllEvents = $AddEvents + $RemoveEvents + $CreateEvents

# -----------------------------
# PULL EVENTS
# -----------------------------
$Events = Get-WinEvent -FilterHashtable @{
    LogName   = 'Security'
    ID        = $AllEvents
    StartTime = $StartDate
    EndTime   = $EndDate
} -ErrorAction SilentlyContinue

# -----------------------------
# PARSE EVENTS (XML SAFE)
# -----------------------------
$Parsed = $Events | ForEach-Object {

    $xml = [xml]$_.ToXml()
    $data = @{}

    foreach ($d in $xml.Event.EventData.Data) {
        $data[$d.Name] = $d.'#text'
    }

    $EventID = $_.Id

    $Action = switch ($EventID) {
        {$_ -in $AddEvents}    { "User Added To Group" }
        {$_ -in $RemoveEvents} { "User Removed From Group" }
        {$_ -in $CreateEvents} { "Group Created" }
        default                { "Unknown" }
    }

    [PSCustomObject]@{
        TimeCreated = $_.TimeCreated
        Action      = $Action
        EventID     = $EventID
        Actor       = $data["SubjectUserName"]
        TargetUser  = $data["MemberName"]
        Group       = $data["TargetUserName"]
    }
}

# -----------------------------
# CLEAN NOISE
# -----------------------------
$Parsed = $Parsed | Where-Object {
    $_.Actor -and
    $_.Actor -notmatch "\$$" -and
    $_.Actor -ne "SYSTEM"
}

# -----------------------------
# DETECTIONS
# -----------------------------
$HighRiskGroups = @("Administrators", "Domain Admins", "Enterprise Admins")

$HighRiskChanges = $Parsed | Where-Object {
    $HighRiskGroups -contains $_.Group
}

# -----------------------------
# TIMER END
# -----------------------------
$ScriptEnd = Get-Date
$RunTime = $ScriptEnd - $ScriptStart

# -----------------------------
# SUMMARY
# -----------------------------
Write-Host "========== GROUP CHANGE SUMMARY ==========" -ForegroundColor Yellow
Write-Host "Total Events: $($Parsed.Count)"
Write-Host "High Risk Changes: $($HighRiskChanges.Count)"
Write-Host "Number of Days: $Days"
Write-Host "Total Time Run: $RunTime"
Write-Host "==========================================="

# -----------------------------
# DETAILS
# -----------------------------
if ($Parsed) {
    Write-Host "`n[!] ALL GROUP CHANGES" -ForegroundColor Red
    $Parsed | Format-Table TimeCreated, Action, Actor, TargetUser, Group -AutoSize
}

if ($HighRiskChanges) {
    Write-Host "`n[!] HIGH RISK GROUP CHANGES" -ForegroundColor Red
    $HighRiskChanges | Format-Table TimeCreated, Action, Actor, TargetUser, Group -AutoSize
}

# -----------------------------
# EXPORT
# -----------------------------
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

$Parsed | Export-Csv ".\GroupChanges_$Timestamp.csv" -NoTypeInformation

Write-Host "`n[+] Report saved: GroupChanges_$Timestamp.csv"
