param (
    [ValidateSet("SHA256","SHA512","MD5","SHA1")]
    [string]$HashAlgorithm = "SHA256"
)

$ScriptStart = Get-Date
$TimeStamp   = $ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile  = "startup_persistence_$TimeStamp.log"

$Results = @()

# --------------------------------------
# Helper: Resolve Binary Path
# --------------------------------------
function Resolve-BinaryPath {
    param ($Command)

    $Exe = $Command -replace '"',''
    $Exe = $Exe.Split(" ")[0]

    if (Test-Path $Exe) {
        return $Exe
    }

    $SearchPaths = @(
        "C:\Windows\$Exe",
        "C:\Windows\System32\$Exe",
        "C:\$Exe"
    )

    foreach ($Path in $SearchPaths) {
        if (Test-Path $Path) {
            return $Path
        }
    }

    return $null
}

# --------------------------------------
# Helper: Hash File
# --------------------------------------
function Get-FileHashSafe {
    param ($Path)

    try {
        return (Get-FileHash -Path $Path -Algorithm $HashAlgorithm -ErrorAction Stop).Hash
    }
    catch {
        return "Hash Failed"
    }
}

# --------------------------------------
# Registry Run Keys
# --------------------------------------
$RunKeys = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
)

$RegistryCount = 0

foreach ($Key in $RunKeys) {

    if (Test-Path $Key) {

        $Entries = Get-ItemProperty $Key

        foreach ($Property in $Entries.PSObject.Properties | Where-Object { $_.MemberType -eq "NoteProperty" }) {

            $RegistryCount++

            $ResolvedPath = Resolve-BinaryPath $Property.Value
            $Hash = if ($ResolvedPath) { Get-FileHashSafe $ResolvedPath } else { "Not Located" }

            $Results += [PSCustomObject]@{
                Type            = "Registry Run"
                Location        = $Key
                Name            = $Property.Name
                Command         = $Property.Value
                ResolvedPath    = $ResolvedPath
                Hash            = $Hash
            }
        }
    }
}

# --------------------------------------
# Winlogon
# --------------------------------------
$WinlogonKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
if (Test-Path $WinlogonKey) {

    $Winlogon = Get-ItemProperty $WinlogonKey

    foreach ($Entry in @("Shell","Userinit")) {

        if ($Winlogon.$Entry) {

            $RegistryCount++

            $ResolvedPath = Resolve-BinaryPath $Winlogon.$Entry
            $Hash = if ($ResolvedPath) { Get-FileHashSafe $ResolvedPath } else { "Not Located" }

            $Results += [PSCustomObject]@{
                Type         = "Winlogon"
                Location     = $WinlogonKey
                Name         = $Entry
                Command      = $Winlogon.$Entry
                ResolvedPath = $ResolvedPath
                Hash         = $Hash
            }
        }
    }
}

# --------------------------------------
# Startup Folders
# --------------------------------------
$StartupFolders = @(
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
)

$StartupFolderCount = 0

foreach ($Folder in $StartupFolders) {

    if (Test-Path $Folder) {

        $Files = Get-ChildItem $Folder -File -Force -ErrorAction SilentlyContinue

        foreach ($File in $Files) {

            $StartupFolderCount++

            $Hash = Get-FileHashSafe $File.FullName

            $Results += [PSCustomObject]@{
                Type         = "Startup Folder"
                Location     = $Folder
                Name         = $File.Name
                Command      = $File.FullName
                ResolvedPath = $File.FullName
                Hash         = $Hash
            }
        }
    }
}

# --------------------------------------
# Scheduled Tasks
# --------------------------------------
$TaskCount = 0
$Tasks = Get-ScheduledTask -ErrorAction SilentlyContinue

foreach ($Task in $Tasks) {

    foreach ($Action in $Task.Actions) {

        if ($Action.Execute) {

            $TaskCount++

            $ResolvedPath = Resolve-BinaryPath $Action.Execute
            $Hash = if ($ResolvedPath) { Get-FileHashSafe $ResolvedPath } else { "Not Located" }

            $Results += [PSCustomObject]@{
                Type         = "Scheduled Task"
                Location     = $Task.TaskName
                Name         = $Task.TaskName
                Command      = $Action.Execute
                ResolvedPath = $ResolvedPath
                Hash         = $Hash
            }
        }
    }
}

$ScriptEnd = Get-Date
$Elapsed   = $ScriptEnd - $ScriptStart

$Summary = @"
Persistence Enumeration Report
--------------------------------------------
Script Start: $ScriptStart
Script End:   $ScriptEnd
Elapsed Time: $Elapsed

Registry Startup Count:   $RegistryCount
Startup Folder Count:     $StartupFolderCount
Scheduled Task Count:     $TaskCount
Total Persistence Items:  $($Results.Count)
--------------------------------------------
"@

Write-Host $Summary
$Summary | Out-File $OutputFile

$Results | Tee-Object -FilePath $OutputFile -Append | Format-Table -AutoSize

Write-Host "`nResults written to $OutputFile"