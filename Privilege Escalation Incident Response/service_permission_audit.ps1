param(
    [int]$Days = 30
)

$StartTime = Get-Date
$Timestamp = $StartTime.ToString("yyyyMMddHHmmss")
$LogFile = "service_permission_audit_$Timestamp.log"

Write-Output "=== Service Permission Audit ===" | Tee-Object $LogFile
Write-Output "Start Time: $StartTime" | Tee-Object $LogFile -Append

Get-WmiObject Win32_Service | ForEach-Object {
    $Path = $_.PathName
    if ($Path) {
        $CleanPath = $Path.Split(".exe")[0] + ".exe"
        if (Test-Path $CleanPath) {
            $Acl = Get-Acl $CleanPath
            $Acl.Access | Where-Object {
                $_.FileSystemRights -match "Write" -and
                $_.IdentityReference -notmatch "SYSTEM|Administrators"
            } | ForEach-Object {
                [PSCustomObject]@{
                    Service = $_.Name
                    Path    = $CleanPath
                    WritableBy = $_.IdentityReference
                }
            }
        }
    }
} | Tee-Object $LogFile -Append

$EndTime = Get-Date
$Duration = $EndTime - $StartTime

Write-Output "Duration: $Duration" | Tee-Object $LogFile -Append