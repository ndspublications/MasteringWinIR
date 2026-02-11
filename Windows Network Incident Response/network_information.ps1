param (
    [ValidateSet("IPv4","IPv6","All")]
    [string]$AddressFamily = "All"
)

$ScriptStart = Get-Date
$TimeStamp   = $ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile  = "network_routes_$TimeStamp.log"

# Determine address family filter
switch ($AddressFamily) {
    "IPv4" { $AF = 2 }
    "IPv6" { $AF = 23 }
    "All"  { $AF = $null }
}

# Collect routes
if ($AF) {
    $Routes = Get-NetRoute -AddressFamily $AF -ErrorAction SilentlyContinue
}
else {
    $Routes = Get-NetRoute -ErrorAction SilentlyContinue
}

# Collect interface information
$Interfaces = Get-NetIPConfiguration -ErrorAction SilentlyContinue

$Results = @()

foreach ($Route in $Routes) {

    $InterfaceInfo = $Interfaces | Where-Object {
        $_.InterfaceIndex -eq $Route.InterfaceIndex
    }

    $Results += [PSCustomObject]@{
        DestinationPrefix = $Route.DestinationPrefix
        NextHop           = $Route.NextHop
        InterfaceAlias    = $Route.InterfaceAlias
        InterfaceIndex    = $Route.InterfaceIndex
        RouteMetric       = $Route.RouteMetric
        Protocol          = $Route.Protocol
        AddressFamily     = $Route.AddressFamily
        InterfaceIPv4     = ($InterfaceInfo.IPv4Address.IPAddress -join ",")
        InterfaceIPv6     = ($InterfaceInfo.IPv6Address.IPAddress -join ",")
        DefaultGateway    = ($InterfaceInfo.IPv4DefaultGateway.NextHop -join ",")
    }
}

$ScriptEnd = Get-Date
$Elapsed   = $ScriptEnd - $ScriptStart

# Summary
$Summary = @"
Network Route Enumeration Report
--------------------------------------------
Script Start: $ScriptStart
Script End:   $ScriptEnd
Elapsed Time: $Elapsed
Total Routes: $($Results.Count)
Address Family Filter: $AddressFamily
--------------------------------------------
"@

Write-Host $Summary
$Summary | Out-File $OutputFile

# Output detailed routes
foreach ($Entry in $Results | Sort-Object DestinationPrefix) {

@"
Destination:    $($Entry.DestinationPrefix)
Next Hop:       $($Entry.NextHop)
Interface:      $($Entry.InterfaceAlias)
InterfaceIndex: $($Entry.InterfaceIndex)
Route Metric:   $($Entry.RouteMetric)
Protocol:       $($Entry.Protocol)
Address Family: $($Entry.AddressFamily)
Interface IPv4: $($Entry.InterfaceIPv4)
Interface IPv6: $($Entry.InterfaceIPv6)
Default Gateway:$($Entry.DefaultGateway)
------------------------------------------------------------
"@ | Tee-Object -FilePath $OutputFile -Append
}

Write-Host "Results written to $OutputFile"