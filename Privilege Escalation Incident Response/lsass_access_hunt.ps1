param(
    [int]$Days = 30
)

$StartTime = Get-Date
$Timestamp = $StartTime.ToString("yyyyMMddHHmmss")
$LogFile = "lsass_access_hunt_$Timestamp.log"

Write-Output "=== LSASS Access Hunt ===" | Tee-Object $LogFile
Write-Output "Start Time: $StartTime" | Tee-Object $LogFile -Append

$Events = Get-WinEvent -FilterHashtable @{
    LogName='Microsoft-Windows-Sysmon/Operational'
    ID=10
    StartTime=(Get-Date).AddDays(-$Days)
} | Where-Object { $_.Message -match "lsass.exe" }

$Events | Select TimeCreated, Message | Tee-Object $LogFile -Append

$Count = $Events.Count
$EndTime = Get-Date
$Duration = $EndTime - $StartTime

Write-Output "Total Findings: $Count" | Tee-Object $LogFile -Append
Write-Output "Duration: $Duration" | Tee-Object $LogFile -Append