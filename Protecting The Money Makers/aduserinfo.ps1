
Get-ADUser -Filter * -Properties DisplayName, Title, EmailAddress |
Select-Object DisplayName, Title, EmailAddress
