# Print services: CUPS and Windows LPD

## CUPS on CentOS

- Installed CUPS and `cups-pdf` (from EPEL) to create a virtual PDF printer, so the whole print path could be tested without hardware.
- Changed the `Out` directory in `/etc/cups/cups-pdf.conf` to a dedicated directory with mode `700`, because the default location often isn't writable by the background process.
- Added the printer through the CUPS web interface on port 631, printed a test page and checked it with `lpstat -p`. `export PRINTER=...` in `~/.bashrc` sets a persistent default.

## Windows printer shared to Linux over LPD

- Created a text printer whose local port is a file path, with the Generic / Text Only driver, and shared it.
- Windows shares printers over SMB by default, so I added the Print and Document Services role with the **LPD Service** for Unix-style clients.
- On CentOS, added it in CUPS as `lpd://10.0.2.2/TextPrinter` (the queue name must match the Windows share name). `echo "Hello from CentOS" | lp` produced the text in the Windows port file.

If a job stays queued, check three things: the TCP/IP Print Server (LPD) service is running, TCP 515 is allowed through the Windows firewall, and the share name matches the queue name in the URL.

## Security trade-off I noted

The lab used `setenforce 0` (SELinux permissive) so CUPS wouldn't be blocked. That lasts until reboot and turns off protection for the whole system, not just CUPS. On a real server I'd read the denial with `ausearch -m avc` and fix the specific label or boolean instead. I'd also allow TCP 515 only from the lab subnet, not from any address.
