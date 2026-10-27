#!/usr/bin/env bash
# ext4 user quota, a tar backup with a verified restore, and a nightly cron job.
# WARNING: unmounts MNT to enable quotas. Use a dedicated data partition listed in /etc/fstab, in a lab VM.
# Usage: sudo DEV=/dev/sdb1 MNT=/opt QUOTA_USER=alice ./quota-backup.sh
set -euo pipefail

: "${DEV:?set DEV to the ext4 partition, e.g. DEV=/dev/sdb1}"
MNT=${MNT:-/opt}
QUOTA_USER=${QUOTA_USER:-alice}
HARD_KB=${HARD_KB:-61440}               # 60 MB hard limit (edquota and setquota count in 1 KB blocks)
BACKUP_DIR=${BACKUP_DIR:-/backup}

dnf install -y quota tar
id -u "$QUOTA_USER" >/dev/null 2>&1 || useradd -m "$QUOTA_USER"

# Quota support can only be switched on while the file system is unmounted.
umount "$MNT"
tune2fs -O quota "$DEV"
mount "$MNT"
quotaon -v "$MNT" || true               # already on is fine
setquota -u "$QUOTA_USER" 0 "$HARD_KB" 0 0 "$MNT"
install -d -o "$QUOTA_USER" "$MNT/$QUOTA_USER"

echo "--- quota check"
su - "$QUOTA_USER" -c "dd if=/dev/zero of='$MNT/$QUOTA_USER/ok.bin' bs=1M count=50 status=none" && echo "OK: 50 MB write allowed"
if su - "$QUOTA_USER" -c "dd if=/dev/zero of='$MNT/$QUOTA_USER/big.bin' bs=1M count=100 status=none" 2>/dev/null; then
  echo "FAIL: 100 MB write was not stopped"; exit 1
else
  echo "OK: 100 MB write stopped by the quota"
fi
rm -f "$MNT/$QUOTA_USER/ok.bin" "$MNT/$QUOTA_USER/big.bin"
repquota -s "$MNT"

echo "--- backup and restore test"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
ARCHIVE="$BACKUP_DIR/$(basename "$MNT")-$(date +%F).tar.gz"
tar -czf "$ARCHIVE" -C / "${MNT#/}"
tar -tzf "$ARCHIVE" | head
RESTORE=$(mktemp -d)
tar -xzf "$ARCHIVE" -C "$RESTORE"
# A backup only counts once a restore has been proven.
diff -r --exclude=aquota.user --exclude=aquota.group --exclude=lost+found "$MNT" "$RESTORE/${MNT#/}" && echo "OK: restore matches $MNT"
rm -rf "$RESTORE"

# /etc/cron.d entries need a user field, and % must be escaped as \% inside cron commands.
cat > /etc/cron.d/lab-backup <<EOF
30 2 * * * root tar -czf $BACKUP_DIR/$(basename "$MNT")-\$(date +\%F).tar.gz -C / ${MNT#/}
EOF
chmod 644 /etc/cron.d/lab-backup
echo "Scheduled: $(cat /etc/cron.d/lab-backup)"
