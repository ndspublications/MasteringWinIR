param(
    [int]$Days = 7
)

$ScriptStart = Get-Date
$TimeStamp = $ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile = "nullsession_hunt_$TimeStamp.log"
$StartTime = (Get-Date).AddDays(-$Days)

Write-Host "Starting Null Session Hunt..."
Write-Host "Timeframe: Last $Days days"

$Events = Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    ID = 4624,4625,5140
    StartTime = $StartTime
} -ErrorAction SilentlyContinue

$AnonymousLogons = $Events | Where-Object {
    $_.Message -match "ANONYMOUS LOGON"
}

$IPCShareAccess = $Events | Where-Object {
    $_.Message -match "IPC\$"
}

$ScriptEnd = Get-Date
$Duration = $ScriptEnd - $ScriptStart

"Null Session Hunt" | Out-File $OutputFile
"Start Time: $ScriptStart" | Out-File $OutputFile -Append
"End Time:   $ScriptEnd" | Out-File $OutputFile -Append
"Duration:   $Duration" | Out-File $OutputFile -Append
"Anonymous Logons Found: $($AnonymousLogons.Count)" | Out-File $OutputFile -Append
"IPC$ Access Events: $($IPCShareAccess.Count)" | Out-File $OutputFile -Append
"--------------------------------------------------" | Out-File $OutputFile -Append

$AnonymousLogons | Select-Object TimeCreated, Id |
Format-Table -AutoSize | Out-File $OutputFile -Append

Write-Host "Completed. Output written to $OutputFile"