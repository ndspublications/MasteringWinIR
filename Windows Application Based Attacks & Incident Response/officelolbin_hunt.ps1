# NOTE:
# Detects suspicious process execution (Event ID 4688)
# Focused on:
# - Office spawning shells (macro behavior)
# - LOLBins (PowerShell, CMD, MSHTA, etc.)
#
# Requires: Process Creation auditing enabled

param (
    [int]$Days,
    [datetime]$StartDate,
    [datetime]$EndDate = (Get-Date)
)

# -----------------------------
# INTERACTIVE MODE
# -----------------------------
if (-not $Days -and -not $StartDate) {

    Write-Host "==== Process Execution Hunt Options ====" -ForegroundColor Cyan

    $Days = Read-Host "How many days ago? (Default: 30)"
    if (-not $Days) { $Days = 30 }

    $StartDate = (Get-Date).AddDays(-[int]$Days)
}

# -----------------------------
# AUDIT POLICY CHECK
# -----------------------------
$AuditCheck = auditpol /get /subcategory:"Process Creation" 2>$null

if ($AuditCheck -notmatch "Success") {
    Write-Host "[WARNING] Process Creation auditing is NOT enabled." -ForegroundColor Red
    Write-Host "[WARNING] 4688 events may not be logged." -ForegroundColor Red
}

# -----------------------------
# DATE HANDLING
# -----------------------------
if (-not $StartDate) {
    $StartDate = (Get-Date).AddDays(-$Days)
}

$ScriptStart = Get-Date

Write-Host "`n[+] Process Execution Detector Running..." -ForegroundColor Cyan
Write-Host "Date Range: $StartDate -> $EndDate"
Write-Host ""

# -----------------------------
# TARGET PROCESSES
# -----------------------------
$OfficeParents = @(
    "WINWORD.EXE",
    "EXCEL.EXE",
    "OUTLOOK.EXE",
    "POWERPNT.EXE"
)

$SuspiciousChildren = @(
    "powershell.exe",
    "cmd.exe",
    "wscript.exe",
    "cscript.exe",
    "mshta.exe",
    "rundll32.exe",
    "regsvr32.exe"
)

# -----------------------------
# PULL EVENTS (4688)
# -----------------------------
$Events = Get-WinEvent -FilterHashtable @{
    LogName   = 'Security'
    ID        = 4688
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

    $Parent = $data["ParentProcessName"]
    $NewProc = $data["NewProcessName"]
    $User = $data["SubjectUserName"]
    $CmdLine = $data["CommandLine"]

    if (-not $Parent -or -not $NewProc) { return }

    $ParentName = [System.IO.Path]::GetFileName($Parent)
    $ChildName  = [System.IO.Path]::GetFileName($NewProc)

    [PSCustomObject]@{
        TimeCreated = $_.TimeCreated
        User        = $User
        Parent      = $ParentName
        Child       = $ChildName
        CommandLine = $CmdLine
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

# 1. Office spawning suspicious processes
$OfficeAbuse = $Parsed | Where-Object {
    ($OfficeParents -contains $_.Parent.ToUpper()) -and
    ($SuspiciousChildren -contains $_.Child.ToLower())
}

# 2. Suspicious process execution (LOLBins)
$SuspiciousExec = $Parsed | Where-Object {
    $SuspiciousChildren -contains $_.Child.ToLower()
}

# -----------------------------
# TIMER END
# -----------------------------
$ScriptEnd = Get-Date
$RunTime = $ScriptEnd - $ScriptStart

# -----------------------------
# SUMMARY
# -----------------------------
Write-Host "========== PROCESS EXECUTION SUMMARY ==========" -ForegroundColor Yellow
Write-Host "Total Processes Parsed: $($Parsed.Count)"
Write-Host "Office Abuse Events: $($OfficeAbuse.Count)"
Write-Host "Suspicious Executions: $($SuspiciousExec.Count)"
Write-Host "Number of Days: $Days"
Write-Host "Total Time Run: $RunTime"
Write-Host "==============================================="

# -----------------------------
# DETAILS
# -----------------------------
if ($OfficeAbuse) {
    Write-Host "`n[!] OFFICE → SHELL EXECUTION (MACRO BEHAVIOR)" -ForegroundColor Red
    $OfficeAbuse | Format-Table TimeCreated, User, Parent, Child -AutoSize
}

if ($SuspiciousExec) {
    Write-Host "`n[!] SUSPICIOUS PROCESS EXECUTION" -ForegroundColor Red
    $SuspiciousExec | Format-Table TimeCreated, User, Parent, Child -AutoSize
}

# -----------------------------
# EXPORT
# -----------------------------
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

$Parsed | Export-Csv ".\ProcessExecution_$Timestamp.csv" -NoTypeInformation

Write-Host "`n[+] Report saved: ProcessExecution_$Timestamp.csv"
