Get-ADUser -Filter * -Properties DisplayName, Title, EmailAddress |
Select-Object DisplayName, Title, EmailAddress |
Export-Csv "C:\AD_Users_Name_Title_Email.csv" -NoTypeInformation -Encoding UTF8
