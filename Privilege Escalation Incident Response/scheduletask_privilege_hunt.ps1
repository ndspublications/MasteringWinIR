param(
    [int]$Days = 30
)

$StartTime = Get-Date
$Timestamp = $StartTime.ToString("yyyyMMddHHmmss")
$LogFile = "scheduled_task_privilege_hunt_$Timestamp.log"

Write-Output "=== Scheduled Task Privilege Hunt ===" | Tee-Object $LogFile
Write-Output "Start Time: $StartTime" | Tee-Object $LogFile -Append

$Tasks = Get-ScheduledTask | Where-Object {
    $_.Principal.UserId -match "SYSTEM|Administrator" -or
    $_.Principal.RunLevel -eq "Highest"
}

$Findings = @()

foreach ($Task in $Tasks) {
    $ActionPath = $Task.Actions.Execute
    $Hash = $null
    if (Test-Path $ActionPath) {
        $Hash = (Get-FileHash $ActionPath -Algorithm SHA256).Hash
    }

    $Findings += [PSCustomObject]@{
        TaskName = $Task.TaskName
        User     = $Task.Principal.UserId
        RunLevel = $Task.Principal.RunLevel
        Action   = $ActionPath
        SHA256   = $Hash
    }
}

$Findings | Tee-Object $LogFile -Append

$EndTime = Get-Date
$Duration = $EndTime - $StartTime
$Count = $Findings.Count

Write-Output "Total Findings: $Count" | Tee-Object $LogFile -Append
Write-Output "Duration: $Duration" | Tee-Object $LogFile -Append