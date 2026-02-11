param (
    [ValidateSet(30,60,90)]
    [int]$Days = 30
)

$ScriptStart = Get-Date
$TimeStamp   = $ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile  = "file_auditing_$TimeStamp.log"

$StartTime = (Get-Date).AddDays(-$Days)
$EndTime   = Get-Date

Write-Host "File System Auditing Collection"
Write-Host "Time Window: $StartTime  ->  $EndTime"
Write-Host "-------------------------------------------"

# Helper: Safe XML property extraction
function Get-EventDataField {
    param($Xml, $FieldName)
    return ($Xml.Event.EventData.Data | Where-Object { $_.Name -eq $FieldName }).'#text'
}

# Collect events
$SecurityIDs = 4656,4658,4660,4663,5140,5145
$SystemIDs   = 55,98,129,157
$SysmonID    = 2

$Events = @()

# Security Log
$SecurityEvents = Get-WinEvent -FilterHashtable @{
    LogName='Security'
    Id=$SecurityIDs
    StartTime=$StartTime
    EndTime=$EndTime
} -ErrorAction SilentlyContinue

# System Log
$SystemEvents = Get-WinEvent -FilterHashtable @{
    LogName='System'
    Id=$SystemIDs
    StartTime=$StartTime
    EndTime=$EndTime
} -ErrorAction SilentlyContinue

# Sysmon (if installed)
$SysmonEvents = @()
if (Get-WinEvent -ListLog "Microsoft-Windows-Sysmon/Operational" -ErrorAction SilentlyContinue) {
    $SysmonEvents = Get-WinEvent -FilterHashtable @{
        LogName='Microsoft-Windows-Sysmon/Operational'
        Id=$SysmonID
        StartTime=$StartTime
        EndTime=$EndTime
    } -ErrorAction SilentlyContinue
}

$AllEvents = $SecurityEvents + $SystemEvents + $SysmonEvents

# Categorization Buckets
$Created  = @()
$Modified = @()
$Deleted  = @()
$Renamed  = @()
$HandleReq= @()
$HandleCls= @()
$Share    = @()
$Disk     = @()
$TimeMod  = @()

foreach ($Event in $AllEvents) {

    $Xml = [xml]$Event.ToXml()
    $Id  = $Event.Id
    $Log = $Event.LogName
    $Time = $Event.TimeCreated

    $User = Get-EventDataField $Xml "SubjectUserName"
    $ObjectName = Get-EventDataField $Xml "ObjectName"
    $AccessMask = Get-EventDataField $Xml "AccessMask"
    $AccessList = Get-EventDataField $Xml "AccessList"

    $Record = [PSCustomObject]@{
        TimeCreated = $Time
        LogName     = $Log
        EventID     = $Id
        User        = $User
        Object      = $ObjectName
        AccessMask  = $AccessMask
        AccessList  = $AccessList
        Message     = $Event.Message.Split("`n")[0]
    }

    switch ($Id) {

        4663 {
            if ($AccessList -match "WriteData|AddFile") {
                $Created += $Record
            }
            elseif ($AccessList -match "Delete") {
                $Renamed += $Record
            }
            else {
                $Modified += $Record
            }
        }

        4656 { $HandleReq += $Record }
        4658 { $HandleCls += $Record }
        4660 { $Deleted   += $Record }

        5140 { $Share += $Record }
        5145 { $Share += $Record }

        55   { $Disk += $Record }
        98   { $Disk += $Record }
        129  { $Disk += $Record }
        157  { $Disk += $Record }

        2    { $TimeMod += $Record }
    }
}

$ScriptEnd = Get-Date
$Elapsed   = $ScriptEnd - $ScriptStart

# Summary
$Summary = @"
File Auditing Summary
--------------------------------------------
Time Window: $StartTime  ->  $EndTime
Script Start: $ScriptStart
Script End:   $ScriptEnd
Elapsed Time: $Elapsed

Created Events        : $($Created.Count)
Modified Events       : $($Modified.Count)
Renamed Indicators    : $($Renamed.Count)
Deleted Events        : $($Deleted.Count)
Handle Requested      : $($HandleReq.Count)
Handle Closed         : $($HandleCls.Count)
Share Access Events   : $($Share.Count)
Disk Related Events   : $($Disk.Count)
Creation Time Changed : $($TimeMod.Count)
--------------------------------------------
"@

# Output to screen
Write-Host $Summary

# Write summary to file
$Summary | Out-File $OutputFile

# Helper to write event blocks
function Write-Category {
    param($Title, $Data)

    Write-Host "Writing $Title ($($Data.Count))"
    "===== $Title =====" | Out-File $OutputFile -Append

    foreach ($Item in $Data | Sort-Object TimeCreated) {
        @"
Time:      $($Item.TimeCreated)
Log:       $($Item.LogName)
Event ID:  $($Item.EventID)
User:      $($Item.User)
Object:    $($Item.Object)
Access:    $($Item.AccessList)
Message:   $($Item.Message)
------------------------------------------------------------
"@ | Out-File $OutputFile -Append
    }
}

Write-Category "CREATED" $Created
Write-Category "MODIFIED" $Modified
Write-Category "RENAMED INDICATORS" $Renamed
Write-Category "DELETED" $Deleted
Write-Category "HANDLE REQUESTED" $HandleReq
Write-Category "HANDLE CLOSED" $HandleCls
Write-Category "SHARE ACCESS" $Share
Write-Category "DISK EVENTS" $Disk
Write-Category "CREATION TIME MODIFIED (SYSMON)" $TimeMod

Write-Host "Completed. Log written to $OutputFile"
