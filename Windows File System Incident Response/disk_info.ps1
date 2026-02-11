param (
    [datetime]$StartTime,
    [datetime]$EndTime
)

$ScriptStart = Get-Date
$TimeStamp = $ScriptStart.ToString("MMddyyyyHHmmss")
$OutputFile = "drives_$TimeStamp.log"

$Results = @()

# Get volumes that have drive letters
$Volumes = Get-Volume | Where-Object { $_.DriveLetter -ne $null }

foreach ($Volume in $Volumes) {

    $Partition = Get-Partition -DriveLetter $Volume.DriveLetter -ErrorAction SilentlyContinue
    $Disk = $null

    if ($Partition) {
        $Disk = Get-Disk -Number $Partition.DiskNumber -ErrorAction SilentlyContinue
    }

    if (-not $Disk) { continue }

    # Classification Logic
    $Classification = switch ($Disk.BusType) {
        "USB" { "External" }
        "NVMe" { "Internal" }
        "SATA" { "Internal" }
        "ATA" { "Internal" }
        "RAID" { "Internal" }
        default { $Disk.BusType }
    }

    # Approximate timestamp reference
    # Windows does not store a reliable mount timestamp per volume.
    # We use volume creation time if available.
    $VolumeTime = $Volume.CreationTime

    if ($StartTime -and $VolumeTime -lt $StartTime) { continue }
    if ($EndTime -and $VolumeTime -gt $EndTime) { continue }

    $Results += [PSCustomObject]@{
        DriveLetter        = "$($Volume.DriveLetter):"
        Classification     = $Classification
        BusType            = $Disk.BusType
        MediaType          = $Disk.MediaType
        VolumeLabel        = $Volume.FileSystemLabel
        FileSystem         = $Volume.FileSystem
        VolumeSerialNumber = $Volume.SerialNumber
        DiskNumber         = $Disk.Number
        DiskSizeGB         = [math]::Round($Disk.Size / 1GB,2)
        FreeSpaceGB        = [math]::Round($Volume.SizeRemaining / 1GB,2)
        PhysicalSerial     = $Disk.SerialNumber
        ApproxMountTime    = $VolumeTime
    }
}

$ScriptEnd = Get-Date
$Duration = $ScriptEnd - $ScriptStart

# Write header
"Script Start Time: $ScriptStart" | Out-File $OutputFile
"Script End Time:   $ScriptEnd" | Out-File $OutputFile -Append
"Elapsed Time:      $Duration" | Out-File $OutputFile -Append
"Total Drives Found: $($Results.Count)" | Out-File $OutputFile -Append
"------------------------------------------------------------" | Out-File $OutputFile -Append

# Write results (no truncation)
$Results | Sort-Object DriveLetter | Format-List | Out-File $OutputFile -Append

Write-Host "Completed. Output written to $OutputFile"
