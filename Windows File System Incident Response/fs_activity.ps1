param (
    [ValidateSet(30,60,90)]
    [int]$Days = 30
)

$ScriptStart = Get-Date
$TimeStamp = $ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile = "filesystem_winids_$TimeStamp.log"

$StartTime = (Get-Date).AddDays(-$Days)
$EndTime = Get-Date

Write-Host "Pulling File System Events for last $Days days..."
Write-Host "Start Window: $StartTime"
Write-Host "End Window:   $EndTime"
Write-Host "----------------------------------------------"

$FilterHash = @{
    LogName   = 'Security'
    Id        = 4656,4660,4663
    StartTime = $StartTime
    EndTime   = $EndTime
}

$Events = Get-WinEvent -FilterHashtable $FilterHash -ErrorAction SilentlyContinue

$Created  = @()
$Modified = @()
$Renamed  = @()
$Deleted  = @()

foreach ($Event in $Events) {

    $Message = $Event.Message
    $Time    = $Event.TimeCreated
    $Id      = $Event.Id

    if ($Id -eq 4663 -and $Message -match "WriteData|AddFile") {
        $Created += $Event
    }
    elseif ($Id -eq 4656 -and $Message -match "WriteData|AppendData") {
        $Modified += $Event
    }
    elseif ($Id -eq 4663 -and $Message -match "DELETE") {
        $Renamed += $Event
    }
    elseif ($Id -eq 4660) {
        $Deleted += $Event
    }
}

$ScriptEnd = Get-Date
$Elapsed = $ScriptEnd - $ScriptStart

# Summary Output
$Summary = @"
File System Activity Summary
----------------------------------------------
Time Window: $StartTime  ->  $EndTime
Script Start: $ScriptStart
Script End:   $ScriptEnd
Elapsed Time: $Elapsed

Created Events :  $($Created.Count)
Modified Events:  $($Modified.Count)
Renamed Events :  $($Renamed.Count)
Deleted Events :  $($Deleted.Count)
----------------------------------------------
"@

# Write to terminal
Write-Host $Summary

# Write to file
$Summary | Out-File $OutputFile

function Write-EventBlock {
    param($Title, $EventArray)

    "===== $Title =====" | Out-File $OutputFile -Append
    foreach ($E in $EventArray) {
        @"
Time:      $($E.TimeCreated)
Event ID:  $($E.Id)
Message:
$($E.Message)
-----------------------------------------------------
"@ | Out-File $OutputFile -Append
    }
}

Write-EventBlock "CREATED"  $Created
Write-EventBlock "MODIFIED" $Modified
Write-EventBlock "RENAMED"  $Renamed
Write-EventBlock "DELETED"  $Deleted

Write-Host "Log written to $OutputFile"
