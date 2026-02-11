param(
    [switch]$VerboseOutput
)

$ScriptStart = Get-Date
$TimeStamp = $ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile = "proxy_audit_$TimeStamp.log"

Write-Host "Starting Proxy Configuration Audit..."

$Results = @()

# -------------------------------------------------
# WinHTTP Proxy (System Level)
# -------------------------------------------------
$WinHttpProxy = netsh winhttp show proxy 2>&1

# -------------------------------------------------
# WinINET Proxy (User Level)
# -------------------------------------------------
$UserProxyKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
$MachineProxyKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"

$UserProxy = Get-ItemProperty -Path $UserProxyKey -ErrorAction SilentlyContinue
$MachineProxy = Get-ItemProperty -Path $MachineProxyKey -ErrorAction SilentlyContinue

# -------------------------------------------------
# Environment Variables
# -------------------------------------------------
$EnvProxy = Get-ChildItem Env: | Where-Object {
    $_.Name -match "proxy"
}

# -------------------------------------------------
# Suspicious Indicators
# -------------------------------------------------
$SuspiciousFindings = @()

if ($UserProxy.ProxyEnable -eq 1 -and $UserProxy.ProxyServer) {
    $SuspiciousFindings += "User proxy enabled: $($UserProxy.ProxyServer)"
}

if ($MachineProxy.ProxyEnable -eq 1 -and $MachineProxy.ProxyServer) {
    $SuspiciousFindings += "Machine proxy enabled: $($MachineProxy.ProxyServer)"
}

if ($UserProxy.AutoConfigURL) {
    $SuspiciousFindings += "User PAC file configured: $($UserProxy.AutoConfigURL)"
}

if ($MachineProxy.AutoConfigURL) {
    $SuspiciousFindings += "Machine PAC file configured: $($MachineProxy.AutoConfigURL)"
}

if ($EnvProxy) {
    foreach ($Var in $EnvProxy) {
        $SuspiciousFindings += "Environment variable proxy: $($Var.Name) = $($Var.Value)"
    }
}

# -------------------------------------------------
# Script End Time
# -------------------------------------------------
$ScriptEnd = Get-Date
$Duration = $ScriptEnd - $ScriptStart

# -------------------------------------------------
# Output
# -------------------------------------------------
"Proxy Configuration Audit" | Out-File $OutputFile
"Start Time: $ScriptStart" | Out-File $OutputFile -Append
"End Time:   $ScriptEnd" | Out-File $OutputFile -Append
"Duration:   $Duration" | Out-File $OutputFile -Append
"------------------------------------------------------------" | Out-File $OutputFile -Append

"WinHTTP Proxy Configuration:" | Out-File $OutputFile -Append
$WinHttpProxy | Out-File $OutputFile -Append

"`nUser Proxy Settings:" | Out-File $OutputFile -Append
$UserProxy | Out-File $OutputFile -Append

"`nMachine Proxy Settings:" | Out-File $OutputFile -Append
$MachineProxy | Out-File $OutputFile -Append

"`nEnvironment Proxy Variables:" | Out-File $OutputFile -Append
$EnvProxy | Out-File $OutputFile -Append

"`nSuspicious Indicators:" | Out-File $OutputFile -Append
if ($SuspiciousFindings.Count -gt 0) {
    $SuspiciousFindings | Out-File $OutputFile -Append
} else {
    "No obvious suspicious proxy configuration detected." | Out-File $OutputFile -Append
}

Write-Host "Completed. Output written to $OutputFile"