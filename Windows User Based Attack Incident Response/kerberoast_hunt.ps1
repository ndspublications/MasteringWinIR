param(
    [int]$Days = 7,
    [int]$Threshold = 10
)

$ScriptStart = Get-Date
$TimeStamp = $ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile = "kerberoast_hunt_$TimeStamp.log"
$StartTime = (Get-Date).AddDays(-$Days)

Write-Host "Kerberoast Hunt - Last $Days days"

$Events = Get-WinEvent -FilterHashtable @{
    LogName='Security'
    ID=4769
    StartTime=$StartTime
} -ErrorAction SilentlyContinue

$Parsed = foreach ($Event in $Events) {
    $Xml = [xml]$Event.ToXml()
    $User = ($Xml.Event.EventData.Data | Where-Object {$_.Name -eq "TargetUserName"}).'#text'
    $Service = ($Xml.Event.EventData.Data | Where-Object {$_.Name -eq "ServiceName"}).'#text'
    [PSCustomObject]@{
        TimeCreated = $Event.TimeCreated
        User = $User
        Service = $Service
    }
}

$Grouped = $Parsed | Group-Object User | Where-Object {$_.Count -ge $Threshold}

$ScriptEnd = Get-Date
$Duration = $ScriptEnd - $ScriptStart

"Kerberoast Hunt" | Out-File $OutputFile
"Start Time: $ScriptStart" | Out-File $OutputFile -Append
"End Time:   $ScriptEnd" | Out-File $OutputFile -Append
"Duration:   $Duration" | Out-File $OutputFile -Append
"Total 4769 Events: $($Events.Count)" | Out-File $OutputFile -Append
"Accounts Over Threshold ($Threshold): $($Grouped.Count)" | Out-File $OutputFile -Append
"------------------------------------------------" | Out-File $OutputFile -Append

$Grouped | Select Name,Count | Format-Table -AutoSize | Tee-Object -FilePath $OutputFile -Append

Write-Host "Completed. Output: $OutputFile"