#!/usr/bin/env bash
# BIND on CentOS Stream: authoritative for the child zone (delegated from Windows) and the lab reverse zone.
# Usage: sudo ZONE=it.corp.lab NS_IP=10.0.2.1 SITE_IP=10.0.2.10 ./dns-bind.sh
set -euo pipefail

ZONE=${ZONE:-it.corp.lab}
REV=${REV:-2.0.10.in-addr.arpa}
NS_IP=${NS_IP:-10.0.2.1}
SITE_IP=${SITE_IP:-10.0.2.10}
LAB_NET=${LAB_NET:-10.0.2.0/24}
SERIAL=$(date +%Y%m%d%H)

dnf install -y bind bind-utils

# Listen on all addresses but answer only the loopback and the lab network, with no recursion for outsiders.
sed -i 's/listen-on port 53 { 127.0.0.1; };/listen-on port 53 { any; };/' /etc/named.conf
sed -i "s|allow-query     { localhost; };|allow-query     { localhost; $LAB_NET; };|" /etc/named.conf

if ! grep -q "zone \"$ZONE\"" /etc/named.conf; then
  cat >> /etc/named.conf <<EOF

zone "$ZONE" IN { type master; file "$ZONE.zone"; allow-transfer { none; }; };
zone "$REV" IN { type master; file "$REV.zone"; allow-transfer { none; }; };
EOF
fi

# Fully qualified names end with a dot, or BIND appends the zone name again.
cat > "/var/named/$ZONE.zone" <<EOF
\$TTL 1D
@       IN SOA  ns.$ZONE. admin.$ZONE. ( $SERIAL 1D 1H 1W 3H )
        IN NS   ns.$ZONE.
        IN MX   10 mail.$ZONE.
ns      IN A    $NS_IP
mail    IN A    $NS_IP
site    IN A    $SITE_IP
www     IN CNAME site
EOF

cat > "/var/named/$REV.zone" <<EOF
\$TTL 1D
@       IN SOA  ns.$ZONE. admin.$ZONE. ( $SERIAL 1D 1H 1W 3H )
        IN NS   ns.$ZONE.
${NS_IP##*.}       IN PTR  ns.$ZONE.
${SITE_IP##*.}      IN PTR  site.$ZONE.
EOF

# named runs as the named group and must be able to read the zone files.
chgrp named "/var/named/$ZONE.zone" "/var/named/$REV.zone"
chmod 640 "/var/named/$ZONE.zone" "/var/named/$REV.zone"

named-checkconf /etc/named.conf
named-checkzone "$ZONE" "/var/named/$ZONE.zone"
named-checkzone "$REV" "/var/named/$REV.zone"

firewall-cmd --permanent --add-service=dns
firewall-cmd --reload
systemctl enable --now named
systemctl reload named

echo "--- checks"
dig +short @127.0.0.1 "site.$ZONE"
dig +short @127.0.0.1 "www.$ZONE"
dig +short @127.0.0.1 -x "$SITE_IP"
