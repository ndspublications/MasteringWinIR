param([int]$Days=3)

$ScriptStart=Get-Date
$TimeStamp=$ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile="auth_timeline_$TimeStamp.log"
$StartTime=(Get-Date).AddDays(-$Days)

$Events=Get-WinEvent -FilterHashtable @{
    LogName='Security'
    ID=4624,4625,4634,4740
    StartTime=$StartTime
}

$Timeline=$Events | Sort TimeCreated | Select TimeCreated,Id,Message

$ScriptEnd=Get-Date
$Duration=$ScriptEnd-$ScriptStart

"Full Authentication Timeline" | Out-File $OutputFile
"Duration: $Duration" | Out-File $OutputFile -Append
"Total Events: $($Timeline.Count)" | Out-File $OutputFile -Append
"----------------------------------------" | Out-File $OutputFile -Append

$Timeline | Tee-Object -FilePath $OutputFile -Append