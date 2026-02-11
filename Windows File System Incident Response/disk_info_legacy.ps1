param (
    [datetime]$StartTime,
    [datetime]$EndTime
)

$ScriptStart = Get-Date
$TimeStamp = $ScriptStart.ToString("MMddyyyyHHmmss")
$OutputFile = "drives_$TimeStamp.log"

$Results = @()

# Get logical disks
$LogicalDisks = Get-CimInstance Win32_LogicalDisk

foreach ($Disk in $LogicalDisks) {

    # Get partition
    $Partition = Get-CimInstance -Query "ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='$($Disk.DeviceID)'} WHERE AssocClass=Win32_LogicalDiskToPartition"

    # Get physical disk
    $PhysicalDisk = $null
    if ($Partition) {
        $PhysicalDisk = Get-CimInstance -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($Partition.DeviceID)'} WHERE AssocClass=Win32_DiskDriveToDiskPartition"
    }

    # Determine Drive Type
    $DriveType = switch ($Disk.DriveType) {
        0 {"Unknown"}
        1 {"No Root Directory"}
        2 {"Removable"}
        3 {"Fixed"}
        4 {"Network"}
        5 {"CD/DVD"}
        6 {"RAM Disk"}
        default {"Other"}
    }

    $BusType = if ($PhysicalDisk) { $PhysicalDisk.InterfaceType } else { "N/A" }

    # Classification Logic
    $Classification = if ($BusType -eq "USB") {
        "External"
    }
    elseif ($DriveType -eq "Fixed") {
        "Internal"
    }
    else {
        $DriveType
    }

    # Approximate mount indicator via MountedDevices registry
    $MountReg = "HKLM:\SYSTEM\MountedDevices"
    $MountTime = (Get-Item $MountReg).LastWriteTime

    # Time filtering
    if ($StartTime -and $MountTime -lt $StartTime) { continue }
    if ($EndTime -and $MountTime -gt $EndTime) { continue }

    $Results += [PSCustomObject]@{
        DriveLetter        = $Disk.DeviceID
        Classification     = $Classification
        DriveType          = $DriveType
        BusType            = $BusType
        VolumeLabel        = $Disk.VolumeName
        FileSystem         = $Disk.FileSystem
        VolumeSerialNumber = $Disk.VolumeSerialNumber
        DiskSizeGB         = if ($Disk.Size) {[math]::Round($Disk.Size / 1GB,2)} else {"N/A"}
        FreeSpaceGB        = if ($Disk.FreeSpace) {[math]::Round($Disk.FreeSpace / 1GB,2)} else {"N/A"}
        PhysicalSerial     = if ($PhysicalDisk) { $PhysicalDisk.SerialNumber } else { "N/A" }
        RegistryMountTime  = $MountTime
    }
}

$ScriptEnd = Get-Date
$Duration = $ScriptEnd - $ScriptStart

# Write Header
"Script Start Time: $ScriptStart" | Out-File $OutputFile
"Script End Time:   $ScriptEnd" | Out-File $OutputFile -Append
"Elapsed Time:      $Duration" | Out-File $OutputFile -Append
"Total Drives Found: $($Results.Count)" | Out-File $OutputFile -Append
"------------------------------------------------------------" | Out-File $OutputFile -Append

# Write Full Results (no truncation)
$Results | Sort-Object DriveLetter | Format-List | Out-File $OutputFile -Append

Write-Host "Completed. Output written to $OutputFile"
