param (
    [ValidateSet("SHA256","SHA512","MD5","SHA1")]
    [string]$HashAlgorithm = "SHA256"
)

$ScriptStart = Get-Date
$TimeStamp   = $ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile  = "system_share_hashes_$TimeStamp.log"

Write-Host "System Share Hash Enumeration"
Write-Host "--------------------------------------------"

# Get system shares (ADMIN$, C$, D$, etc.)
$Shares = Get-SmbShare -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match "\$$" }

$TotalShares = $Shares.Count
$TotalFiles  = 0
$HashErrors  = 0

$Results = @()

foreach ($Share in $Shares) {

    Write-Host "Processing Share: $($Share.Name) -> $($Share.Path)"

    if (-not (Test-Path $Share.Path)) { continue }

    $Files = Get-ChildItem -Path $Share.Path -Recurse -File -Force -ErrorAction SilentlyContinue

    foreach ($File in $Files) {

        try {
            $Hash = Get-FileHash -Path $File.FullName -Algorithm $HashAlgorithm -ErrorAction Stop

            $Results += [PSCustomObject]@{
                ShareName     = $Share.Name
                FilePath      = $File.FullName
                SizeBytes     = $File.Length
                LastWriteTime = $File.LastWriteTime
                Hash          = $Hash.Hash
            }

            $TotalFiles++
        }
        catch {
            $HashErrors++
        }
    }
}

$ScriptEnd = Get-Date
$Elapsed   = $ScriptEnd - $ScriptStart

# Summary block
$Summary = @"
System Share Hash Enumeration Report
--------------------------------------------
Script Start: $ScriptStart
Script End:   $ScriptEnd
Elapsed Time: $Elapsed

Hash Algorithm Used: $HashAlgorithm
Total Shares Found:  $TotalShares
Total Files Hashed:  $TotalFiles
Hash Errors:         $HashErrors
--------------------------------------------
"@

Write-Host $Summary
$Summary | Out-File $OutputFile

foreach ($Entry in $Results) {

@"
Share:        $($Entry.ShareName)
File:         $($Entry.FilePath)
Size (Bytes): $($Entry.SizeBytes)
Last Modified:$($Entry.LastWriteTime)
Hash:         $($Entry.Hash)
------------------------------------------------------------
"@ | Tee-Object -FilePath $OutputFile -Append
}

Write-Host "Results written to $OutputFile"