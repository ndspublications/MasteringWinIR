$ScriptStart = Get-Date
$TimeStamp   = $ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile  = "wireless_history_$TimeStamp.log"

Write-Host "Wireless & Bluetooth History Collection"
Write-Host "--------------------------------------------"

# -----------------------
# WIFI PROFILES
# -----------------------
$WifiProfiles = @()
$ProfileList = netsh wlan show profiles 2>$null

foreach ($Line in $ProfileList) {
    if ($Line -match "All User Profile") {
        $SSID = ($Line -split ":")[1].Trim()

        $ProfileDetails = netsh wlan show profile name="$SSID" 2>$null

        $Auth  = ($ProfileDetails | Select-String "Authentication").ToString().Split(":")[1].Trim()
        $Cipher = ($ProfileDetails | Select-String "Cipher").ToString().Split(":")[1].Trim()
        $ConnMode = ($ProfileDetails | Select-String "Connection mode").ToString().Split(":")[1].Trim()

        $WifiProfiles += [PSCustomObject]@{
            SSID           = $SSID
            Authentication = $Auth
            Encryption     = $Cipher
            ConnectionMode = $ConnMode
        }
    }
}

# Currently connected network
$CurrentConnection = netsh wlan show interfaces 2>$null |
    Select-String "SSID" |
    Select-Object -First 1

# -----------------------
# BLUETOOTH DEVICES
# -----------------------
$BluetoothDevices = @()

$BTRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Devices"

if (Test-Path $BTRegPath) {

    $Devices = Get-ChildItem $BTRegPath -ErrorAction SilentlyContinue

    foreach ($Device in $Devices) {

        $Props = Get-ItemProperty $Device.PSPath -ErrorAction SilentlyContinue

        $BluetoothDevices += [PSCustomObject]@{
            DeviceMAC   = $Device.PSChildName
            DeviceName  = $Props.Name
            LastUpdated = $Device.LastWriteTime
        }
    }
}

$ScriptEnd = Get-Date
$Elapsed   = $ScriptEnd - $ScriptStart

# -----------------------
# OUTPUT
# -----------------------

$Summary = @"
Wireless & Bluetooth Investigation Report
--------------------------------------------
Script Start: $ScriptStart
Script End:   $ScriptEnd
Elapsed Time: $Elapsed

Total WiFi Profiles Found: $($WifiProfiles.Count)
Total Bluetooth Devices Found: $($BluetoothDevices.Count)
--------------------------------------------
"@

Write-Host $Summary
$Summary | Out-File $OutputFile

# WiFi Output
Write-Host "`n--- WiFi Profiles ---`n"

foreach ($Wifi in $WifiProfiles) {

@"
SSID:           $($Wifi.SSID)
Authentication: $($Wifi.Authentication)
Encryption:     $($Wifi.Encryption)
ConnectionMode: $($Wifi.ConnectionMode)
------------------------------------------------------------
"@ | Tee-Object -FilePath $OutputFile -Append
}

# Current Connection
if ($CurrentConnection) {
    "`nCurrently Connected: $($CurrentConnection.ToString())" |
        Tee-Object -FilePath $OutputFile -Append
}

# Bluetooth Output
Write-Host "`n--- Bluetooth Devices ---`n"

foreach ($BT in $BluetoothDevices) {

@"
Device MAC:   $($BT.DeviceMAC)
Device Name:  $($BT.DeviceName)
Last Updated: $($BT.LastUpdated)
------------------------------------------------------------
"@ | Tee-Object -FilePath $OutputFile -Append
}

Write-Host "`nResults written to $OutputFile"