#DETECT RECON ATTEMPTS ON SMB SHARES
param (
    [int]$Days = 1,
    [datetime]$StartDate,
    [datetime]$EndDate = (Get-Date),
    [int]$Threshold = 3
)

if (-not $StartDate) {
    $StartDate = (Get-Date).AddDays(-$Days)
}

$ScriptStart = Get-Date

Write-Host "`n[+] SMB Recon Detection Running..." -ForegroundColor Cyan
Write-Host "Date Range: $StartDate -> $EndDate"
Write-Host "Threshold: $Threshold events per user/IP"
Write-Host ""

# -----------------------------
# PULL SMB EVENTS
# -----------------------------
$Events = Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    ID = 5140,5145
    StartTime = $StartDate
    EndTime = $EndDate
} -ErrorAction SilentlyContinue

# -----------------------------
# PARSE EVENTS
# -----------------------------
$Parsed = $Events | ForEach-Object {

    $event = $_
    $xml = [xml]$event.ToXml()

    $data = @{}
    foreach ($d in $xml.Event.EventData.Data) {
        $data[$d.Name] = $d.'#text'
    }

    $SourceIP = $data["IpAddress"]

    # Fix numeric IP issue
    if ($SourceIP -match "^\d+$") {
        try {
            $SourceIP = ([System.Net.IPAddress]$SourceIP).ToString()
        } catch {}
    }

    [PSCustomObject]@{
        TimeCreated = $event.TimeCreated
        EventID     = $event.Id
        User        = $data["SubjectUserName"]
        Share       = $data["ShareName"]
        File        = $data["RelativeTargetName"]
        SourceIP    = $SourceIP
        AccessMask  = $data["AccessMask"]
    }
}

# -----------------------------
# DETECTIONS
# -----------------------------

# 1. High Volume Recon
$HighVolumeGroups = $Parsed | Group-Object User, SourceIP | Where-Object {
    $_.Count -ge $Threshold
}

$HighVolumeDetails = foreach ($group in $HighVolumeGroups) {
    $group.Group
}

# 2. Admin Share Access
$AdminShares = $Parsed | Where-Object {
    $_.Share -match "C\$|ADMIN\$|IPC\$"
}

# 3. Anonymous Access
$Anonymous = $Parsed | Where-Object {
    $_.User -match "ANONYMOUS LOGON"
}

# 4. Share Enumeration (many unique shares)
$EnumerationGroups = $Parsed | Group-Object User | Where-Object {
    ($_.Group | Select-Object -ExpandProperty Share -Unique).Count -ge 5
}

$EnumerationDetails = foreach ($group in $EnumerationGroups) {
    $group.Group
}

# -----------------------------
# TIMER END
# -----------------------------
$ScriptEnd = Get-Date
$RunTime = $ScriptEnd - $ScriptStart

# -----------------------------
# SUMMARY
# -----------------------------
Write-Host "========== SMB RECON SUMMARY ==========" -ForegroundColor Yellow
Write-Host "Total Events Parsed: $($Parsed.Count)"
Write-Host "High Volume Recon Events: $($HighVolumeDetails.Count)"
Write-Host "Admin Share Access Events: $($AdminShares.Count)"
Write-Host "Anonymous Access Events: $($Anonymous.Count)"
Write-Host "Enumeration Events: $($EnumerationDetails.Count)"
Write-Host "Total Time Run: $RunTime"
Write-Host "======================================="

# -----------------------------
# DETAILED OUTPUT
# -----------------------------

if ($HighVolumeDetails) {
    Write-Host "`n[!] HIGH VOLUME RECON DETAILS" -ForegroundColor Red
    $HighVolumeDetails | Format-Table TimeCreated, User, SourceIP, Share -AutoSize
}

if ($AdminShares) {
    Write-Host "`n[!] ADMIN SHARE ACCESS DETAILS" -ForegroundColor Red
    $AdminShares | Format-Table TimeCreated, User, SourceIP, Share -AutoSize
}

if ($Anonymous) {
    Write-Host "`n[!] ANONYMOUS ACCESS DETAILS" -ForegroundColor Red
    $Anonymous | Format-Table TimeCreated, SourceIP, Share -AutoSize
}

if ($EnumerationDetails) {
    Write-Host "`n[!] SHARE ENUMERATION DETAILS" -ForegroundColor Red
    $EnumerationDetails | Format-Table TimeCreated, User, SourceIP, Share -AutoSize
}

# -----------------------------
# EXPORT FILES
# -----------------------------
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

$Parsed | Export-Csv ".\SMB_AllEvents_$Timestamp.csv" -NoTypeInformation
$HighVolumeDetails | Export-Csv ".\SMB_HighVolume_Details_$Timestamp.csv" -NoTypeInformation
$AdminShares | Export-Csv ".\SMB_AdminShare_Details_$Timestamp.csv" -NoTypeInformation
$Anonymous | Export-Csv ".\SMB_Anonymous_Details_$Timestamp.csv" -NoTypeInformation
$EnumerationDetails | Export-Csv ".\SMB_Enumeration_Details_$Timestamp.csv" -NoTypeInformation

Write-Host "`n[+] Detailed reports saved with timestamp: $Timestamp"
