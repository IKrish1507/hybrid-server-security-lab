#Requires -RunAsAdministrator
<#
  Windows Server DNS: primary zone, reverse zone, records, and delegation of the child zone to BIND on CentOS.
  Usage: .\dns-zones.ps1 -Zone corp.lab -ServerIp 10.0.2.2 -ChildNsIp 10.0.2.1
#>
param(
    [string]$Zone = 'corp.lab',
    [string]$ServerIp = '10.0.2.2',
    [string]$SiteIp = '10.0.2.20',
    [string]$NetworkId = '10.0.2.0/24',
    [string]$ChildLabel = 'it',
    [string]$ChildNsIp = '10.0.2.1'
)
$ErrorActionPreference = 'Stop'
$ChildZone = "$ChildLabel.$Zone"

Install-WindowsFeature DNS -IncludeManagementTools | Out-Null

if (-not (Get-DnsServerZone -Name $Zone -ErrorAction SilentlyContinue)) {
    Add-DnsServerPrimaryZone -Name $Zone -ZoneFile "$Zone.dns" -DynamicUpdate None
}
$reverseName = ((($NetworkId -split '/')[0] -split '\.')[2..0] -join '.') + '.in-addr.arpa'
if (-not (Get-DnsServerZone -Name $reverseName -ErrorAction SilentlyContinue)) {
    Add-DnsServerPrimaryZone -NetworkId $NetworkId -ZoneFile "$reverseName.dns" -DynamicUpdate None
}

function Add-ARecord([string]$Name, [string]$Ip) {
    if (-not (Get-DnsServerResourceRecord -ZoneName $Zone -Name $Name -RRType A -ErrorAction SilentlyContinue)) {
        Add-DnsServerResourceRecordA -ZoneName $Zone -Name $Name -IPv4Address $Ip -CreatePtr
    }
}
Add-ARecord 'ns' $ServerIp
Add-ARecord 'mail' $ServerIp
Add-ARecord 'site' $SiteIp
if (-not (Get-DnsServerResourceRecord -ZoneName $Zone -Name 'www' -RRType CName -ErrorAction SilentlyContinue)) {
    Add-DnsServerResourceRecordCName -ZoneName $Zone -Name 'www' -HostNameAlias "site.$Zone"
}
if (-not (Get-DnsServerResourceRecord -ZoneName $Zone -Name '@' -RRType Mx -ErrorAction SilentlyContinue)) {
    Add-DnsServerResourceRecordMX -ZoneName $Zone -Name '.' -MailExchange "mail.$Zone" -Preference 10
}

# Without this delegation Windows answers NXDOMAIN for names in the child zone instead of referring to BIND.
if (-not (Get-DnsServerZoneDelegation -Name $Zone -ChildZoneName $ChildLabel -ErrorAction SilentlyContinue)) {
    Add-DnsServerZoneDelegation -Name $Zone -ChildZoneName $ChildLabel -NameServer "ns.$ChildZone" -IPAddress $ChildNsIp
}

# An authoritative lab server doesn't need to recurse for clients.
Set-DnsServerRecursion -Enable $false

Write-Host '--- checks'
Resolve-DnsName "www.$Zone" -Server 127.0.0.1 -DnsOnly | Format-Table -AutoSize
Resolve-DnsName $SiteIp -Server 127.0.0.1 -DnsOnly | Format-Table -AutoSize
Get-DnsServerZoneDelegation -Name $Zone | Format-Table -AutoSize
Write-Host "Child zone test (needs BIND running on $ChildNsIp):"
Resolve-DnsName "www.$ChildZone" -Server $ChildNsIp -DnsOnly -ErrorAction Continue | Format-Table -AutoSize
