#Requires -RunAsAdministrator
<#
  Windows Server file sharing for the Linux side: a Server for NFS share limited to one host,
  and an SMB share for one local account with encryption on and SMB1 off.
  Usage: .\file-shares.ps1 -LinuxHost 10.0.2.1 -SmbUser smbuser
#>
param(
    [string]$LinuxHost = '10.0.2.1',
    [string]$NfsPath = 'C:\shares\nfs',
    [string]$SmbPath = 'C:\shares\smb',
    [string]$SmbUser = 'smbuser'
)
$ErrorActionPreference = 'Stop'

# --- NFS: no access by default, read/write only for the CentOS host.
Install-WindowsFeature FS-NFS-Service -IncludeManagementTools | Out-Null
New-Item -ItemType Directory -Path $NfsPath -Force | Out-Null
if (-not (Get-NfsShare -Name 'nfs_win' -ErrorAction SilentlyContinue)) {
    New-NfsShare -Name 'nfs_win' -Path $NfsPath -Permission no-access -EnableUnmappedAccess $true -Authentication sys
}
Grant-NfsSharePermission -Name 'nfs_win' -ClientName $LinuxHost -ClientType host -Permission readwrite -AllowRootAccess $false

# --- SMB: one named local account, NTFS and share permissions both limited to it.
if (-not (Get-LocalUser -Name $SmbUser -ErrorAction SilentlyContinue)) {
    $password = Read-Host -AsSecureString "Password for new local account $SmbUser"
    New-LocalUser -Name $SmbUser -Password $password -PasswordNeverExpires:$false | Out-Null
}
New-Item -ItemType Directory -Path $SmbPath -Force | Out-Null
icacls $SmbPath /inheritance:r /grant:r "Administrators:(OI)(CI)F" "SYSTEM:(OI)(CI)F" "${SmbUser}:(OI)(CI)M" | Out-Null
if (-not (Get-SmbShare -Name 'smb_win' -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name 'smb_win' -Path $SmbPath -ChangeAccess "$env:COMPUTERNAME\$SmbUser" -EncryptData $true | Out-Null
}

# SMB1 is the protocol behind EternalBlue / WannaCry. Linux smbclient supports SMB3 encryption.
Set-SmbServerConfiguration -EnableSMB1Protocol $false -EncryptData $true -Force

# Allow file sharing only from the lab network.
Get-NetFirewallRule -DisplayGroup 'File and Printer Sharing' | Set-NetFirewallRule -RemoteAddress '10.0.2.0/24' -Enabled True

Write-Host '--- checks'
Get-NfsSharePermission -Name 'nfs_win' | Format-Table -AutoSize
Get-SmbShare -Name 'smb_win' | Select-Object Name, Path, EncryptData | Format-Table -AutoSize
Get-SmbShareAccess -Name 'smb_win' | Format-Table -AutoSize
Get-SmbServerConfiguration | Select-Object EnableSMB1Protocol, EncryptData | Format-Table -AutoSize
Write-Host "From CentOS:  mount -t nfs ${env:COMPUTERNAME}:/nfs_win /mnt   and   smbclient //10.0.2.2/smb_win -U $SmbUser"
