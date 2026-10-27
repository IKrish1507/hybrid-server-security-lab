#!/usr/bin/env bash
# Group collaboration directory: SetGID for group ownership, a default ACL for group write, no access for anyone else.
# Usage: sudo DIR=/srv/team GROUP=team MEMBERS="alice bob" OUTSIDER=carol ./shared-dir-acl.sh
set -euo pipefail

DIR=${DIR:-/srv/team}
GROUP=${GROUP:-team}
MEMBERS=${MEMBERS:-"alice bob"}
OUTSIDER=${OUTSIDER:-carol}

groupadd -f "$GROUP"
for user in $MEMBERS "$OUTSIDER"; do
  id -u "$user" >/dev/null 2>&1 || useradd -m "$user"
done
for user in $MEMBERS; do
  usermod -aG "$GROUP" "$user"
done

mkdir -p "$DIR"
chown root:"$GROUP" "$DIR"
chmod 2770 "$DIR"                       # s in the group execute position: new files inherit the group
setfacl -m g:"$GROUP":rwx "$DIR"
setfacl -d -m g:"$GROUP":rwx "$DIR"     # default ACL: group can write new files despite umask 0022

echo "--- checks"
ls -ld "$DIR"
getfacl -p "$DIR"

first=$(echo "$MEMBERS" | awk '{print $1}')
second=$(echo "$MEMBERS" | awk '{print $2}')
# su - starts a new login, which is needed for the new group membership to apply.
su - "$first" -c "echo draft > '$DIR/from-$first.txt'"
stat -c '%n  owner=%U group=%G mode=%A' "$DIR/from-$first.txt"
if [ -n "$second" ]; then
  su - "$second" -c "echo edit >> '$DIR/from-$first.txt'" && echo "OK: $second can edit $first's file"
fi
if su - "$OUTSIDER" -c "ls '$DIR'" >/dev/null 2>&1; then
  echo "FAIL: $OUTSIDER can list $DIR"; exit 1
else
  echo "OK: $OUTSIDER is denied"
fi
