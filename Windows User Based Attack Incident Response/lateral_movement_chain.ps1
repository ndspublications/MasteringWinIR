param([int]$Days=7)

$ScriptStart = Get-Date
$TimeStamp = $ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile = "lateral_chain_$TimeStamp.log"
$StartTime = (Get-Date).AddDays(-$Days)

$Events = Get-WinEvent -FilterHashtable @{
    LogName='Security'
    ID=4624,4648,4672
    StartTime=$StartTime
}

$Parsed = foreach ($Event in $Events) {
    $Xml = [xml]$Event.ToXml()
    $User = ($Xml.Event.EventData.Data | Where {$_.Name -eq "TargetUserName"}).'#text'
    $LogonType = ($Xml.Event.EventData.Data | Where {$_.Name -eq "LogonType"}).'#text'

    [PSCustomObject]@{
        TimeCreated=$Event.TimeCreated
        EventID=$Event.Id
        User=$User
        LogonType=$LogonType
    }
}

$ScriptEnd = Get-Date
$Duration = $ScriptEnd - $ScriptStart

"Lateral Movement Chain Hunt" | Out-File $OutputFile
"Duration: $Duration" | Out-File $OutputFile -Append
"Total Events: $($Parsed.Count)" | Out-File $OutputFile -Append
"----------------------------------------" | Out-File $OutputFile -Append

$Parsed | Sort TimeCreated | Tee-Object -FilePath $OutputFile -Append