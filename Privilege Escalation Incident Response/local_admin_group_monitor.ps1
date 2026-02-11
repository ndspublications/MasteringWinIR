param(
    [int]$Days = 30
)

$StartTime = Get-Date
$Timestamp = $StartTime.ToString("yyyyMMddHHmmss")
$LogFile = "local_admin_group_monitor_$Timestamp.log"

Write-Output "=== Local Admin Group Monitor ===" | Tee-Object $LogFile
Write-Output "Start Time: $StartTime" | Tee-Object $LogFile -Append

$Events = Get-WinEvent -FilterHashtable @{
    LogName='Security'
    ID=4732,4720
    StartTime=(Get-Date).AddDays(-$Days)
}

$Events | Select TimeCreated, Id, Message | Tee-Object $LogFile -Append

$Count = $Events.Count
$EndTime = Get-Date
$Duration = $EndTime - $StartTime

Write-Output "Total Findings: $Count" | Tee-Object $LogFile -Append
Write-Output "Duration: $Duration" | Tee-Object $LogFile -Append