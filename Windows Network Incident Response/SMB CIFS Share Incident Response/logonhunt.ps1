param (
    [int]$Days = 1,
    [datetime]$StartDate,
    [datetime]$EndDate = (Get-Date),
    [int]$Threshold = 5
)

if (-not $StartDate) {
    $StartDate = (Get-Date).AddDays(-$Days)
}

$ScriptStart = Get-Date

Write-Host "`n[+] Logon Analyzer Running..." -ForegroundColor Cyan
Write-Host "Date Range: $StartDate -> $EndDate"
Write-Host "Threshold: $Threshold"
Write-Host ""

# -----------------------------
# GET LOGONS (4624)
# -----------------------------
$Logons = Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    ID = 4624
    StartTime = $StartDate
    EndTime = $EndDate
} -ErrorAction SilentlyContinue | ForEach-Object {

    $xml = [xml]$_.ToXml()
    $data = @{}
    foreach ($d in $xml.Event.EventData.Data) {
        $data[$d.Name] = $d.'#text'
    }

    [PSCustomObject]@{
        TimeCreated = $_.TimeCreated
        User        = $data["TargetUserName"]
        Domain      = $data["TargetDomainName"]
        LogonType   = [int]$data["LogonType"]
        SourceIP    = $data["IpAddress"]
    }
}

# -----------------------------
# GET FAILED LOGONS (4625)
# -----------------------------
$Failed = Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    ID = 4625
    StartTime = $StartDate
    EndTime = $EndDate
} -ErrorAction SilentlyContinue | ForEach-Object {

    $xml = [xml]$_.ToXml()
    $data = @{}
    foreach ($d in $xml.Event.EventData.Data) {
        $data[$d.Name] = $d.'#text'
    }

    [PSCustomObject]@{
        TimeCreated = $_.TimeCreated
        User        = $data["TargetUserName"]
        SourceIP    = $data["IpAddress"]
    }
}

# -----------------------------
# CLEAN DATA (REMOVE NOISE)
# -----------------------------
$Logons = $Logons | Where-Object {
    $_.User -and
    $_.User -notmatch "\$$" -and
    $_.User -ne "SYSTEM" -and
    $_.SourceIP -ne "::1" -and
    $_.SourceIP -ne "127.0.0.1"
}

# -----------------------------
# DETECTIONS
# -----------------------------

# 1. HIGH VOLUME LOGONS
$HighVolume = $Logons | Group-Object User, SourceIP | Where-Object {
    $_.Count -ge $Threshold
}

# 2. MULTIPLE IPS PER USER
$MultiIP = $Logons | Group-Object User | Where-Object {
    ($_.Group | Select-Object -ExpandProperty SourceIP -Unique).Count -ge 2
}

# 3. REMOTE LOGONS (NETWORK + RDP)
$Remote = $Logons | Where-Object {
    $_.LogonType -eq 3 -or $_.LogonType -eq 10
}

# 4. FAILED LOGON SPIKES
$FailedGroups = $Failed | Group-Object SourceIP | Where-Object {
    $_.Count -ge $Threshold
}

# -----------------------------
# TIMER END
# -----------------------------
$ScriptEnd = Get-Date
$RunTime = $ScriptEnd - $ScriptStart

# -----------------------------
# SUMMARY
# -----------------------------
Write-Host "========== LOGON ANALYSIS ==========" -ForegroundColor Yellow
Write-Host "Total Logons: $($Logons.Count)"
Write-Host "High Volume Logons: $($HighVolume.Count)"
Write-Host "Multi-IP Users: $($MultiIP.Count)"
Write-Host "Remote Logons: $($Remote.Count)"
Write-Host "Failed Logon Sources: $($FailedGroups.Count)"
Write-Host "Total Time Run: $RunTime"
Write-Host "===================================="

# -----------------------------
# DETAILS
# -----------------------------
if ($HighVolume) {
    Write-Host "`n[!] HIGH VOLUME LOGONS" -ForegroundColor Red
    $HighVolume | ForEach-Object {
        Write-Host "User/IP: $($_.Name) Count: $($_.Count)"
    }
}

if ($MultiIP) {
    Write-Host "`n[!] MULTIPLE IPs PER USER" -ForegroundColor Red
    foreach ($group in $MultiIP) {
        $ips = $group.Group | Select -Expand SourceIP -Unique
        Write-Host "User: $($group.Name) IPs: $($ips -join ', ')"
    }
}

if ($Remote) {
    Write-Host "`n[!] REMOTE LOGONS (Type 3 / 10)" -ForegroundColor Red
    $Remote | Format-Table TimeCreated, User, SourceIP, LogonType -AutoSize
}

if ($FailedGroups) {
    Write-Host "`n[!] FAILED LOGON SPIKES" -ForegroundColor Red
    foreach ($group in $FailedGroups) {
        Write-Host "Source IP: $($group.Name) Attempts: $($group.Count)"
    }
}

# -----------------------------
# EXPORT
# -----------------------------
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

$Logons | Export-Csv ".\Logons_$Timestamp.csv" -NoTypeInformation
$Failed | Export-Csv ".\FailedLogons_$Timestamp.csv" -NoTypeInformation

Write-Host "`n[+] Reports saved with timestamp: $Timestamp"
