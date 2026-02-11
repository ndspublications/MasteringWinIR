param (
    [ValidateSet("SHA256","SHA512","MD5","SHA1")]
    [string]$HashAlgorithm = "SHA256"
)

$ScriptStart = Get-Date
$TimeStamp   = $ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile  = "services_persistence_$TimeStamp.log"

$Results = @()
$MissingBinaryCount = 0
$ServiceCount = 0

# ---------------------------------
# Helper: Resolve Binary Path
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
# Hash safely
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
# Enumerate Services
# ---------------------------------
$Services = Get-CimInstance Win32_Service

foreach ($Service in $Services) {

    $ServiceCount++

    $Resolved = Resolve-BinaryPath $Service.PathName
    $Hash = $null
    $SignatureStatus = $null
    $Company = $null

    if ($Resolved) {

        $Hash = Get-FileHashSafe $Resolved

        try {
            $Signature = Get-AuthenticodeSignature $Resolved
            $SignatureStatus = $Signature.Status
        }
        catch { }

        try {
            $Company = (Get-Item $Resolved).VersionInfo.CompanyName
        }
        catch { }

    }
    else {
        $Hash = "Not Located"
        $SignatureStatus = "Unknown"
        $MissingBinaryCount++
    }

    $Results += [PSCustomObject]@{
        ServiceName     = $Service.Name
        DisplayName     = $Service.DisplayName
        Status          = $Service.State
        StartMode       = $Service.StartMode
        ProcessId       = $Service.ProcessId
        ImagePath       = $Service.PathName
        ResolvedPath    = $Resolved
        Hash            = $Hash
        SignatureStatus = $SignatureStatus
        CompanyName     = $Company
    }
}

$ScriptEnd = Get-Date
$Elapsed   = $ScriptEnd - $ScriptStart

$Summary = @"
Service Persistence Enumeration Report
--------------------------------------------
Script Start: $ScriptStart
Script End:   $ScriptEnd
Elapsed Time: $Elapsed

Total Services Found:       $ServiceCount
Services with Missing Binary: $MissingBinaryCount
--------------------------------------------
"@

Write-Host $Summary
$Summary | Out-File $OutputFile

$Results | Tee-Object -FilePath $OutputFile -Append | Format-Table -AutoSize

Write-Host "`nResults written to $OutputFile"