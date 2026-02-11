param (
    [ValidateSet("SHA256","SHA512","MD5","SHA1")]
    [string]$HashAlgorithm = "SHA256"
)

$ScriptStart = Get-Date
$TimeStamp   = $ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile  = "registry_persistence_$TimeStamp.log"

$Results = @()

# ---------------------------------
# Helper: Resolve Binary
# ---------------------------------
function Resolve-BinaryPath {
    param ($Command)

    if (-not $Command) { return $null }

    $Exe = $Command -replace '"',''
    $Exe = $Exe.Split(" ")[0]

    if (Test-Path $Exe) { return $Exe }

    $SearchPaths = @(
        "C:\Windows\$Exe",
        "C:\Windows\System32\$Exe",
        "C:\$Exe"
    )

    foreach ($Path in $SearchPaths) {
        if (Test-Path $Path) { return $Path }
    }

    return $null
}

# ---------------------------------
# Helper: Hash File
# ---------------------------------
function Get-FileHashSafe {
    param ($Path)

    try {
        return (Get-FileHash -Path $Path -Algorithm $HashAlgorithm -ErrorAction Stop).Hash
    }
    catch {
        return "Hash Failed"
    }
}

# ---------------------------------
# RUN KEYS
# ---------------------------------
$RunKeys = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
)

$RunCount = 0

foreach ($Key in $RunKeys) {

    if (Test-Path $Key) {

        $Entries = Get-ItemProperty $Key

        foreach ($Property in $Entries.PSObject.Properties | Where-Object { $_.MemberType -eq "NoteProperty" }) {

            $RunCount++

            $Resolved = Resolve-BinaryPath $Property.Value
            $Hash = if ($Resolved) { Get-FileHashSafe $Resolved } else { "Not Located" }

            $Results += [PSCustomObject]@{
                Type         = "Run Key"
                RegistryPath = $Key
                Name         = $Property.Name
                Command      = $Property.Value
                ResolvedPath = $Resolved
                Hash         = $Hash
            }
        }
    }
}

# ---------------------------------
# WINLOGON
# ---------------------------------
$WinlogonKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$WinlogonCount = 0

if (Test-Path $WinlogonKey) {

    $Winlogon = Get-ItemProperty $WinlogonKey

    foreach ($Entry in @("Shell","Userinit")) {

        if ($Winlogon.$Entry) {

            $WinlogonCount++

            $Resolved = Resolve-BinaryPath $Winlogon.$Entry
            $Hash = if ($Resolved) { Get-FileHashSafe $Resolved } else { "Not Located" }

            $Results += [PSCustomObject]@{
                Type         = "Winlogon"
                RegistryPath = $WinlogonKey
                Name         = $Entry
                Command      = $Winlogon.$Entry
                ResolvedPath = $Resolved
                Hash         = $Hash
            }
        }
    }
}

# ---------------------------------
# IFEO (Debugger Persistence)
# ---------------------------------
$IFEOPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"
$IFEOCount = 0

if (Test-Path $IFEOPath) {

    $IFEOKeys = Get-ChildItem $IFEOPath

    foreach ($SubKey in $IFEOKeys) {

        $Debugger = (Get-ItemProperty $SubKey.PSPath -ErrorAction SilentlyContinue).Debugger

        if ($Debugger) {

            $IFEOCount++

            $Resolved = Resolve-BinaryPath $Debugger
            $Hash = if ($Resolved) { Get-FileHashSafe $Resolved } else { "Not Located" }

            $Results += [PSCustomObject]@{
                Type         = "IFEO Debugger"
                RegistryPath = $SubKey.PSPath
                Name         = $SubKey.PSChildName
                Command      = $Debugger
                ResolvedPath = $Resolved
                Hash         = $Hash
            }
        }
    }
}

# ---------------------------------
# SERVICES
# ---------------------------------
$ServicesPath = "HKLM:\SYSTEM\CurrentControlSet\Services"
$ServiceCount = 0

if (Test-Path $ServicesPath) {

    $ServiceKeys = Get-ChildItem $ServicesPath

    foreach ($Service in $ServiceKeys) {

        $ImagePath = (Get-ItemProperty $Service.PSPath -ErrorAction SilentlyContinue).ImagePath

        if ($ImagePath) {

            $ServiceCount++

            $Resolved = Resolve-BinaryPath $ImagePath
            $Hash = if ($Resolved) { Get-FileHashSafe $Resolved } else { "Not Located" }

            $Results += [PSCustomObject]@{
                Type         = "Service"
                RegistryPath = $Service.PSPath
                Name         = $Service.PSChildName
                Command      = $ImagePath
                ResolvedPath = $Resolved
                Hash         = $Hash
            }
        }
    }
}

$ScriptEnd = Get-Date
$Elapsed   = $ScriptEnd - $ScriptStart

$Summary = @"
Registry Persistence Enumeration Report
--------------------------------------------
Script Start: $ScriptStart
Script End:   $ScriptEnd
Elapsed Time: $Elapsed

Run Key Count:      $RunCount
Winlogon Count:     $WinlogonCount
IFEO Count:         $IFEOCount
Service Count:      $ServiceCount
Total Items Found:  $($Results.Count)
--------------------------------------------
"@

Write-Host $Summary
$Summary | Out-File $OutputFile

$Results | Tee-Object -FilePath $OutputFile -Append | Format-Table -AutoSize

Write-Host "`nResults written to $OutputFile"