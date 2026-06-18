# Mikrotik Config Backup

This computer (`n100d.steenburg.net`) runs **vsftpd** as a passive FTP receiver. Each Mikrotik device has its own built-in scheduler that exports its config and FTPs the files here. Nothing on this machine initiates the transfer.

## FTP server

- **Service**: `vsftpd.service` (systemd, always running)
- **Config**: `/etc/vsftpd.conf`
- **FTP user**: `ftp-files` (local Linux account)
- **Backup directory**: `/home/ftp-files/`
- **Transfer log**: `/var/log/vsftpd.log`

## Mikrotik devices

| Device name | IP | Approx. backup time |
|-------------|-----|---------------------|
| `mikro-den` | 192.168.1.27 | ~22:01 |
| `mikro-switch01` | 192.168.2.20 | ~22:01 |
| `mikro-masterbed` | 192.168.1.28 | ~00:25 |
| `mikro-cottage` | 192.168.1.26 | ~13:14 |
| `mikro-livingroom` | 192.168.1.29 | ~20:37 |

Each device uploads two files per run:
- `mikro-{name}-YYYYMMDD.backup` — binary backup (full restore)
- `mikro-{name}-YYYYMMDD.rsc` — text export (human-readable config)

## Credentials

Mikrotik admin credentials are in `/home/rsteenbu/secrets/mikrotik-creds.txt`.

## Known issues

- **`mikro-cottage` and `mikro-masterbed` have broken NTP** — their backup filenames use epoch-era dates (e.g. `19710402`) instead of today's date because their clocks are not synced. The backup data itself is valid.

- **mikro-router has a scheduled job that blocks all internet traffic from 1:30AM–4:30AM** — this causes the dnsmasq container on rpi-dns01 to deadlock. When 1.1.1.1 becomes unreachable, forwarded queries pile up and fill dnsmasq's 150-query concurrent limit, leaving the container hung but still "running" (so `restart: always` never fires). Two mitigations are in place:
  1. A Docker healthcheck on the dnsmasq container (`nslookup home.steenburg.net 127.0.0.1`) detects the hang and triggers an auto-restart within ~90 seconds.
  2. A firewall exception on mikro-router should allow DNS traffic (UDP port 53) from rpi-dns01 (192.168.1.5) to pass through even during the block window, preventing the deadlock entirely.

## Checking backup status

```bash
# Recent vsftpd transfers
tail -40 /var/log/vsftpd.log

# List today's backups
ls -lh /home/ftp-files/ | grep $(date +%Y%m%d)

# Check which devices backed up in the last 24h
grep "OK UPLOAD" /var/log/vsftpd.log | grep $(date +"%b %d" | sed 's/ 0/ /') | awk '{print $9, $10}'

# Verify vsftpd is running
systemctl status vsftpd
```

## Scheduling

The backup schedule is configured entirely on each Mikrotik device (System > Scheduler in WinBox, or `/system scheduler` in the CLI). There is no cron job on this machine for backups.
