#!/usr/bin/env bash
# Apache on CentOS Stream: two name-based virtual hosts, HTTPS with a self-signed certificate, security headers.
# Usage: sudo SITE1=www.corp.lab SITE2=www2.corp.lab ./apache-tls-vhosts.sh
set -euo pipefail

SITE1=${SITE1:-www.corp.lab}
SITE2=${SITE2:-www2.corp.lab}
IP=${IP:-10.0.2.1}
CERT=/etc/pki/tls/certs/lab-web.crt
KEY=/etc/pki/tls/private/lab-web.key

dnf install -y httpd mod_ssl openssl

for site in "$SITE1" "$SITE2"; do
  mkdir -p "/var/www/$site"
  echo "<h1>$site</h1><p>Served by Apache on CentOS</p>" > "/var/www/$site/index.html"
  grep -q " $site\$" /etc/hosts || echo "$IP $site" >> /etc/hosts
done
restorecon -R /var/www

# Self-signed certificate whose SANs cover both names, so the only browser warning is "untrusted issuer".
if [ ! -f "$CERT" ]; then
  openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
    -keyout "$KEY" -out "$CERT" \
    -subj "/CN=$SITE1" -addext "subjectAltName=DNS:$SITE1,DNS:$SITE2"
  chmod 600 "$KEY"
fi

cat > /etc/httpd/conf.d/lab-vhosts.conf <<EOF
ServerTokens Prod
ServerSignature Off
Header always set X-Content-Type-Options "nosniff"
Header always set X-Frame-Options "DENY"
Header always set Referrer-Policy "strict-origin-when-cross-origin"

<VirtualHost *:80>
    ServerName $SITE1
    DocumentRoot /var/www/$SITE1
</VirtualHost>

<VirtualHost *:80>
    ServerName $SITE2
    DocumentRoot /var/www/$SITE2
</VirtualHost>

<VirtualHost *:443>
    ServerName $SITE1
    DocumentRoot /var/www/$SITE1
    SSLEngine on
    SSLCertificateFile $CERT
    SSLCertificateKeyFile $KEY
    SSLProtocol -all +TLSv1.2 +TLSv1.3
    Header always set Strict-Transport-Security "max-age=31536000"
</VirtualHost>
EOF

apachectl configtest
firewall-cmd --permanent --add-service=http --add-service=https
firewall-cmd --reload
systemctl enable --now httpd
systemctl reload httpd

echo "--- checks"
curl -s "http://$SITE1" | head -1
curl -s "http://$SITE2" | head -1
curl -sk -D - "https://$SITE1" -o /dev/null | grep -iE '^(HTTP|strict-transport|x-content-type|server):'
openssl s_client -connect "$IP:443" -servername "$SITE1" </dev/null 2>/dev/null | openssl x509 -noout -subject -ext subjectAltName
