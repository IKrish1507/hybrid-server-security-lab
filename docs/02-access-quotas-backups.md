# Access control, disk quotas and backups (CentOS)

## Group collaboration directory

Goal: members of one group can all create and edit files in a shared directory, and nobody else can enter it.

1. Created the directory as root, set its group and mode `770`.
2. A file created by one member belonged to that user's own primary group, so another member couldn't edit it. Group ownership was the problem.
3. `chmod 2770` (SetGID) made new files inherit the directory's group. The listing shows `drwxrws---`.
4. That fixed ownership but not access. With the default umask `0022` new files are `644`, so the group could read but not write. A default ACL, `setfacl -d -m g:<group>:rwx`, gave the group write access on every new file.
5. A user outside the group couldn't even list the directory, as intended.

Lesson: Linux access problems usually involve several layers (owner, group, mode, umask, ACL), and fixing one layer often exposes the next. Group membership changes also only apply to a new login session.

## Disk quotas (ext4)

- Quota support has to be enabled on an unmounted file system with `tune2fs -O quota`, then turned on with `quotaon -v`.
- I set a 60 MB hard block limit for a test user. Writing 50 MB with `dd` succeeded. Writing 100 MB failed with `Disk quota exceeded`, leaving a file of about 60 MB.
- `edquota` shows blocks in KB, so 60 MB is `61440` if the editor won't accept the `M` suffix.

Why it matters for security: quotas are a control against resource-exhaustion (one account or a compromised process filling a shared disk and taking services down).

## Backups and restore testing

| Tool | Archive | List | Restore |
|---|---|---|---|
| tar | `tar -czf opt.tar.gz -C / opt` | `tar -tzf` | `tar -xzf ... -C <dir> [path]` |
| cpio | `find /opt \| cpio -ov > opt.cpio` | `cpio -it < opt.cpio` | `cpio -idv < opt.cpio` |

- tar strips the leading `/`, so a single file is restored by its path without the slash.
- I restored a file from each archive, because a backup that has never been restored is an assumption, not a backup.
- Scheduling used `/etc/crontab`, which has a user field that personal crontabs don't. A `%` in a cron command must be escaped as `\%`, which matters when the archive name contains a date. I created the target directory first so the first run couldn't fail silently.

Script versions: [`shared-dir-acl.sh`](../scripts/linux/shared-dir-acl.sh), [`quota-backup.sh`](../scripts/linux/quota-backup.sh)
