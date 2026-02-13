# Mastering Windows Incident Response
# Author: Anthony Valente
# Company: Network Defense Solutions, Inc.
# For Educational Use Only
# Shadow IT - Virtual Machine Inventory

param(
    [int]$DaysBack = 30
)

# ----------------------------
# Initialize
# ----------------------------

$StartTime = Get-Date
$Timestamp = $StartTime.ToString("yyyyMMdd_HHmmss")
$LogFile = "${Timestamp}_shadowit_vm_inventory.log"
$CutOff = (Get-Date).AddDays(-$DaysBack)
$EventCount = 0

"========== SHADOW IT VM INVENTORY ==========" | Out-File $LogFile
"Script Start Time: $StartTime" | Out-File $LogFile -Append
"Days Queried: $DaysBack" | Out-File $LogFile -Append
"Host Running Script: $env:COMPUTERNAME" | Out-File $LogFile -Append
"--------------------------------------------" | Out-File $LogFile -Append

# ----------------------------
# Retrieve VMs
# ----------------------------

$VMs = Get-VM | Where-Object { $_.CreationTime -ge $CutOff }

if ($VMs) {
    foreach ($vm in $VMs) {

        $EventCount++

        $NetworkInfo = Get-VMNetworkAdapter -VMName $vm.Name -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty IPAddresses -ErrorAction SilentlyContinue

        $Output = @"
VM Name      : $($vm.Name)
State        : $($vm.State)
CreationTime : $($vm.CreationTime)
Uptime       : $($vm.Uptime)
IP Addresses : $NetworkInfo
--------------------------------------------
"@

        $Output | Out-File $LogFile -Append
    }
}
else {
    "No VMs found within the specified time range." | Out-File $LogFile -Append
}

# ----------------------------
# Completion
# ----------------------------

$EndTime = Get-Date
$Duration = New-TimeSpan -Start $StartTime -End $EndTime

"============================================" | Out-File $LogFile -Append
"Script End Time: $EndTime" | Out-File $LogFile -Append
"Duration: $($Duration.ToString())" | Out-File $LogFile -Append
"Total VMs Found: $EventCount" | Out-File $LogFile -Append
"============================================" | Out-File $LogFile -Append

Write-Host "-------------------------------------"
Write-Host "Shadow IT VM Inventory Complete"
Write-Host "Start Time : $StartTime"
Write-Host "End Time   : $EndTime"
Write-Host "Duration   : $Duration"
Write-Host "Days Queried: $DaysBack"
Write-Host "VMs Found  : $EventCount"
Write-Host "Log File   : $LogFile"
Write-Host "-------------------------------------"