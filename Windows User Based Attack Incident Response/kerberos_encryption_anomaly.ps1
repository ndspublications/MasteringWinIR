param([int]$Days=7)

$ScriptStart=Get-Date
$TimeStamp=$ScriptStart.ToString("yyyyMMddHHmmss")
$OutputFile="kerberos_encryption_$TimeStamp.log"
$StartTime=(Get-Date).AddDays(-$Days)

$Events=Get-WinEvent -FilterHashtable @{
    LogName='Security'
    ID=4769
    StartTime=$StartTime
}

$Suspicious=foreach($Event in $Events){
    $Xml=[xml]$Event.ToXml()
    $EncType=($Xml.Event.EventData.Data | Where {$_.Name -eq "TicketEncryptionType"}).'#text'
    if($EncType -eq "0x17"){
        [PSCustomObject]@{
            TimeCreated=$Event.TimeCreated
            Encryption=$EncType
        }
    }
}

$ScriptEnd=Get-Date
$Duration=$ScriptEnd-$ScriptStart

"Kerberos Encryption Anomaly" | Out-File $OutputFile
"RC4 Tickets Found: $($Suspicious.Count)" | Out-File $OutputFile -Append
"Duration: $Duration" | Out-File $OutputFile -Append
"----------------------------------------" | Out-File $OutputFile -Append

$Suspicious | Tee-Object -FilePath $OutputFile -Append