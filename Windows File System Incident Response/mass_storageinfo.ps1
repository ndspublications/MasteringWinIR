

param (
    [datetime]$StartTime,
    [datetime]$EndTime
)

$ScriptStart = Get-Date

Write-Host "Starting mounted device enumeration..."
Write-Host "Script started at: $ScriptStart"
Write-Host "--------------------------------------------"

$Results = @()

# USB Storage Devices (USBSTOR)
$USBStorPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR"

if (Test-Path $USBStorPath) {
    Get-ChildItem $USBStorPath | ForEach-Object {

        $DeviceType = $_.PSChildName

        Get-ChildItem $_.PSPath | ForEach-Object {

            $DeviceInstance = $_.PSChildName
            $DeviceKey = $_.PSPath

            try {
                $Props = Get-ItemProperty -Path $DeviceKey
                $LastWrite = (Get-Item $DeviceKey).LastWriteTime

                # Time Filtering
                if ($StartTime -and $LastWrite -lt $StartTime) { return }
                if ($EndTime -and $LastWrite -gt $EndTime) { return }

                $Results += [PSCustomObject]@{
                    DeviceType      = $DeviceType
                    DeviceInstance  = $DeviceInstance
                    FriendlyName    = $Props.FriendlyName
                    Manufacturer    = $Props.Mfg
                    SerialNumber    = $DeviceInstance
                    RegistryPath    = $DeviceKey
                    LastWriteTime   = $LastWrite
                }
            }
            catch {}
        }
    }
}

# Mounted Devices Key (Drive Letters & Volume GUIDs)
$MountedDevicesPath = "HKLM:\SYSTEM\MountedDevices"

if (Test-Path $MountedDevicesPath) {
    $MountedDevices = Get-ItemProperty -Path $MountedDevicesPath

    foreach ($Property in $MountedDevices.PSObject.Properties) {
        if ($Property.Name -like "\DosDevices\*" -or $Property.Name -like "\??\Volume*") {

            $LastWrite = (Get-Item $MountedDevicesPath).LastWriteTime

            if ($StartTime -and $LastWrite -lt $StartTime) { continue }
            if ($EndTime -and $LastWrite -gt $EndTime) { continue }

            $Results += [PSCustomObject]@{
                DeviceType      = "MountedDevice"
                DeviceInstance  = $Property.Name
                FriendlyName    = ""
                Manufacturer    = ""
                SerialNumber    = ""
                RegistryPath    = $MountedDevicesPath
                LastWriteTime   = $LastWrite
            }
        }
    }
}

$ScriptEnd = Get-Date
$Elapsed = $ScriptEnd - $ScriptStart

Write-Host "--------------------------------------------"
Write-Host "Script completed at: $ScriptEnd"
Write-Host "Elapsed Time: $($Elapsed.ToString())"
Write-Host "Total Entries Found: $($Results.Count)"
Write-Host "--------------------------------------------"

$Results | Sort-Object LastWriteTime | Format-Table -AutoSize
