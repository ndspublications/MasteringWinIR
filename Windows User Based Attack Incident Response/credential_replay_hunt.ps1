param(
    [int]$Days = 7
)

$ScriptStart = Get-Date
$TimeStamp = $ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile = "explicit_creds_hunt_$TimeStamp.log"
$StartTime = (Get-Date).AddDays(-$Days)

Write-Host "Explicit Credential Usage Hunt - Last $Days days"

$Events = Get-WinEvent -FilterHashtable @{
    LogName='Security'
    ID=4648
    StartTime=$StartTime
} -ErrorAction SilentlyContinue

$Parsed = foreach ($Event in $Events) {
    $Xml = [xml]$Event.ToXml()
    $User = ($Xml.Event.EventData.Data | Where-Object {$_.Name -eq "SubjectUserName"}).'#text'
    $Target = ($Xml.Event.EventData.Data | Where-Object {$_.Name -eq "TargetUserName"}).'#text'
    [PSCustomObject]@{
        TimeCreated = $Event.TimeCreated
        Caller = $User
        TargetAccount = $Target
    }
}

$ScriptEnd = Get-Date
$Duration = $ScriptEnd - $ScriptStart

"Explicit Credentials Hunt" | Out-File $OutputFile
"Start Time: $ScriptStart" | Out-File $OutputFile -Append
"End Time:   $ScriptEnd" | Out-File $OutputFile -Append
"Duration:   $Duration" | Out-File $OutputFile -Append
"Total 4648 Events: $($Parsed.Count)" | Out-File $OutputFile -Append
"------------------------------------------------" | Out-File $OutputFile -Append

$Parsed | Format-Table -AutoSize | Tee-Object -FilePath $OutputFile -Append

Write-Host "Completed. Output: $OutputFile"