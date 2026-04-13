# NOTE:
# This script relies on Windows Object Access auditing (Event ID 4663).
# If File System auditing and folder-level auditing (SACL) are not configured,
# results may be incomplete or empty.

param (
    [int]$Days = 1,
    [datetime]$StartDate,
    [datetime]$EndDate = (Get-Date)
)

# -----------------------------
# AUDIT POLICY CHECK (IMPORTANT)
# -----------------------------
$AuditCheck = auditpol /get /subcategory:"File System" 2>$null

if ($AuditCheck -notmatch "Success") {
    Write-Host "[WARNING] File System auditing is NOT fully enabled." -ForegroundColor Red
    Write-Host "[WARNING] 4663 events may not be logged." -ForegroundColor Red
}

# Basic SACL presence check (not perfect, but useful signal)
try {
    $AuditRules = (Get-Acl "C:\").Audit
    if (-not $AuditRules) {
        Write-Host "[WARNING] No auditing rules (SACL) detected on system paths." -ForegroundColor Yellow
        Write-Host "[WARNING] File-level events may not be captured." -ForegroundColor Yellow
    }
} catch {}

# -----------------------------
# DATE HANDLING
# -----------------------------
if (-not $StartDate) {
    $StartDate = (Get-Date).AddDays(-$Days)
}

$ScriptStart = Get-Date

Write-Host "`n[+] File Activity Detector Running..." -ForegroundColor Cyan
Write-Host "Date Range: $StartDate -> $EndDate"
Write-Host ""

# -----------------------------
# TARGET EXTENSIONS (HIGH SIGNAL)
# -----------------------------
$SuspiciousExtensions = @(".exe", ".ps1", ".bat", ".dll", ".zip")

# -----------------------------
# PULL EVENTS (4663)
# -----------------------------
$Events = Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    ID = 4663
    StartTime = $StartDate
    EndTime = $EndDate
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

    $AccessMask = $data["AccessMask"]
    $ObjectName = $data["ObjectName"]
    $User       = $data["SubjectUserName"]

    # Detect WRITE / CREATE / DELETE
    $IsWrite = $false

    if ($AccessMask) {
        if ($AccessMask -match "0x2|0x6|0x10000|0x12019f") {
            $IsWrite = $true
        }
    }

    if (-not $IsWrite) { return }

    # Extension filtering
    $ExtensionMatch = $false
    foreach ($ext in $SuspiciousExtensions) {
        if ($ObjectName -like "*$ext") {
            $ExtensionMatch = $true
            break
        }
    }

    if (-not $ExtensionMatch) { return }

    [PSCustomObject]@{
        TimeCreated = $_.TimeCreated
        User        = $User
        ObjectName  = $ObjectName
        AccessMask  = $AccessMask
    }
}

# -----------------------------
# CLEAN NOISE
# -----------------------------
$Parsed = $Parsed | Where-Object {
    $_.User -and
    $_.User -notmatch "\$$" -and
    $_.User -ne "SYSTEM"
}

# -----------------------------
# DETECTIONS
# -----------------------------

# 1. FILE WRITES
$FileWrites = $Parsed

# 2. HIGH VOLUME FILE ACTIVITY
$HighVolume = $Parsed | Group-Object User | Where-Object {
    $_.Count -ge 5
}

# -----------------------------
# TIMER END
# -----------------------------
$ScriptEnd = Get-Date
$RunTime = $ScriptEnd - $ScriptStart

# -----------------------------
# SUMMARY
# -----------------------------
Write-Host "========== FILE ACTIVITY SUMMARY ==========" -ForegroundColor Yellow
Write-Host "Total Suspicious File Events: $($FileWrites.Count)"
Write-Host "High Volume File Activity: $($HighVolume.Count)"
Write-Host "Total Time Run: $RunTime"
Write-Host "==========================================="

# -----------------------------
# DETAILS
# -----------------------------
if ($FileWrites) {
    Write-Host "`n[!] FILE WRITE / CREATE EVENTS" -ForegroundColor Red
    $FileWrites | Format-Table TimeCreated, User, ObjectName -AutoSize
}

if ($HighVolume) {
    Write-Host "`n[!] HIGH VOLUME FILE ACTIVITY" -ForegroundColor Red
    foreach ($group in $HighVolume) {
        Write-Host "User: $($group.Name) Count: $($group.Count)"
    }
}

# -----------------------------
# EXPORT
# -----------------------------
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

$FileWrites | Export-Csv ".\FileActivity_$Timestamp.csv" -NoTypeInformation

Write-Host "`n[+] Report saved: FileActivity_$Timestamp.csv"
