# Hybrid Server Security Lab

A two-server Linux and Windows network I built and secured in VMware Workstation: CentOS Stream 10 and Windows Server 2025 sharing a private 10.0.2.0/24 network. It covers the services a small organisation runs every day (DNS, shared storage, cross-platform file sharing and HTTPS web hosting), with a focus on the security layers that sit around each one: firewalls, SELinux, least-privilege permissions, disk quotas, encryption and tested backups.

> Built during the UTS subject 31338 Network Servers (2026) and written up independently. No university lab sheets or assessment material are included. Domain names and user accounts have been generalised.

## Network

```
                 Internet (NAT, package installs only)
                        |
                 ens160 (DHCP)
              +--------------------+            +----------------------+
              |  CentOS Stream 10  |  ens192    |  Windows Server 2025 |
              |  10.0.2.1          |------------|  10.0.2.2            |
              |  BIND (it.corp.lab)|  10.0.2.0/24  DNS (corp.lab)      |
              |  NFS, Samba        |            |  Server for NFS, SMB |
              |  Apache + TLS      |            |  IIS + TLS           |
              +--------------------+            +----------------------+
```

## What I built

| Area | Linux (CentOS) | Windows Server | Security focus |
|---|---|---|---|
| [DNS](docs/01-dns.md) | BIND authoritative for the child zone `it.corp.lab` plus reverse zone | Primary zone `corp.lab`, reverse zone, delegation to BIND | Zone validation before reload, restricted query scope, firewall port 53 only |
| [Access control, quotas, backups](docs/02-access-quotas-backups.md) | SetGID group directory with default ACLs, ext4 user quotas, tar/cpio backups on cron | | Least privilege, resource exhaustion limits, restore testing |
| [Cross-platform file sharing](docs/03-nfs-samba.md) | NFSv4 export, Samba share | Server for NFS, SMB share | Export and host allow-lists, SELinux labels, SMB1 disabled, SMB encryption |
| [Web servers and TLS](docs/04-web-tls.md) | Apache name-based virtual hosts, HTTPS with OpenSSL certificate | IIS site with host header, HTTPS binding | TLS, security headers, certificate trust |
| [Print services](docs/05-printing.md) | CUPS with virtual PDF printer | Text printer shared over LPD | Firewall scope for LPD (TCP 515), SELinux trade-off |

The full troubleshooting log is in [docs/troubleshooting.md](docs/troubleshooting.md). The [security review](docs/security-review.md) lists what I would change before running this outside a lab.

## Scripts

[`scripts/`](scripts) contains scripted versions of the manual steps I took in the lab, so the setup can be rebuilt in a fresh VM:

| Script | Runs on | Does |
|---|---|---|
| `linux/dns-bind.sh` | CentOS | Installs BIND, writes the child and reverse zones, validates, opens the firewall, tests with `dig` |
| `linux/shared-dir-acl.sh` | CentOS | Builds a SetGID group directory with default ACLs and verifies who can and can't get in |
| `linux/quota-backup.sh` | CentOS | Enables ext4 quotas, sets a hard limit, runs a backup, proves a restore, schedules it in cron |
| `linux/nfs-samba.sh` | CentOS | NFSv4 export and a group-restricted Samba share with persistent SELinux labels |
| `linux/apache-tls-vhosts.sh` | CentOS | Two name-based virtual hosts, a self-signed certificate, HTTPS and security headers |
| `windows/dns-zones.ps1` | Windows Server | Forward and reverse zones, records, delegation of `it.corp.lab` to BIND |
| `windows/file-shares.ps1` | Windows Server | Server for NFS share and an encrypted SMB share, SMB1 off |
| `windows/iis-tls-site.ps1` | Windows Server | Second IIS site with host header and an HTTPS binding |

Run them as root or Administrator in a disposable VM. Every script prints what it changed and finishes with a check.

## Skills demonstrated

Linux and Windows Server administration · BIND and Windows DNS · NFS and SMB/Samba · Apache and IIS · TLS certificates with OpenSSL · firewalld and Windows Firewall · SELinux · POSIX ACLs and SetGID · disk quotas · backup and restore with tar, cpio and cron · PowerShell · Bash · systematic troubleshooting

## Related project

[Toolkit-v1](https://github.com/LAzzzyy1507/Toolkit-v1) is my defensive security web app. Its certificate and header inspector and its private-network port scanner can be pointed at this lab.
