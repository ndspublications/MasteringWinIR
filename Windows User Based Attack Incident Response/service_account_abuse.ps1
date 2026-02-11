param(
    [int]$Days = 7
)

$ScriptStart = Get-Date
$TimeStamp = $ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile = "service_account_abuse_$TimeStamp.log"
$StartTime = (Get-Date).AddDays(-$Days)

Write-Host "Service Account Abuse Hunt - Last $Days days"

$Events = Get-WinEvent -FilterHashtable @{
    LogName='Security'
    ID=4624
    StartTime=$StartTime
} -ErrorAction SilentlyContinue

$Suspicious = foreach ($Event in $Events) {
    $Xml = [xml]$Event.ToXml()
    $User = ($Xml.Event.EventData.Data | Where-Object {$_.Name -eq "TargetUserName"}).'#text'
    $LogonType = ($Xml.Event.EventData.Data | Where-Object {$_.Name -eq "LogonType"}).'#text'

    if ($User -match "svc|sql|service" -and $LogonType -in @("2","10","3")) {
        [PSCustomObject]@{
            TimeCreated = $Event.TimeCreated
            User = $User
            LogonType = $LogonType
        }
    }
}

$ScriptEnd = Get-Date
$Duration = $ScriptEnd - $ScriptStart

"Service Account Abuse Hunt" | Out-File $OutputFile
"Start Time: $ScriptStart" | Out-File $OutputFile -Append
"End Time:   $ScriptEnd" | Out-File $OutputFile -Append
"Duration:   $Duration" | Out-File $OutputFile -Append
"Suspicious Service Logons: $($Suspicious.Count)" | Out-File $OutputFile -Append
"------------------------------------------------" | Out-File $OutputFile -Append

$Suspicious | Format-Table -AutoSize | Tee-Object -FilePath $OutputFile -Append

Write-Host "Completed. Output: $OutputFile"