# SFTP Service

Docker-based SFTP server using [atmoz/sftp](https://github.com/atmoz/sftp), used to receive automated config backups from Mikrotik devices.

Files land in `/home/ftp-files/` on the host, world-readable (644).

## Prerequisites

### 1. Create the ftp-files user and directory

```bash
sudo useradd -m -u 1001 -s /bin/bash ftp-files
sudo mkdir -p /home/ftp-files
sudo chown root:root /home/ftp-files   # chroot requires root ownership
```

The `upload/` subdirectory inside the container is bind-mounted from `/home/ftp-files` on the host. atmoz/sftp creates it automatically on first start.

### 2. Generate a password hash

The `command:` field in docker-compose.yml takes a pre-hashed SHA-512 password (the `:e` flag tells atmoz/sftp the password is already hashed). To generate one:

```bash
python3 -c "import crypt; print(crypt.crypt('YOUR_PASSWORD', crypt.mksalt(crypt.METHOD_SHA512)))"
```

Update the `command:` line in `docker-compose.yml`, escaping every `$` with `$$`:

```
command: "ftp-files:$$6$$salt$$hash...:e:1001:1001:upload"
```

**Why SHA-512?** The container's default `chpasswd` produces a yescrypt (`$y$`) hash which the older PAM version in the container cannot verify. Pre-hashing with SHA-512 and using `UsePAM no` in sshd_config sidesteps this.

### 3. Install Docker and Docker Compose

```bash
sudo apt install docker.io docker-compose
sudo systemctl enable --now docker
```

## Starting the service

```bash
sudo docker-compose up -d
```

## Updating Mikrotik backup scripts

Replace the FTP fetch calls with SFTP. In each device's `Backup_Daily` script, change:

```
/tool fetch address=$ftpserver src-path="$localfilename.rsc" \
  user=$username mode=ftp password=$password \
  dst-path="$remotefilename.rsc" upload=yes
```

to:

```
/tool fetch address=$ftpserver port=2222 src-path="$localfilename.rsc" \
  user=$username mode=sftp password=$password \
  dst-path=("upload/" . $remotefilename . ".rsc") upload=yes
```

Key differences:
- `mode=ftp` → `mode=sftp`
- Add `port=2222`
- `dst-path` uses string concatenation with `"upload/"` prefix

See `mikrotik-backup-script.rsc` for the full updated script to paste into **System → Scripts → Backup_Daily** in Winbox, or via terminal:

```
/system script edit Backup_Daily source
```

## Disabling vsftpd

Once SFTP backups are confirmed working across all devices:

```bash
sudo systemctl stop vsftpd
sudo systemctl disable vsftpd
```
