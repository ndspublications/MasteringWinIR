param (
    [ValidateSet("SHA256","SHA512","MD5","SHA1")]
    [string]$HashAlgorithm = "SHA256"
)

$ScriptStart = Get-Date
$TimeStamp   = $ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile  = "remote_admin_detection_$TimeStamp.log"

# Known RAT / Remote Tool Ports
$SuspiciousPorts = @(
    4444,   # Metasploit
    5555,   # Common reverse shell
    1337,   # Generic exploit
    3389,   # RDP
    5900,   # VNC
    5938,   # TeamViewer
    7070,   # AnyDesk alt
    8080,   # Common RAT / proxy
    9001    # Common backdoor
)

# Known Remote Tool Process Names
$SuspiciousProcessNames = @(
    "teamviewer",
    "tv_x64",
    "vnc",
    "winvnc",
    "anydesk",
    "ammyy",
    "logmein",
    "radmin",
    "mstsc",
    "splashtop"
)

Write-Host "Remote Administration / Exploit Port Detection"
Write-Host "---------------------------------------------------"

$Findings = @()
$Connections = Get-NetTCPConnection -ErrorAction SilentlyContinue

foreach ($Conn in $Connections) {

    $Process = Get-Process -Id $Conn.OwningProcess -ErrorAction SilentlyContinue
    if (-not $Process) { continue }

    $FlagReason = $null

    # Check ports
    if ($SuspiciousPorts -contains $Conn.LocalPort -or
        $SuspiciousPorts -contains $Conn.RemotePort) {

        $FlagReason = "Suspicious Port"
    }

    # Check process name
    foreach ($Name in $SuspiciousProcessNames) {
        if ($Process.ProcessName -match $Name) {
            $FlagReason = "Known Remote Tool"
        }
    }

    if ($FlagReason) {

        $Hash = $null
        try {
            if ($Process.Path) {
                $Hash = (Get-FileHash -Path $Process.Path -Algorithm $HashAlgorithm -ErrorAction Stop).Hash
            }
        }
        catch { }

        $Findings += [PSCustomObject]@{
            DateTimeFound = Get-Date
            PID            = $Process.Id
            ProcessName    = $Process.ProcessName
            ExecutablePath = $Process.Path
            Hash           = $Hash
            LocalAddress   = $Conn.LocalAddress
            LocalPort      = $Conn.LocalPort
            RemoteAddress  = $Conn.RemoteAddress
            RemotePort     = $Conn.RemotePort
            State          = $Conn.State
            DetectionType  = $FlagReason
        }
    }
}

$ScriptEnd = Get-Date
$Elapsed   = $ScriptEnd - $ScriptStart

$Summary = @"
Remote Administration / Exploit Port Detection Report
------------------------------------------------------------
Script Start: $ScriptStart
Script End:   $ScriptEnd
Elapsed Time: $Elapsed

Total Suspicious Findings: $($Findings.Count)
------------------------------------------------------------
"@

Write-Host $Summary
$Summary | Out-File $OutputFile

foreach ($Entry in $Findings) {

@"
Date/Time Found: $($Entry.DateTimeFound)
Detection Type:  $($Entry.DetectionType)

PID:             $($Entry.PID)
Process Name:    $($Entry.ProcessName)
Executable Path: $($Entry.ExecutablePath)
Hash ($HashAlgorithm): $($Entry.Hash)

Local:  $($Entry.LocalAddress):$($Entry.LocalPort)
Remote: $($Entry.RemoteAddress):$($Entry.RemotePort)
State:  $($Entry.State)
------------------------------------------------------------
"@ | Tee-Object -FilePath $OutputFile -Append
}

Write-Host "`nResults written to $OutputFile"