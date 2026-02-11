param(
    [int]$Days = 30
)

$StartTime = Get-Date
$Timestamp = $StartTime.ToString("yyyyMMddHHmmss")
$LogFile = "privilege_token_abuse_hunt_$Timestamp.log"

Write-Output "=== Privilege Token Abuse Hunt ===" | Tee-Object $LogFile
Write-Output "Start Time: $StartTime" | Tee-Object $LogFile -Append

$Events = Get-WinEvent -FilterHashtable @{
    LogName='Security'
    ID=4672,4673,4674
    StartTime=(Get-Date).AddDays(-$Days)
}

$Events | Select TimeCreated, Id, Message | Tee-Object $LogFile -Append

$Count = $Events.Count
$EndTime = Get-Date
$Duration = $EndTime - $StartTime

Write-Output "Total Findings: $Count" | Tee-Object $LogFile -Append
Write-Output "Duration: $Duration" | Tee-Object $LogFile -Append