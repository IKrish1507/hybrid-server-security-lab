#!/usr/bin/env bash
# NFSv4 export and a group-restricted Samba share on CentOS Stream, with persistent SELinux labels.
# Usage: sudo LAB_NET=10.0.2.0/24 GROUP=team ./nfs-samba.sh
set -euo pipefail

LAB_NET=${LAB_NET:-10.0.2.0/24}
SMB_HOSTS=${SMB_HOSTS:-"127. 10.0.2."}
GROUP=${GROUP:-team}
NFS_DIR=${NFS_DIR:-/share/nfs}
SMB_DIR=${SMB_DIR:-/share/smb}

dnf install -y nfs-utils samba samba-client policycoreutils-python-utils
groupadd -f "$GROUP"

# --- NFS: lab network only, root on a client is squashed to nobody.
mkdir -p "$NFS_DIR"
chown nobody:nobody "$NFS_DIR"
chmod 775 "$NFS_DIR"
echo "$NFS_DIR $LAB_NET(rw,sync,root_squash,no_subtree_check)" > /etc/exports.d/lab.exports
systemctl enable --now nfs-server
exportfs -rav
firewall-cmd --permanent --add-service=nfs --add-service=mountd --add-service=rpc-bind

# --- Samba: group members only, from the lab network only.
mkdir -p "$SMB_DIR"
chown root:"$GROUP" "$SMB_DIR"
chmod 2770 "$SMB_DIR"
# SELinux blocks Samba from unlabelled directories even with chmod 777. semanage makes the label survive a relabel.
semanage fcontext -a -t samba_share_t "$SMB_DIR(/.*)?" 2>/dev/null || semanage fcontext -m -t samba_share_t "$SMB_DIR(/.*)?"
restorecon -Rv "$SMB_DIR"

if ! grep -q '^\[smb_share\]' /etc/samba/smb.conf; then
  cat >> /etc/samba/smb.conf <<EOF

[smb_share]
   path = $SMB_DIR
   valid users = @$GROUP
   writable = yes
   browseable = yes
   hosts allow = $SMB_HOSTS
   create mask = 0660
   directory mask = 2770
EOF
fi
# Refuse SMB1 clients.
grep -q 'server min protocol' /etc/samba/smb.conf || sed -i '/^\[global\]/a \   server min protocol = SMB2_10' /etc/samba/smb.conf

testparm -s >/dev/null
systemctl enable --now smb
firewall-cmd --permanent --add-service=samba
firewall-cmd --reload

echo "--- checks"
exportfs -v
ls -Zd "$SMB_DIR"
echo "Samba passwords are separate from Linux passwords. Add each member with:  smbpasswd -a <user>"
echo "Then test from Linux:  smbclient //127.0.0.1/smb_share -U <user> -c 'ls'"
