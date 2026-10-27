# Web servers and TLS: Apache and IIS

## Apache (CentOS)

- Installed `httpd` and `mod_ssl`, opened `http` and `https` in firewalld and confirmed the test page.
- Set `ServerName` to the DNS name from the [DNS lab](01-dns.md), so the site answers by name as well as by IP.
- Generated a self-signed key and certificate with `openssl` and served a separate document root over HTTPS.
- Configured two **name-based virtual hosts** on one IP address. Apache picks the site from the `Host` header in the request.

## IIS (Windows Server)

- Added the Web Server (IIS) role. An `index.html` in `C:\inetpub\wwwroot` takes precedence over `iisstart.htm` because it comes first in the default document list.
- Created a self-signed certificate in IIS Manager. Unlike Apache with `mod_ssl`, IIS doesn't use a certificate until you **add an HTTPS binding on port 443** and select it.
- Added a second website with its own host name and physical path, resolved through the Windows `hosts` file.

## Why the browser warns

A self-signed certificate still encrypts traffic, but no trusted authority vouches for it, and the name may not match (for example browsing to `127.0.0.1` when the certificate says `site2.corp.lab`). In production, I'd use a certificate from an internal CA or Let's Encrypt, with the subject alternative names matching every host name served.

## Security headers

The Apache script also sends `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy` and HSTS on the HTTPS site, and turns off version disclosure with `ServerTokens Prod` / `ServerSignature Off`. These are the checks my [Toolkit-v1](https://github.com/LAzzzyy1507/Toolkit-v1) certificate and header inspector reports on.

Script versions: [`apache-tls-vhosts.sh`](../scripts/linux/apache-tls-vhosts.sh), [`iis-tls-site.ps1`](../scripts/windows/iis-tls-site.ps1)
