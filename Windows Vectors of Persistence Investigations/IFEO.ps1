# Define the root registry path
$rootPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"

function Get-RegistryValue {
    param (
        [string]$Path
    )

    try {
        $subkeys = Get-ChildItem -Path $Path -ErrorAction Stop
    } catch {
        Write-Warning "Error accessing path: $Path"
        return
    }

    foreach ($subkey in $subkeys) {
        $fullKeyPath = $subkey.PSPath

        try {
            $props = Get-ItemProperty -Path $fullKeyPath -ErrorAction Stop
            if ($props.PSObject.Properties.Name -contains 'Debugger') {
                Write-Output "Key: $fullKeyPath, Debugger: $($props.Debugger)"
            }
        } catch {
            Write-Warning "Error reading key: $fullKeyPath"
        }

        # Recursive call
        Get-RegistryValue -Path $fullKeyPath
    }
}

# Run as Administrator
Get-RegistryValue -Path $rootPath
