param (
    [ValidateSet(30,60,90)]
    [int]$Days = 30
)

$ScriptStart = Get-Date
$TimeStamp   = $ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile  = "lockfiles_$TimeStamp.log"

$StartTime = (Get-Date).AddDays(-$Days)
$EndTime   = Get-Date

Write-Host "Lock File Hunt - Last $Days Days"
Write-Host "Time Window: $StartTime -> $EndTime"
Write-Host "------------------------------------------"

# --- Find Lock Files ---
$LockPatterns = '~$*','*.lock*','.~lock*'

$LockFiles = Get-ChildItem -Path C:\Users\ -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object {
        ($LockPatterns | ForEach-Object { $_ }) -contains $_.Name -or
        $_.Name -like '~$*' -or
        $_.Name -like '*.lock*' -or
        $_.Name -like '.~lock*'
    } |
    Where-Object {
        $_.LastWriteTime -ge $StartTime
    }

# --- Get Prefetch Files ---
$PrefetchPath = "C:\Windows\Prefetch"
$PrefetchFiles = @()

if (Test-Path $PrefetchPath) {
    $PrefetchFiles = Get-ChildItem $PrefetchPath -Filter *.pf -ErrorAction SilentlyContinue
}

# --- Correlate ---
$Results = @()

foreach ($File in $LockFiles) {

    $AppHint = ""

    switch -Wildcard ($File.Extension) {
        "*.doc*"  { $AppHint = "WINWORD" }
        "*.xls*"  { $AppHint = "EXCEL" }
        "*.ppt*"  { $AppHint = "POWERPNT" }
        "*.odt*"  { $AppHint = "SOFFICE" }
        default   { $AppHint = "" }
    }

    $PrefetchMatch = $null

    if ($AppHint -ne "") {
        $PrefetchMatch = $PrefetchFiles |
            Where-Object { $_.Name -like "$AppHint*" } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    }

    $Results += [PSCustomObject]@{
        LockFilePath      = $File.FullName
        SizeBytes         = $File.Length
        CreationTime      = $File.CreationTime
        LastWriteTime     = $File.LastWriteTime
        LastAccessTime    = $File.LastAccessTime
        PrefetchMatch     = if ($PrefetchMatch) { $PrefetchMatch.Name } else { "None" }
        PrefetchLastWrite = if ($PrefetchMatch) { $PrefetchMatch.LastWriteTime } else { "N/A" }
    }
}

$ScriptEnd = Get-Date
$Elapsed   = $ScriptEnd - $ScriptStart

# --- Summary ---
$Summary = @"
Lock File Investigation Summary
--------------------------------------------
Time Window: $StartTime -> $EndTime
Script Start: $ScriptStart
Script End:   $ScriptEnd
Elapsed Time: $Elapsed
Total Lock Files Found: $($Results.Count)
--------------------------------------------
"@

Write-Host $Summary
$Summary | Out-File $OutputFile

foreach ($Entry in $Results | Sort-Object LastWriteTime) {

@"
Lock File:          $($Entry.LockFilePath)
Size (Bytes):       $($Entry.SizeBytes)
Created:            $($Entry.CreationTime)
Last Modified:      $($Entry.LastWriteTime)
Last Accessed:      $($Entry.LastAccessTime)

Prefetch Match:     $($Entry.PrefetchMatch)
Prefetch Timestamp: $($Entry.PrefetchLastWrite)
------------------------------------------------------------
"@ | Tee-Object -FilePath $OutputFile -Append
}

Write-Host "Results written to $OutputFile"
