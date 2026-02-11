param([int]$Days=7)

$ScriptStart=Get-Date
$TimeStamp=$ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile="priv_escalation_$TimeStamp.log"
$StartTime=(Get-Date).AddDays(-$Days)

$Events=Get-WinEvent -FilterHashtable @{
    LogName='Security'
    ID=4672,4728,4732,4720
    StartTime=$StartTime
}

$Parsed=foreach($Event in $Events){
    [PSCustomObject]@{
        TimeCreated=$Event.TimeCreated
        EventID=$Event.Id
        Message=$Event.Message.Substring(0,200)
    }
}

$ScriptEnd=Get-Date
$Duration=$ScriptEnd-$ScriptStart

"Privilege Escalation Tracker" | Out-File $OutputFile
"Total Events: $($Parsed.Count)" | Out-File $OutputFile -Append
"Duration: $Duration" | Out-File $OutputFile -Append
"----------------------------------------" | Out-File $OutputFile -Append

$Parsed | Tee-Object -FilePath $OutputFile -Append