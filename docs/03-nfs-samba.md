# Cross-platform file sharing: NFS and SMB in both directions

| Share | Server | Client | Identity model |
|---|---|---|---|
| NFSv4 export of `/share/nfs` | CentOS | Windows (Client for NFS) | Numeric UID/GID, export list by network |
| `C:\shares\nfs` | Windows Server for NFS | CentOS `mount -t nfs` | UID/GID mapping |
| Samba share `smb_share` | CentOS | Windows Explorer | Samba user database (separate passwords) |
| `C:\shares\smb` | Windows SMB | CentOS `smbclient` | Windows local account |

## What I learned

- **NFS and SMB trust different things.** NFS trusts the client's numeric UID/GID, limited by the export list. SMB authenticates a named account with a password. Every cross-platform setup needs an agreed way to map users and permissions.
- **Samba passwords are separate.** `smbpasswd -a` adds a user to Samba's own database, even when the Linux username matches.
- **SELinux sits above file permissions.** The Samba share was refused even with `chmod 777` until the directory had the `samba_share_t` label. `chcon` fixes it until the next relabel; `semanage fcontext` plus `restorecon` makes it permanent (the script uses the permanent form).
- **Restrict who can connect.** The Samba share uses `hosts allow = 127. 10.0.2.`, and the NFS export is limited to `10.0.2.0/24`.

## Hardening I added in the scripts (beyond the lab)

- Samba access limited to a group (`valid users = @<group>`) with mode `2770`, instead of world-writable `777`.
- NFS exported with `root_squash`, so root on a client isn't root on the share.
- Windows: SMB1 confirmed disabled (the protocol behind EternalBlue/WannaCry) and SMB encryption turned on.
- Windows NFS share: no access for unknown clients; read/write granted only to the CentOS host.

See also the routing problem I hit before any of this worked: [troubleshooting.md](troubleshooting.md#no-internet-for-package-installs).

Script versions: [`nfs-samba.sh`](../scripts/linux/nfs-samba.sh), [`file-shares.ps1`](../scripts/windows/file-shares.ps1)
