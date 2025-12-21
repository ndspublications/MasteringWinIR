#THIS SCRIPT HAS AN ACCOMPANYING APPLICATION
#THAT WILL PERFORM THE LOOKUPS OF ALL THE USERS
#TO COMPARE WHEN THE LAST PASSWORD CHANGE WAS 
#IN ACCORDANCE WITH THE LAST TIME THE PASSWORD WAS CHANGED
#IF IT'S WITHIN THE WINDOW, IT WILL HELP IDENTIFY THOSE VPS
#THAT THEY NEED A PASSWORD CHANGE. 

# ===========================
# CONFIGURATION
# ===========================

# Targeted job titles (case-insensitive partial match)
$TargetTitles = @(
    "HR",
    "Vice President",
    "VP",
    "CISO",
    "Manager",
    "Director"
)

# Include disabled accounts?
$IncludeDisabled = $false   # $true or $false

# Output file
$OutputCsv = "C:\AD_Credential_Hygiene_Export.csv"

Import-Module ActiveDirectory

$users = Get-ADUser -Filter * -Properties `
    SamAccountName,
    DisplayName,
    Title,
    EmailAddress,
    LastLogonDate,
    Enabled,
    PasswordLastSet

# Role-based filtering
$filtered = $users | Where-Object {
    $_.Title -and (
        $TargetTitles | Where-Object {
            $_ -and ($_.ToLower() -in $_.Title.ToLower())
        }
    )
}

# Enabled / Disabled filtering
if (-not $IncludeDisabled) {
    $filtered = $filtered | Where-Object { $_.Enabled -eq $true }
}

# Final projection
$report = $filtered | Select-Object @{
        Name = "SamAccountName"
        Expression = { $_.SamAccountName }
    }, @{
        Name = "DisplayName"
        Expression = { $_.DisplayName }
    }, @{
        Name = "Title"
        Expression = { $_.Title }
    }, @{
        Name = "Email"
        Expression = { $_.EmailAddress }
    }, @{
        Name = "LastLogon"
        Expression = { $_.LastLogonDate }
    }, @{
        Name = "AccountStatus"
        Expression = {
            if ($_.Enabled) { "Enabled" } else { "Disabled" }
        }
    }, @{
        Name = "PasswordLastChanged"
        Expression = { $_.PasswordLastSet }
    }

# Export
$report | Export-Csv $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host "[+] Export complete:" $OutputCsv
Write-Host "[+] Users exported:" $report.Count

