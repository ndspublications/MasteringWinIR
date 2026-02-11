param(
    [int]$Days = 7,
    [int]$FailureThreshold = 5
)

$ScriptStart = Get-Date
$TimeStamp = $ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile = "rdp_bruteforce_$TimeStamp.log"
$StartTime = (Get-Date).AddDays(-$Days)

Write-Host "RDP Brute Force Hunt - Last $Days days"

$Events = Get-WinEvent -FilterHashtable @{
    LogName='Security'
    ID=4624,4625
    StartTime=$StartTime
} -ErrorAction SilentlyContinue

$Parsed = foreach ($Event in $Events) {
    $Xml = [xml]$Event.ToXml()
    $User = ($Xml.Event.EventData.Data | Where {$_.Name -eq "TargetUserName"}).'#text'
    $LogonType = ($Xml.Event.EventData.Data | Where {$_.Name -eq "LogonType"}).'#text'
    $Ip = ($Xml.Event.EventData.Data | Where {$_.Name -eq "IpAddress"}).'#text'

    if ($LogonType -eq "10") {
        [PSCustomObject]@{
            TimeCreated = $Event.TimeCreated
            EventID = $Event.Id
            User = $User
            IP = $Ip
        }
    }
}

$Failures = $Parsed | Where {$_.EventID -eq 4625}
$Grouped = $Failures | Group-Object IP | Where {$_.Count -ge $FailureThreshold}

$ScriptEnd = Get-Date
$Duration = $ScriptEnd - $ScriptStart

"RDP Brute Force Hunt" | Out-File $OutputFile
"Start: $ScriptStart" | Out-File $OutputFile -Append
"End:   $ScriptEnd" | Out-File $OutputFile -Append
"Duration: $Duration" | Out-File $OutputFile -Append
"Total RDP Failures: $($Failures.Count)" | Out-File $OutputFile -Append
"IPs Over Threshold: $($Grouped.Count)" | Out-File $OutputFile -Append
"------------------------------------------------" | Out-File $OutputFile -Append

$Grouped | Select Name,Count | Tee-Object -FilePath $OutputFile -Append

Write-Host "Completed: $OutputFile"