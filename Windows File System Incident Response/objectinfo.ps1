param (
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [ValidateSet("MD5","SHA1","SHA256","SHA384","SHA512")]
    [string]$HashAlgorithm = "SHA256"
)

$ScriptStart = Get-Date
$TimeStamp   = $ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile  = "objectinfo_$TimeStamp.log"

if (-not (Test-Path $Path)) {
    Write-Host "File does not exist."
    exit
}

$File = Get-Item -Path $Path -ErrorAction SilentlyContinue

# --- HASH ---
$Hash = Get-FileHash -Path $Path -Algorithm $HashAlgorithm

# --- BASIC METADATA ---
$Metadata = $File | Select-Object `
    Name,
    FullName,
    DirectoryName,
    Length,
    Extension,
    Mode,
    Attributes,
    IsReadOnly,
    CreationTime,
    CreationTimeUtc,
    LastAccessTime,
    LastAccessTimeUtc,
    LastWriteTime,
    LastWriteTimeUtc

# --- VERSION INFO (if exists) ---
$VersionInfo = $File.VersionInfo

# --- AUTHENTICODE SIGNATURE ---
$Signature = Get-AuthenticodeSignature $Path

# --- FILE HEADER (Magic Bytes) ---
$HeaderBytes = [System.IO.File]::OpenRead($Path)
$Buffer = New-Object byte[] 16
$HeaderBytes.Read($Buffer,0,16) | Out-Null
$HeaderBytes.Close()
$MagicHex = ($Buffer | ForEach-Object { $_.ToString("X2") }) -join " "

# --- ALTERNATE DATA STREAMS ---
$ADS = Get-Item -Path $Path -Stream * -ErrorAction SilentlyContinue

# --- REPARSE POINT CHECK ---
$Reparse = $false
if ($File.Attributes -match "ReparsePoint") {
    $Reparse = $true
}

# --- HANDLE CHECK (File Lock Test) ---
$IsLocked = $false
try {
    $Stream = [System.IO.File]::Open($Path,'Open','Read','None')
    $Stream.Close()
}
catch {
    $IsLocked = $true
}

$ScriptEnd = Get-Date
$Elapsed   = $ScriptEnd - $ScriptStart

# --- OUTPUT BLOCK ---
$Output = @"
OBJECT INFORMATION REPORT
------------------------------------------
File Path: $($File.FullName)

Hash ($HashAlgorithm): $($Hash.Hash)

Size (Bytes): $($Metadata.Length)
Extension:    $($Metadata.Extension)
Attributes:   $($Metadata.Attributes)
ReadOnly:     $($Metadata.IsReadOnly)

CreationTime (Local): $($Metadata.CreationTime)
CreationTime (UTC):   $($Metadata.CreationTimeUtc)
LastAccess (Local):   $($Metadata.LastAccessTime)
LastAccess (UTC):     $($Metadata.LastAccessTimeUtc)
LastWrite (Local):    $($Metadata.LastWriteTime)
LastWrite (UTC):      $($Metadata.LastWriteTimeUtc)

Version:       $($VersionInfo.FileVersion)
Company:       $($VersionInfo.CompanyName)
Product:       $($VersionInfo.ProductName)

Signature Status: $($Signature.Status)
Signer:           $($Signature.SignerCertificate.Subject)
Timestamp Cert:   $($Signature.TimeStamperCertificate.Subject)
Is OS Binary:     $($Signature.IsOSBinary)

Magic Header (First 16 Bytes):
$MagicHex

Reparse Point: $Reparse
File Locked:   $IsLocked

Alternate Data Streams:
$($ADS | ForEach-Object { $_.Stream })

------------------------------------------
Script Start: $ScriptStart
Script End:   $ScriptEnd
Elapsed Time: $Elapsed
------------------------------------------
"@

# Write to screen
Write-Host $Output

# Write to file
$Output | Out-File $OutputFile

Write-Host "Report written to $OutputFile"
