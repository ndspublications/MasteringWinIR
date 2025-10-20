write-host "[!] Attempting to write proxy settings as system wide settings... "
$regPath = "HKLM:\Software\Microsoft\Windows\Currentversion\Internet Settings"
$nameValues = @{
  "ProxyEnable" = 1
  "ProxyServer" = "https://yourproxy:8080"
  }

  if (-not (Test-Path $regPath)){
    New-Item -Path $regPath -Force | out-null
    }

foreach ( $nameValuePair in $nameValues.GenerateEnumerator()) {
    $name = $nameValuePair.Key
    $value = $nameValuePair.Value
    Set-ItemProperty -Path $regPath -Name -$name -Type DWORD -Value $value
    }
write-host "[+] Changes have been made successfully [ OK ]"
