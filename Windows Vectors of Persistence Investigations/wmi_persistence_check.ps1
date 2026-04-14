# Event filters
Get-CimInstance -Namespace root\subscription -ClassName __EventFilter |
  Select-Object __PATH, Name, Query, QueryLanguage | Format-List

# Event consumers (note the concrete consumer classes will appear)
Get-CimInstance -Namespace root\subscription -ClassName __EventConsumer |
  Select-Object __PATH, __CLASS, Name | Format-List

# Filter-to-consumer bindings
Get-CimInstance -Namespace root\subscription -ClassName __FilterToConsumerBinding |
  Select-Object __PATH, Filter, Consumer | Format-List
