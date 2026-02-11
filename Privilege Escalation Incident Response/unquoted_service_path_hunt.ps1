param(
    [int]$Days = 30
)

$StartTime = Get-Date
$Timestamp = $StartTime.ToString("yyyyMMddHHmmss")
$LogFile = "unquoted_service_path_hunt_$Timestamp.log"

Write-Output "=== Unquoted Service Path Hunt ===" | Tee-Object -FilePath $LogFile
Write-Output "Start Time: $StartTime" | Tee-Object -FilePath $LogFile -Append
Write-Output "Days Parameter: $Days" | Tee-Object -FilePath $LogFile -Append
Write-Output "" | Tee-Object -FilePath $LogFile -Append

$Findings = @()

Get-WmiObject Win32_Service | ForEach-Object {
    $Path = $_.PathName
    if ($Path -and $Path -match " " -and $Path -notmatch '"') {
        $CleanPath = $Path.Split(".exe")[0] + ".exe"
        $Exists = Test-Path $CleanPath
        $Hash = $null
        if ($Exists) {
            $Hash = (Get-FileHash $CleanPath -Algorithm SHA256).Hash
        }

        $Findings += [PSCustomObject]@{
            ServiceName = $_.Name
            DisplayName = $_.DisplayName
            Path        = $Path
            FileExists  = $Exists
            SHA256      = $Hash
        }
    }
}

$Count = $Findings.Count
$Findings | Tee-Object -FilePath $LogFile -Append

$EndTime = Get-Date
$Duration = $EndTime - $StartTime

Write-Output "" | Tee-Object -FilePath $LogFile -Append
Write-Output "Total Findings: $Count" | Tee-Object -FilePath $LogFile -Append
Write-Output "End Time: $EndTime" | Tee-Object -FilePath $LogFile -Append
Write-Output "Duration: $Duration" | Tee-Object -FilePath $LogFile -Append