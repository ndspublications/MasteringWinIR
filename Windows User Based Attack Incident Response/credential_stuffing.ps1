param(
    [int]$Days = 7
)

$ScriptStart = Get-Date
$TimeStamp = $ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile = "credential_stuffing_$TimeStamp.log"
$StartTime = (Get-Date).AddDays(-$Days)

Write-Host "Starting Credential Stuffing Hunt..."
Write-Host "Timeframe: Last $Days days"

$Events = Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    ID = 4625,4624,4740
    StartTime = $StartTime
} -ErrorAction SilentlyContinue

$Failed = $Events | Where-Object {$_.Id -eq 4625}
$Success = $Events | Where-Object {$_.Id -eq 4624}
$Lockouts = $Events | Where-Object {$_.Id -eq 4740}

$GroupedFailures = $Failed | Group-Object {
    ($_ | Select-String "Account Name").Line
}

$ScriptEnd = Get-Date
$Duration = $ScriptEnd - $ScriptStart

# Output
"Credential Stuffing Hunt" | Out-File $OutputFile
"Start Time: $ScriptStart" | Out-File $OutputFile -Append
"End Time:   $ScriptEnd" | Out-File $OutputFile -Append
"Duration:   $Duration" | Out-File $OutputFile -Append
"Total Events: $($Events.Count)" | Out-File $OutputFile -Append
"Failed Logons: $($Failed.Count)" | Out-File $OutputFile -Append
"Successful Logons: $($Success.Count)" | Out-File $OutputFile -Append
"Lockouts: $($Lockouts.Count)" | Out-File $OutputFile -Append
"--------------------------------------------------" | Out-File $OutputFile -Append

$GroupedFailures | Sort-Object Count -Descending | 
Select-Object Name,Count | 
Format-Table -AutoSize | Out-File $OutputFile -Append

Write-Host "Completed. Output written to $OutputFile"