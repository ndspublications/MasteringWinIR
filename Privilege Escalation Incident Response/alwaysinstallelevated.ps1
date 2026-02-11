param(
    [int]$Days = 30
)

$StartTime = Get-Date
$Timestamp = $StartTime.ToString("yyyyMMddHHmmss")
$LogFile = "alwaysinstallelevated_check_$Timestamp.log"

Write-Output "=== AlwaysInstallElevated Check ===" | Tee-Object $LogFile
Write-Output "Start Time: $StartTime" | Tee-Object $LogFile -Append

$HKLM = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -ErrorAction SilentlyContinue
$HKCU = Get-ItemProperty -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" -ErrorAction SilentlyContinue

$HKLMValue = $HKLM.AlwaysInstallElevated
$HKCUValue = $HKCU.AlwaysInstallElevated

$result = [PSCustomObject]@{
    HKLM_Value = $HKLMValue
    HKCU_Value = $HKCUValue
    Vulnerable = ($HKLMValue -eq 1 -and $HKCUValue -eq 1)
}

$result | Tee-Object $LogFile -Append

$EndTime = Get-Date
$Duration = $EndTime - $StartTime

Write-Output "End Time: $EndTime" | Tee-Object $LogFile -Append
Write-Output "Duration: $Duration" | Tee-Object $LogFile -Append