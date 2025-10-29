
# Define the root registry path
$rootPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"

# Function to recursively enumerate through registry keys and values
function Get-RegistryValue {
    param (
        [string]$Path,
        [System.Collections.ArrayList]$Keys
    )

    # Get all subkeys under the current path
    $subkeys = Get-ChildItem -Path $Path

    foreach ($subkey in $subkeys) {
        # Add the full path to the key name
        $fullKeyPath = "$Path\$($subkey.Name)"
        
        try {
            # Retrieve the value of the Debugger entry for this subkey
            $debuggerValue = (Get-ItemProperty -Path $fullKeyPath).Debugger
            
            if ($debuggerValue) {
                # Print the key name and its associated Debugger string
                Write-Output "Key: $fullKeyPath, Debugger: $debuggerValue"
            } else {
                Write-Output "Key: $fullKeyPath, No Debugger entry found."
            }
        } catch {
            # Handle any errors that occur when accessing the registry key
            Write-Output "Error accessing key: $fullKeyPath"
        }

        # Recursively call Get-RegistryValue for each subkey to handle nested keys
        Get-RegistryValue -Path "$fullKeyPath" -Keys $Keys
    }
}

# Initialize an array list to hold the keys
$keys = New-Object System.Collections.ArrayList

# Call the function starting from the root registry path
Get-RegistryValue -Path $rootPath -Keys $keys
