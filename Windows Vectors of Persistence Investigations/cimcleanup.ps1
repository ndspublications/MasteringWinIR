#CIM PERSISTENCE SHOULD ONLY BE RUN IN YOUR SANDBOX DO NOT RUN IN PRODUCTION
#THIS CODE WAS INCLUDED AS A HANDS-ON DEMO / LAB EXERCISE.

# CLEAN UP ACTIONS (SCRIPT MUS T BE RUN AS ADMINISTRATOR)
Get-CimInstance -Namespace root\subscription -ClassName __FilterToConsumerBinding | 
    Where-Object { $_.Filter -like "*Demo_StartupPersistence_Filter*" } | Remove-CimInstance

Get-CimInstance -Namespace root\subscription -ClassName CommandLineEventConsumer | 
    Where-Object Name -eq "Demo_StartupPersistence_Consumer" | Remove-CimInstance

Get-CimInstance -Namespace root\subscription -ClassName __EventFilter | 
    Where-Object Name -eq "Demo_StartupPersistence_Filter" | Remove-CimInstance

Write-Host "Persistence removed." -ForegroundColor Green
