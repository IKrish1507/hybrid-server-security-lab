# Security review: what I'd change before production

A lab favours getting services working. This review lists the gaps I'd close before the same setup served real users, ordered by risk.

| # | Finding | Risk | Fix |
|---|---|---|---|
| 1 | SELinux set to permissive (`setenforce 0`) to get CUPS working | **High**: removes mandatory access control for every service on the host | Keep enforcing. Read the denial with `ausearch -m avc -ts recent`, then fix the label or boolean (`audit2why` explains it) |
| 2 | World-writable share directories (`chmod 777`) used while debugging Samba | **High**: any local user or compromised service can plant or alter files | Group-owned `2770` with a default ACL; Samba `valid users = @group` |
| 3 | DNS `allow-query { any; }` with recursion on | **Medium**: open resolver, can be abused for amplification attacks | Restrict `allow-query` to internal subnets, `recursion no` on authoritative servers, `allow-transfer` to named secondaries only |
| 4 | Self-signed certificates | **Medium**: users learn to click through warnings, which makes MITM easier | Internal CA or Let's Encrypt; SANs for every host name; HSTS once trusted |
| 5 | NFS uses AUTH_SYS (trusts the client's UID) | **Medium**: a client with root can impersonate any UID | Limit exports to known hosts, `root_squash`, and Kerberos (`sec=krb5p`) where possible |
| 6 | SMB without encryption and SMB1 status unverified | **Medium**: credentials and data readable on the wire; SMB1 is exploitable (EternalBlue) | `Set-SmbServerConfiguration -EncryptData $true`, confirm `EnableSMB1Protocol` is `False` |
| 7 | LPD (TCP 515) open to any address | **Low**: legacy, unauthenticated protocol | Allow only the subnet that needs it, or use IPP over HTTPS |
| 8 | Web servers disclose version banners | **Low**: helps attackers match known CVEs | `ServerTokens Prod`, `ServerSignature Off`; remove the IIS `X-Powered-By` header |
| 9 | Backups stored on the same host, unencrypted | **Medium**: lost along with the server in ransomware or disk failure | Copy off-host, encrypt (e.g. `gpg` or `age`), keep one offline copy, and schedule restore tests |
| 10 | Shared local Administrator / root use | **Medium**: no accountability, larger blast radius | Named admin accounts, `sudo` with logging, separate admin and daily accounts |

## Controls that were already in place

- firewalld and Windows Firewall enabled, with only the needed services opened.
- Disk quotas limiting how much one account can consume.
- Restore tested for both tar and cpio archives.
- Host allow-lists on Samba and NFS.
- Zone and config validation before service reloads.
