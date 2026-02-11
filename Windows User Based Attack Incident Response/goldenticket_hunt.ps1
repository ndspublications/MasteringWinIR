param(
    [int]$Days = 7
)

$ScriptStart = Get-Date
$TimeStamp = $ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile = "golden_ticket_hunt_$TimeStamp.log"
$StartTime = (Get-Date).AddDays(-$Days)

Write-Host "Golden Ticket Hunt - Last $Days days"

$Logons = Get-WinEvent -FilterHashtable @{
    LogName='Security'
    ID=4624
    StartTime=$StartTime
} -ErrorAction SilentlyContinue

$TGTs = Get-WinEvent -FilterHashtable @{
    LogName='Security'
    ID=4768
    StartTime=$StartTime
} -ErrorAction SilentlyContinue

$TGTUsers = @()
foreach ($Event in $TGTs) {
    $Xml = [xml]$Event.ToXml()
    $User = ($Xml.Event.EventData.Data | Where-Object {$_.Name -eq "TargetUserName"}).'#text'
    $TGTUsers += $User
}

$Suspicious = foreach ($Event in $Logons) {
    $Xml = [xml]$Event.ToXml()
    $User = ($Xml.Event.EventData.Data | Where-Object {$_.Name -eq "TargetUserName"}).'#text'
    $LogonType = ($Xml.Event.EventData.Data | Where-Object {$_.Name -eq "LogonType"}).'#text'

    if ($LogonType -eq "3" -and $User -notin $TGTUsers) {
        [PSCustomObject]@{
            TimeCreated = $Event.TimeCreated
            User = $User
            LogonType = $LogonType
        }
    }
}

$ScriptEnd = Get-Date
$Duration = $ScriptEnd - $ScriptStart

"Golden Ticket Hunt" | Out-File $OutputFile
"Start Time: $ScriptStart" | Out-File $OutputFile -Append
"End Time:   $ScriptEnd" | Out-File $OutputFile -Append
"Duration:   $Duration" | Out-File $OutputFile -Append
"Suspicious Network Logons: $($Suspicious.Count)" | Out-File $OutputFile -Append
"------------------------------------------------" | Out-File $OutputFile -Append

$Suspicious | Format-Table -AutoSize | Tee-Object -FilePath $OutputFile -Append

Write-Host "Completed. Output: $OutputFile"