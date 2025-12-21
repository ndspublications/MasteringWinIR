Get-ADUser -Filter * `
    -SearchBase "OU=Users,OU=Corporate,DC=company,DC=local" `
    -Properties DisplayName, Title, EmailAddress |
Select-Object DisplayName, Title, EmailAddress
