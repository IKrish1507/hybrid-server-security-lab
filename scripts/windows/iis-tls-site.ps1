#Requires -RunAsAdministrator
<#
  IIS: a second website selected by host header, with an HTTPS binding and a self-signed certificate.
  IIS doesn't use a certificate until an https binding on 443 is added and the certificate is attached to it.
  Usage: .\iis-tls-site.ps1 -HostName site2.corp.lab
#>
param(
    [string]$HostName = 'site2.corp.lab',
    [string]$SiteName = 'site2',
    [string]$ServerIp = '10.0.2.2'
)
$ErrorActionPreference = 'Stop'

Install-WindowsFeature Web-Server -IncludeManagementTools | Out-Null
Import-Module WebAdministration

$root = "C:\inetpub\$SiteName"
New-Item -ItemType Directory -Path $root -Force | Out-Null
Set-Content -Path "$root\index.html" -Value "<h1>$HostName</h1><p>Served by IIS on Windows Server</p>"

# Resolve the name locally so no DNS record is needed for the test.
$hosts = "$env:SystemRoot\System32\drivers\etc\hosts"
if (-not (Select-String -Path $hosts -Pattern ([regex]::Escape($HostName)) -Quiet)) {
    Add-Content -Path $hosts -Value "$ServerIp`t$HostName"
}

if (-not (Get-Website -Name $SiteName)) {
    New-Website -Name $SiteName -PhysicalPath $root -Port 80 -HostHeader $HostName | Out-Null
}

$cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=$HostName" } | Select-Object -First 1
if (-not $cert) {
    $cert = New-SelfSignedCertificate -DnsName $HostName -CertStoreLocation Cert:\LocalMachine\My -NotAfter (Get-Date).AddYears(1)
}
if (-not (Get-WebBinding -Name $SiteName -Protocol https)) {
    New-WebBinding -Name $SiteName -Protocol https -Port 443 -HostHeader $HostName -SslFlags 1   # 1 = SNI
    (Get-WebBinding -Name $SiteName -Protocol https).AddSslCertificate($cert.Thumbprint, 'My')
}

# Don't advertise the framework.
Remove-WebConfigurationProperty -PSPath "IIS:\Sites\$SiteName" -Filter 'system.webServer/httpProtocol/customHeaders' -Name '.' -AtElement @{name = 'X-Powered-By'} -ErrorAction SilentlyContinue
Add-WebConfigurationProperty -PSPath "IIS:\Sites\$SiteName" -Filter 'system.webServer/httpProtocol/customHeaders' -Name '.' -Value @{name = 'X-Content-Type-Options'; value = 'nosniff'} -ErrorAction SilentlyContinue

Write-Host '--- checks'
Get-WebBinding -Name $SiteName | Format-Table protocol, bindingInformation, sslFlags -AutoSize
(Invoke-WebRequest -UseBasicParsing "http://$HostName").StatusCode
Write-Host "Open https://$HostName - the browser warns because the certificate is self-signed, which is expected."
