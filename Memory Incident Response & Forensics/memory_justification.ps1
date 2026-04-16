# Mastering Windows Incident Response
# Author: Anthony Valente
# Company: Network Defense Solutions, Inc.
# For Educational Use Only
# Memory Acquisition Justification Script
# REQUIRES dumpit.exe
# ----------------------------
# Initialize
# ----------------------------

$StartTime = Get-Date
$Timestamp = $StartTime.ToString("yyyyMMdd_HHmmss")
$LogFile = "${Timestamp}_memory_justification.log"

$DaysBack = 3
$Cutoff = (Get-Date).AddDays(-$DaysBack)

$EventCount = 0


$DumpItPath = ".\dumpit.exe"

if (Test-Path $DumpItPath) {
    "DumpIt Status: FOUND at $DumpItPath" | Out-File $LogFile -Append
    Write-Host "DumpIt located."
}
else {
    "DumpIt Status: NOT FOUND in current directory." | Out-File $LogFile -Append
    Write-Host "WARNING: DumpIt not found in current directory."
}

"========== MEMORY ACQUISITION JUSTIFICATION ==========" | Out-File $LogFile
"Script Start Time: $StartTime" | Out-File $LogFile -Append
"Days Back Reviewed: $DaysBack" | Out-File $LogFile -Append
"------------------------------------------------------" | Out-File $LogFile -Append

# ----------------------------
# System Information
# ----------------------------

$Hostname = $env:COMPUTERNAME
$CurrentUser = whoami
$BootTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$Uptime = (Get-Date) - $BootTime
$RAM = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB

"Hostname: $Hostname" | Out-File $LogFile -Append
"Current User: $CurrentUser" | Out-File $LogFile -Append
"Last Boot Time: $BootTime" | Out-File $LogFile -Append
"System Uptime (Hours): $([math]::Round($Uptime.TotalHours,2))" | Out-File $LogFile -Append
"Installed RAM (GB): $([math]::Round($RAM,2))" | Out-File $LogFile -Append
"------------------------------------------------------" | Out-File $LogFile -Append

# ----------------------------
# Recent Suspicious Activity Check
# ----------------------------

"Recent Security Events (4688, 4624, 7045, 4698):" | Out-File $LogFile -Append

$Events = Get-WinEvent -FilterHashtable @{
    LogName='Security'
    ID=@(4688,4624,7045,4698)
    StartTime=$Cutoff
} -ErrorAction SilentlyContinue

foreach ($Event in $Events) {
    $EventCount++
}

"Total Relevant Events in Last $DaysBack Days: $EventCount" | Out-File $LogFile -Append
"------------------------------------------------------" | Out-File $LogFile -Append

# ----------------------------
# Justification Logic
# ----------------------------

$Recommendation = ""

if ($Uptime.TotalHours -lt 2) {
    $Recommendation = "LOW VALUE: System recently rebooted. Memory artifacts likely minimal."
}
elseif ($EventCount -eq 0) {
    $Recommendation = "LOW VALUE: No recent high-interest security events detected."
}
elseif ($EventCount -gt 0 -and $Uptime.TotalHours -gt 2) {
    $Recommendation = "HIGH VALUE: System active with relevant events. Memory capture recommended."
}
else {
    $Recommendation = "MANUAL REVIEW REQUIRED."
}

"Recommendation: $Recommendation" | Out-File $LogFile -Append

# ----------------------------
# Completion
# ----------------------------

$EndTime = Get-Date
$Duration = New-TimeSpan -Start $StartTime -End $EndTime

"======================================================" | Out-File $LogFile -Append
"Script End Time: $EndTime" | Out-File $LogFile -Append
"Duration: $($Duration.ToString())" | Out-File $LogFile -Append
"Events Reviewed: $EventCount" | Out-File $LogFile -Append
"======================================================" | Out-File $LogFile -Append

Write-Host "-------------------------------------"
Write-Host "Memory Justification Complete"
Write-Host "Start Time : $StartTime"
Write-Host "End Time   : $EndTime"
Write-Host "Duration   : $Duration"
Write-Host "Events Found: $EventCount"
Write-Host "Recommendation: $Recommendation"
Write-Host "Log File   : $LogFile"
Write-Host "-------------------------------------"
