# Barman & WAL-G
**Series:** PostgreSQL Mastery | **Phase:** Phase 18: Backup, Recovery & Disaster Recovery | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we cover two more enterprise backup tools — Barman and WAL-G. Barman is a remote backup management tool created by EDB — it runs on a separate server and manages backups for multiple PostgreSQL instances. WAL-G is a lightweight, cloud-native tool that excels at streaming backups directly to object storage like S3, GCS, or Azure. Each tool has its strengths. Let us learn both. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### pgBackRest vs Barman vs WAL-G
Let us compare all three enterprise backup tools at a glance. pgBackRest is the most feature-rich and runs locally or remotely. Barman is designed for centralized remote backup management. WAL-G is the simplest — focused on cloud storage with minimal configuration. Your choice depends on your infrastructure.

| Term | Meaning / Explanation |
| :--- | :--- |
| **BackRest** | the most feature-rich and runs locally or remotely |
| **Barman** | designed for centralized remote backup management |
| **WAL-G** | the simplest — focused on cloud storage with minimal configuration |

### Barman — Centralized Remote Backup
Let us start with Barman. Barman stands for Backup and Recovery Manager. Its key design difference is that it runs on a SEPARATE server — the backup server. It connects to your PostgreSQL servers over SSH or streaming replication and manages all backups centrally. This separation is good for security — your backup server can be locked down and on a different network.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Architecture** | Runs on a dedicated backup server, connects to PG servers remotely |
| **Connection Methods** | SSH (rsync-based) or streaming (pg_basebackup protocol) |
| **Created by** | EDB (EnterpriseDB) — open source, Python-based |
| **Multi-server** | One Barman server manages backups for many PG instances |
| **Retention** | Time-based (keep 30 days) or count-based (keep 4 full) |

**Notes:**
- Streaming mode recommended — faster, no SSH setup needed
- Requires barman-cli package on the PostgreSQL server for WAL archiving

### Barman Quick Reference
Here is the Barman quick reference for the commands you will use most often.

| Command | What It Does |
| :--- | :--- |
| barman check myapp | Verify server connection and archiving |
| barman switch-wal myapp | Force WAL switch to test archiving |
| barman backup myapp --wait | Take a full backup, wait for completion |
| barman list-backup myapp | List all backups for a server |
| barman show-backup myapp ID | Detailed info on one backup |
| barman recover myapp ID /path | Restore backup to path |
| barman recover ... --target-time | PITR to specific timestamp |
| barman delete myapp ID | Delete a specific backup |
| barman cron | Run maintenance tasks (add to cron every minute) |

### Support & Materials
If you are enjoying this course, please consider supporting it. You can donate through PayPal or UPI — the links are in the description. Every contribution helps keep this course free and growing. You can also download the class materials from GitHub — the link is in the description too. Now let us move to WAL-G.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### WAL-G — Cloud-Native Backup Tool
WAL-G is a cloud-native backup tool written in Go. It was created by Citus Data and is now maintained by the WAL-G community. Its biggest advantage is simplicity — configuration is through environment variables, not config files. It is fast, supports delta backups, and works beautifully with S3, GCS, Azure, and local filesystem. It is the go-to tool for Kubernetes and cloud deployments.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Architecture** | Runs locally on the PG server — no separate backup server needed |
| **Configuration** | Environment variables — perfect for Docker and Kubernetes |
| **Backup Types** | Full and delta (file-level incremental using page LSN) |
| **Compression** | lz4 (default), zstd, brotli, lzma — very fast with lz4 |
| **Cloud Storage** | S3, GCS, Azure Blob, Swift, local filesystem |

**Notes:**
- Single binary — no dependencies to install
- Popular with: Kubernetes, Docker, cloud-managed infrastructure

### Which Backup Tool Should You Choose?
Here is the decision framework for choosing between pgBackRest, Barman, and WAL-G.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is the decision framework for choosing between pgBackRest, Barman, and WAL-G |

### WAL-G Quick Reference
Here is the WAL-G quick reference for the commands you will use most often.

| Command | What It Does |
| :--- | :--- |
| wal-g backup-push $PGDATA | Full backup to storage |
| wal-g backup-push --delta $PGDATA | Delta backup (changed pages only) |
| wal-g backup-list | List all backups |
| wal-g backup-fetch $PGDATA LATEST | Restore most recent backup |
| wal-g backup-fetch $PGDATA name | Restore specific backup by name |
| wal-g wal-push %p | Archive one WAL file (archive_command) |
| wal-g wal-fetch %f %p | Fetch WAL for recovery (restore_command) |
| wal-g delete retain FULL 2 | Dry-run: show what would be deleted |
| wal-g delete retain FULL 2 --confirm | Actually delete old backups |

### Practice Exercises
Time to practice. First, install WAL-G and configure it for local filesystem storage. Second, configure PostgreSQL to use wal-g wal-push as the archive_command. Third, take a full backup and verify with backup-list. Fourth, make changes and take a delta backup. Fifth, practice a restore with backup-fetch and verify the data.

- 1 -- Download binary, set WALG_FILE_PREFIX=/backups/wal-g, PGDATA
- 2 -- archive_command = 'wal-g wal-push %p', restart PG
- 3 -- wal-g backup-push $PGDATA; wal-g backup-list
- 4 -- INSERT data; wal-g backup-push --delta $PGDATA
- 5 -- Stop PG, wal-g backup-fetch $PGDATA LATEST, configure recovery, start


---

## 3. Hands-On Commands & psql Output

### Installing Barman
**Explanation:** Let us install Barman on the backup server and barman-cli on the PostgreSQL server. The barman-cli package provides the barman-wal-archive command that PostgreSQL uses as its archive_command.

```sql
# --- On the BACKUP SERVER ---
backup$ sudo apt install barman
Setting up barman (3.10.0-1) ...
backup$ barman --version
3.10.0 - EDB (https://www.enterprisedb.com/)
-- 
# --- On the POSTGRESQL SERVER ---
pgserver$ sudo apt install barman-cli
Setting up barman-cli (3.10.0-1) ...
pgserver$ which barman-wal-archive
/usr/bin/barman-wal-archive
-- -- barman-cli provides: barman-wal-archive, barman-wal-restore
-- -- These run on the PG server, talk to the Barman server
```

### PostgreSQL Setup for Barman
**Explanation:** On the PostgreSQL server, you need two users for Barman — one for regular connections and one for streaming replication. You also configure archive_command to use barman-wal-archive to send WAL files to the Barman server.

```sql
postgres=# -- Create Barman users on PG server:
postgres=# CREATE ROLE barman WITH LOGIN SUPERUSER PASSWORD 'barman_pass';
CREATE ROLE
postgres=# CREATE ROLE streaming_barman WITH LOGIN REPLICATION PASSWORD 'stream_pass';
CREATE ROLE
postgres=# -- Configure WAL archiving to Barman:
postgres=# ALTER SYSTEM SET archive_mode = 'on';
postgres=# ALTER SYSTEM SET archive_command =
  'barman-wal-archive backup-server myapp %p';
ALTER SYSTEM
-- -- backup-server = hostname of your Barman server
-- -- myapp = server name in Barman config
-- -- %p = WAL file path
-- -- Also add pg_hba.conf entries for barman and streaming_barman
-- -- Restart PostgreSQL after changes
```

### Barman: Check, Backup, List
**Explanation:** With Barman configured, let us verify the setup, take a backup, and list our backups. The barman check command verifies everything is working. The barman switch-wal forces an archive to confirm WAL archiving works.

```sql
backup$ # Verify setup:
backup$ barman check myapp
Server myapp:
    PostgreSQL: OK
    superuser or standard user: OK
    streaming connection: OK
    WAL archiving: OK
    replication slot: OK
backup$ # Take a full backup:
backup$ barman backup myapp --wait
Starting backup using postgres method for server myapp
Backup completed (start time: 2026-11-04 14:00, elapsed: 2m15s)
Backup size: 87.2 MiB. Compressed: 24.1 MiB
backup$ # List backups:
backup$ barman list-backup myapp
myapp 20261104T140000 - Size: 87.2 MiB - Status: DONE
```

### Barman Restore and PITR
**Explanation:** Restoring with Barman sends the backup back to the PostgreSQL server. The barman recover command can restore to the latest state or to a specific point in time with --target-time. It handles everything — extracting files, configuring recovery, setting permissions.

```sql
backup$ # Restore latest backup to PG server:
backup$ barman recover myapp 20261104T140000 \
  /var/lib/postgresql/16/main \
  --remote-ssh-command 'ssh postgres@10.0.1.1'
Starting remote restore for server myapp
Restore completed successfully
-- 
backup$ # PITR to specific time:
backup$ barman recover myapp latest \
  /var/lib/postgresql/16/main \
  --remote-ssh-command 'ssh postgres@10.0.1.1' \
  --target-time '2026-11-04 10:30:00+05:30'
-- -- 'latest' = most recent backup as base for PITR
-- -- Barman configures restore_command, recovery_target_time automatically
```

### Installing WAL-G
**Explanation:** Installing WAL-G is simple — it is a single binary. Download it from GitHub releases, make it executable, and put it in your path. Then set environment variables for your storage backend.

```sql
$ # Download the latest release:
$ wget https://github.com/wal-g/wal-g/releases/download/v3.0.0/\
  wal-g-pg-ubuntu-20.04-amd64.tar.gz
$ tar xzf wal-g-pg-ubuntu-20.04-amd64.tar.gz
$ sudo mv wal-g-pg-ubuntu-20.04-amd64 /usr/local/bin/wal-g
$ sudo chmod +x /usr/local/bin/wal-g
$ wal-g --version
wal-g v3.0.0
-- -- Single binary, no dependencies
-- -- For Docker: ADD wal-g /usr/local/bin/ in Dockerfile
```

### WAL-G Configuration — Environment Variables
**Explanation:** WAL-G is configured entirely through environment variables. For S3 storage, you set the bucket, region, and access keys. For local filesystem storage, you set a file prefix. Let us see both configurations.

```sql
$ # Create WAL-G env file for the postgres user:
$ sudo tee /etc/wal-g/env.conf << 'EOF'
# S3 storage:
WALG_S3_PREFIX=s3://mycompany-pg-backups/myapp
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_REGION=ap-south-1
WALG_COMPRESSION_METHOD=lz4
WALG_DELTA_MAX_STEPS=7
PGDATA=/var/lib/postgresql/16/main
EOF
-- 
-- # For local filesystem instead of S3:
-- # WALG_FILE_PREFIX=/backups/wal-g
-- 
-- # For Google Cloud Storage:
-- # WALG_GS_PREFIX=gs://bucket-name/path
-- # GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
```

### WAL-G: Configure PG and Take Backup
**Explanation:** Now configure PostgreSQL to use WAL-G for WAL archiving and take our first backup. WAL-G uses wal-push for archiving and wal-fetch for restore. The backup-push command takes a base backup.

```sql
postgres=# -- Set WAL-G as the archive handler:
postgres=# ALTER SYSTEM SET archive_command =
  'envdir /etc/wal-g/env.d wal-g wal-push %p';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET archive_mode = 'on';
postgres=# ALTER SYSTEM SET wal_level = 'replica';
-- -- Restart required, then:
$ # Take a full backup:
$ sudo -u postgres envdir /etc/wal-g/env.d wal-g backup-push $PGDATA
INFO: 2026/11/04 14:00:00 Calling pg_start_backup()
INFO: 2026/11/04 14:00:02 Starting part 1 ...
INFO: 2026/11/04 14:00:45 Finishing backup ...
INFO: 2026/11/04 14:00:45 Wrote backup with name base_00000001000000000000000F
$ # List backups:
$ sudo -u postgres envdir /etc/wal-g/env.d wal-g backup-list
name                          modified             wal_segment_backup_start
base_00000001000000000000000F 2026-11-04T14:00:45Z 00000001000000000000000F
```

### WAL-G Delta Backups
**Explanation:** WAL-G supports delta backups. A delta backup stores only the pages that changed since the last backup — at the page level, not the file level. This is more granular than pgBackRest's file-level differential. The WALG_DELTA_MAX_STEPS setting controls how many deltas can chain before a full backup is forced.

```sql
$ # Delta backup (changed pages since last backup):
$ sudo -u postgres envdir /etc/wal-g/env.d \
  wal-g backup-push --delta $PGDATA
INFO: Delta backup from base_00000001000000000000000F
INFO: Wrote backup with name base_000000010000000000000012_D_00000001000000000000000F
$ sudo -u postgres envdir /etc/wal-g/env.d wal-g backup-list
name                                                          modified
base_00000001000000000000000F                                 2026-11-04T14:00Z
base_000000010000000000000012_D_00000001000000000000000F       2026-11-04T16:00Z
-- -- _D_ in the name means delta backup
-- -- WALG_DELTA_MAX_STEPS=7: after 7 deltas, force full
-- -- Page-level delta: smaller than file-level diff
```

### WAL-G Restore and PITR
**Explanation:** Restoring with WAL-G is straightforward. Stop PostgreSQL, clear the data directory, run backup-fetch to get the latest backup, configure the restore_command to use wal-fetch, create recovery.signal, and start PostgreSQL. For PITR, add recovery_target_time.

```sql
$ sudo systemctl stop postgresql
$ # Clear data directory (move aside first for safety):
$ sudo -u postgres rm -rf /var/lib/postgresql/16/main/*
$ # Fetch latest backup:
$ sudo -u postgres envdir /etc/wal-g/env.d \
  wal-g backup-fetch $PGDATA LATEST
INFO: Extracting backup base_000000010000000000000012_D_...
INFO: Finished extraction
$ # Configure recovery for PITR:
$ cat >> $PGDATA/postgresql.auto.conf << 'EOF'
restore_command = 'envdir /etc/wal-g/env.d wal-g wal-fetch %f %p'
recovery_target_time = '2026-11-04 10:30:00+05:30'
recovery_target_action = 'promote'
EOF
$ touch $PGDATA/recovery.signal
$ sudo systemctl start postgresql
```

### WAL-G Retention and Cleanup
**Explanation:** WAL-G handles retention with the delete command. You can delete backups older than a certain count or retain a specific number of full backups. Always use --confirm to actually delete — without it, WAL-G shows what WOULD be deleted.

```sql
$ # Show what would be deleted (dry run):
$ sudo -u postgres envdir /etc/wal-g/env.d \
  wal-g delete retain FULL 2
INFO: Would delete backup base_00000001000000000000000A
INFO: Would delete 24 WAL files
-- 
$ # Actually delete (with --confirm):
$ sudo -u postgres envdir /etc/wal-g/env.d \
  wal-g delete retain FULL 2 --confirm
INFO: Deleted backup base_00000001000000000000000A
INFO: Deleted 24 WAL files
-- -- retain FULL 2: keep 2 most recent full backups + their deltas
-- -- delete before FIND_FULL backup_name: delete before specific backup
-- -- Always dry-run first (no --confirm) to verify!
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf` — /etc/barman.d/myapp.conf (Streaming Mode)
Now configure Barman. The global configuration is at /etc/barman.conf. Then each PostgreSQL server gets its own configuration file in /etc/barman.d/. We will use streaming mode — it uses the replication protocol like pg_basebackup.

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `description` | `"Production PostgreSQL 16"` | `[SETTING]` |  |
| `conninfo` | `host=10.0.1.1 user=barman dbname=postgres` | `[SETTING]` |  |
| `streaming_conninfo` | `host=10.0.1.1 user=streaming_barman` | `[SETTING]` |  |
| `backup_method` | `postgres` | `[SETTING]` |  |
| `streaming_archiver` | `on` | `[SETTING]` |  |
| `slot_name` | `barman` | `[SETTING]` |  |
| `create_slot` | `auto` | `[SETTING]` |  |
| `backup_directory` | `/var/lib/barman/myapp` | `[SETTING]` |  |
| `retention_policy` | `RECOVERY WINDOW OF 30 DAYS` | `[SETTING]` |  |
| `parallel_jobs` | `4` | `[SETTING]` |  |
| `compression` | `gzip` | `[SETTING]` |  |



---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review. Barman is a centralized remote backup tool by EDB — runs on a separate server, manages multiple PG instances, uses streaming or SSH. WAL-G is cloud-native — single binary, configured with environment variables, perfect for Kubernetes and Docker. Both support PITR through WAL archiving. Barman uses barman-wal-archive as the archive_command. WAL-G uses wal-g wal-push. For restoring, Barman uses barman recover, WAL-G uses backup-fetch plus wal-fetch. Choose based on your infrastructure: pgBackRest for most cases, Barman for centralized multi-server, WAL-G for cloud-native.

- **Barman: centralized remote backup by EDB, manages multiple PG servers**
- **Barman: streaming or SSH mode, retention by time or count**
- **barman check → barman backup → barman recover (with PITR)**
- **WAL-G: cloud-native, single Go binary, env var configuration**
- **WAL-G: full + delta (page-level) backups to S3/GCS/Azure/local**
- **wal-g backup-push → wal-g backup-fetch LATEST → configure recovery**
- **Both handle WAL archiving as archive_command replacement**
- **Choose: pgBackRest (most cases), Barman (multi-server), WAL-G (cloud/K8s)**


---

## 8. Downloadable SQL Script Instructions

Every command demonstrated in this video is compiled into the companion `materials.sql` file.

To execute it directly in PostgreSQL:

```bash
# From your command line:
psql -U postgres -d postgres -f materials.sql

# Or from inside psql prompt:
postgres=# \i materials.sql
```
