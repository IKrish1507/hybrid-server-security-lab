# Troubleshooting log

Most failures in this lab came from one missing layer around a service, not the service itself. This is the method I used: check the service, then the firewall, then SELinux, then permissions, then name resolution, then routing.

## No internet for package installs

**Symptom:** `dnf install` failed with a curl timeout. `ping 8.8.8.8` returned *Destination Host Unreachable* from 10.0.2.1.

**Cause:** the default route was going out of `ens192`, the private lab adapter, which has no gateway.

**Fix:** stopped the lab adapter from taking the default route (`nmcli con mod ens192 ipv4.never-default yes`, then re-activate) and confirmed with `ip route` that the default route goes via `ens160`.

## Child zone names didn't resolve from Windows

**Cause:** the parent zone `corp.lab` had no delegation for `it`, so Windows answered "non-existent domain" instead of referring the query to BIND.

**Fix:** added a delegation for `it.corp.lab` pointing to `ns.it.corp.lab` at 10.0.2.1.

## BIND zone loaded with the wrong names

**Cause:** missing trailing dots in the SOA and NS fields, so BIND appended the zone name.

**Fix:** fully qualified names end with `.`. Always run `named-checkzone` before reloading.

## Samba share refused despite `chmod 777`

**Cause:** SELinux. The directory had the default label, not `samba_share_t`.

**Fix:** `semanage fcontext -a -t samba_share_t "/share/smb(/.*)?"` then `restorecon -Rv /share/smb`. After that, tighten the mode back down (`2770` with a group).

## Shell rejected the NFS export line

**Cause:** I passed the export line to `nano` as arguments, and bash choked on the parentheses.

**Fix:** open `/etc/exports` (or a file in `/etc/exports.d/`) and type the line inside it, then `exportfs -rav`.

## Group member couldn't write to new files

**Cause:** SetGID fixed the group owner, but umask `0022` left files at `644`.

**Fix:** a default ACL giving the group `rwx`. Also, group membership only applies to a new login (`su - user`).

## IIS certificate created but HTTPS didn't work

**Cause:** IIS needs an explicit HTTPS binding on port 443 with the certificate selected.

**Fix:** Edit Bindings → Add → https → choose the certificate.

## Print job stuck in the CUPS queue

**Check:** LPD service running on Windows, TCP 515 open in the Windows firewall, and the queue name in `lpd://10.0.2.2/<name>` matching the share name exactly.
