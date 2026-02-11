param(
    [int]$Days = 7
)

$ScriptStart = Get-Date
$TimeStamp = $ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile = "logontype3_hunt_$TimeStamp.log"
$StartTime = (Get-Date).AddDays(-$Days)

Write-Host "Starting LogonType 3 Hunt..."
Write-Host "Timeframe: Last $Days days"

$Events = Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    ID = 4624
    StartTime = $StartTime
} -ErrorAction SilentlyContinue

$NetworkLogons = $Events | Where-Object {
    $_.Properties[8].Value -eq 3
}

$GroupedByUser = $NetworkLogons | Group-Object {
    $_.Properties[5].Value
}

$ScriptEnd = Get-Date
$Duration = $ScriptEnd - $ScriptStart

"LogonType 3 Hunt" | Out-File $OutputFile
"Start Time: $ScriptStart" | Out-File $OutputFile -Append
"End Time:   $ScriptEnd" | Out-File $OutputFile -Append
"Duration:   $Duration" | Out-File $OutputFile -Append
"Total Network Logons: $($NetworkLogons.Count)" | Out-File $OutputFile -Append
"--------------------------------------------------" | Out-File $OutputFile -Append

$GroupedByUser | Sort-Object Count -Descending |
Select-Object Name,Count |
Format-Table -AutoSize | Out-File $OutputFile -Append

Write-Host "Completed. Output written to $OutputFile"