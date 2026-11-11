# Continuous Archiving & pgBackRest
**Series:** PostgreSQL Mastery | **Phase:** Phase 18: Backup, Recovery & Disaster Recovery | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In the previous class, we set up PITR manually — writing archive_command, managing WAL files, configuring recovery by hand. That works, but in production you want automation. pgBackRest is the most popular enterprise backup tool for PostgreSQL. It handles everything: efficient backups, WAL archiving, retention policies, verification, and fast restore — all in one tool. Let us learn it from scratch. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Manual archive_command vs Enterprise Tools
Before pgBackRest, let us understand continuous archiving more deeply. Manual WAL archiving using archive_command has limitations. The cp command does not handle network failures. There is no built-in compression. There is no retention management — you must clean old files yourself. There is no verification. Enterprise tools like pgBackRest solve all of these problems.

| Manual (cp/scp) | pgBackRest |
| :--- | :--- |
| No retry on failure | Automatic retry with backoff |
| No compression | Built-in compression (lz4, zstd, gz) |
| No encryption | Encryption at rest (AES-256) |
| No retention management | Automatic retention policies |
| No backup verification | Backup verification (checksums) |
| No incremental/differential | Full, differential, incremental backups |

### pgBackRest Backup Types
pgBackRest supports three backup types. A full backup copies everything — like pg_basebackup. A differential backup copies only files changed since the last full backup. An incremental backup copies only files changed since the last backup of any type. Differential and incremental save massive amounts of disk space and time on large databases.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Full Backup** | Complete copy of entire database — largest, slowest, most self-contained |
| **Differential (diff)** | Changes since last FULL — needs that full + this diff to restore |
| **Incremental (incr)** | Changes since last backup (any type) — smallest, fastest, needs full chain |

**Notes:**
- 500GB DB: Full=500GB, Diff after 1 day=5GB, Incr after 1 hour=500MB
- Typical schedule: Full weekly + Diff daily + Incr hourly

### Support & Materials
If you are enjoying this course, please consider supporting it. You can donate through PayPal or UPI — the links are in the description. Every contribution helps keep this course free and growing. You can also download the class materials from GitHub — the link is in the description too.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### pgBackRest Quick Reference
Here is the pgBackRest quick reference — the commands you will use most often.

| Command | What It Does |
| :--- | :--- |
| stanza-create | Initialize repository (one-time) |
| check | Verify PG connection + archiving works |
| backup --type=full | Full backup of entire cluster |
| backup --type=diff | Differential (since last full) |
| backup --type=incr | Incremental (since last backup) |
| restore --delta | Restore latest, only replace changed files |
| restore --type=time --target=... | PITR to specific timestamp |
| restore --db-include=dbname | Restore only one database |
| info | List all backups with sizes and dates |
| verify | Check backup integrity + WAL chain |
| expire | Clean up old backups (auto after backup) |

### Practice Exercises
Time to practice. First, install pgBackRest and create the configuration file. Second, create the stanza and run the check command. Third, take a full backup and view it with info. Fourth, make changes, then take a differential backup and compare sizes. Fifth, try a restore with --delta to a test server.

- 1 -- apt install pgbackrest, write /etc/pgbackrest/pgbackrest.conf
- 2 -- pgbackrest --stanza=myapp stanza-create; pgbackrest check
- 3 -- pgbackrest --stanza=myapp --type=full backup; pgbackrest info
- 4 -- INSERT data, --type=diff backup, compare sizes with info
- 5 -- Stop PG, pgbackrest --stanza=myapp --delta restore, start PG, verify


---

## 3. Hands-On Commands & psql Output

### Installing pgBackRest
**Explanation:** Let us install pgBackRest. On Ubuntu and Debian, it is in the official PostgreSQL repository. On RHEL and CentOS, it is in the PGDG repository. After installation, we create its configuration file.

```sql
$ # Ubuntu/Debian:
$ sudo apt install pgbackrest
Reading package lists... Done
Setting up pgbackrest (2.48-1) ...
$ # RHEL/CentOS:
$ sudo dnf install pgbackrest
$ # Verify installation:
$ pgbackrest version
pgBackRest 2.48
$ # Create config directory:
$ sudo mkdir -p /etc/pgbackrest
$ sudo mkdir -p /var/lib/pgbackrest
$ sudo chown postgres:postgres /var/lib/pgbackrest
```

### Configure PostgreSQL for pgBackRest
**Explanation:** Now configure PostgreSQL to use pgBackRest for WAL archiving instead of the manual cp command. pgBackRest has its own archive-push and archive-get commands that handle compression, checksums, and error handling automatically.

```sql
postgres=# -- Set pgBackRest as the archive handler:
postgres=# ALTER SYSTEM SET archive_mode = 'on';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET archive_command =
  'pgbackrest --stanza=myapp archive-push %p';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET wal_level = 'replica';
ALTER SYSTEM
-- -- Restart required for archive_mode and wal_level:
$ sudo systemctl restart postgresql
-- -- pgBackRest archive-push:
-- --   Compresses WAL with lz4 (from config)
-- --   Verifies checksum before storing
-- --   Handles retries automatically
-- --   Stores in repo1-path/archive/
```

### Create and Verify Stanza
**Explanation:** Before taking the first backup, you must create the stanza. This initializes the backup repository structure and verifies pgBackRest can connect to PostgreSQL and the archive location.

```sql
$ # Create the stanza (one-time setup):
$ sudo -u postgres pgbackrest --stanza=myapp stanza-create
P00   INFO: stanza-create command end: completed successfully
$ # Verify stanza (checks PG connection + archive):
$ sudo -u postgres pgbackrest --stanza=myapp check
P00   INFO: check repo1 configuration (primary)
P00   INFO: check repo1 archive for WAL (primary)
P00   INFO: WAL segment 00000001000000000000000A successfully archived
P00   INFO: check command end: completed successfully
-- -- stanza-create: run once, creates repo structure
-- -- check: run anytime to verify everything works
```

### Taking a Full Backup
**Explanation:** Now let us take our first full backup. pgBackRest handles everything automatically — it starts a checkpoint, streams the data, compresses it, calculates checksums, and stores it in the repository. The info command shows all your backups with their sizes and timestamps.

```sql
$ # Full backup:
$ sudo -u postgres pgbackrest --stanza=myapp --type=full backup
P00   INFO: backup command begin 2.48: ...
P00   INFO: execute non-exclusive backup start
P00   INFO: backup start archive = 00000001000000000000000B
P00   INFO: full backup size = 87.2MB, file total = 1234
P00   INFO: backup command end: completed successfully
$ # View backup info:
$ sudo -u postgres pgbackrest --stanza=myapp info
stanza: myapp
    status: ok
    cipher: aes-256-cbc

    db (current)
        full backup: 20261104-100000F
            timestamp start/stop: 2026-11-04 10:00 / 2026-11-04 10:02
            database size: 87.2MB, database backup size: 87.2MB
            repo1: backup size: 12.4MB
```

### Differential and Incremental Backups
**Explanation:** Now a differential backup — it only copies files changed since the last full. Notice how much smaller and faster it is. On a large database, this difference is dramatic — a 500GB full backup might produce only a 5GB differential.

```sql
$ # First, make some changes to the database...
$ psql -U postgres -d trigger_lab -c \
  "INSERT INTO big_orders (customer_id, product, amount, order_date, notes)
   SELECT (random()*1000)::int, 'NewProduct', 99.99, CURRENT_DATE, 'new'
   FROM generate_series(1,50000);"
INSERT 0 50000
$ # Differential backup (changes since last full):
$ sudo -u postgres pgbackrest --stanza=myapp --type=diff backup
P00   INFO: backup command begin ...
P00   INFO: diff backup size = 6.8MB, file total = 1234
P00   INFO: backup command end: completed successfully
$ # Incremental (changes since last backup of any type):
$ sudo -u postgres pgbackrest --stanza=myapp --type=incr backup
P00   INFO: incr backup size = 840KB, file total = 1234
-- -- Full: 87MB, Diff: 6.8MB, Incr: 840KB — massive savings!
```

### Restoring with pgBackRest
**Explanation:** Restoring with pgBackRest is simpler than manual PITR. One command handles everything — it stops PostgreSQL, clears the data directory, restores from the backup, configures recovery, and starts PostgreSQL. For PITR, add the --target option with a timestamp.

```sql
$ # Full restore (latest backup):
$ sudo systemctl stop postgresql
$ sudo -u postgres pgbackrest --stanza=myapp --delta restore
P00   INFO: restore command begin ...
P00   INFO: restore backup set 20261104-100000F_20261104-120000D
P00   INFO: write updated /var/lib/postgresql/16/main/postgresql.auto.conf
P00   INFO: restore command end: completed successfully
$ sudo systemctl start postgresql
-- -- --delta: only restores files that differ (faster restart)
-- 
$ # PITR restore to specific time:
$ sudo -u postgres pgbackrest --stanza=myapp --delta \
  --type=time --target='2026-11-04 10:30:00+05:30' \
  --target-action=promote restore
-- -- Automatically configures restore_command and recovery_target_time
```

### Selective Database Restore
**Explanation:** pgBackRest can also restore specific databases or exclude specific databases from a cluster backup. This is extremely useful when you have a multi-database server and only need to recover one database.

```sql
$ # Restore only the 'trigger_lab' database:
$ sudo -u postgres pgbackrest --stanza=myapp --delta \
  --db-include=trigger_lab restore
-- -- Other databases become empty shells (catalog only)
-- -- Can later restore them individually
-- 
$ # Exclude a large database you don't need:
$ sudo -u postgres pgbackrest --stanza=myapp --delta \
  --db-exclude=huge_analytics restore
-- -- Restores everything except huge_analytics
-- -- Saves time and disk space
```

### Verifying Backups
**Explanation:** Backup verification is critical. pgBackRest can verify that every file in the backup is intact by checking checksums. It also verifies that the archived WAL chain is complete — no gaps between the base backup and now.

```sql
$ # Verify all backups and WAL archive:
$ sudo -u postgres pgbackrest --stanza=myapp verify
P00   INFO: verify command begin ...
P00   INFO: verify backup 20261104-100000F
P00   INFO: verify backup 20261104-100000F_20261104-120000D
P00   INFO: verify backup 20261104-100000F_20261104-130000I
P00   INFO: verify archive 000000010000000000000001-00000001000000000000000F
P00   INFO: verify command end: completed successfully
-- -- Checks: file checksums match, WAL chain is complete
-- -- Run weekly to catch silent corruption early
```

### Retention and Expiration
**Explanation:** pgBackRest handles retention automatically. In our config, we set repo1-retention-full to 2 and repo1-retention-diff to 7. This means pgBackRest keeps the 2 most recent full backups and 7 most recent differential backups. Old backups and their WAL files are automatically cleaned up. This is called the expire command, and it runs automatically after each backup.

```sql
$ # View all backups:
$ sudo -u postgres pgbackrest --stanza=myapp info
    db (current)
        full backup: 20261028-020000F
            database size: 87.2MB, repo size: 12.4MB
        full backup: 20261104-020000F
            database size: 92.1MB, repo size: 13.1MB
            diff backup: 20261104-120000D
                database size: 92.1MB, repo size: 1.8MB
            incr backup: 20261104-130000I
                database size: 92.1MB, repo size: 420KB
-- -- repo1-retention-full=2: keeps 2 full backups
-- -- Older fulls + their diffs/incrs auto-expired
-- -- WAL files no longer needed are cleaned up too
$ # Manual expire (usually automatic):
$ sudo -u postgres pgbackrest --stanza=myapp expire
```

### Production Backup Schedule (cron)
**Explanation:** For a production backup schedule, here is the typical pattern. Weekly full backup on Sunday night. Daily differential backups. And optionally, hourly incremental backups for databases with strict RPO requirements. All managed by cron.

```sql
$ # Add to postgres user's crontab:
$ sudo -u postgres crontab -e

# Weekly full backup - Sunday 2:00 AM
0 2 * * 0 pgbackrest --stanza=myapp --type=full backup

# Daily differential - Mon-Sat 2:00 AM
0 2 * * 1-6 pgbackrest --stanza=myapp --type=diff backup

# Hourly incremental (optional, for strict RPO)
0 * * * * pgbackrest --stanza=myapp --type=incr backup

# Weekly verify - Sunday 6:00 AM
0 6 * * 0 pgbackrest --stanza=myapp verify
-- -- Retention auto-expires old backups after each run
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf` — /etc/pgbackrest/pgbackrest.conf
The pgBackRest configuration file defines stanzas. A stanza is a named configuration for one PostgreSQL cluster. It specifies where the data directory is, where to store backups, and how to archive WAL. Let us write a complete configuration file.

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `repo1-path` | `/var/lib/pgbackrest` | `[SETTING]` |  |
| `repo1-retention-full` | `2` | `[SETTING]` |  |
| `repo1-retention-diff` | `7` | `[SETTING]` |  |
| `repo1-cipher-type` | `aes-256-cbc` | `[SETTING]` |  |
| `repo1-cipher-pass` | `your-encryption-passphrase` | `[SETTING]` |  |
| `compress-type` | `lz4` | `[SETTING]` |  |
| `compress-level` | `6` | `[SETTING]` |  |
| `process-max` | `4` | `[SETTING]` |  |
| `log-level-console` | `info` | `[SETTING]` |  |
| `log-level-file` | `detail` | `[SETTING]` |  |
| `pg1-path` | `/var/lib/postgresql/16/main` | `[SETTING]` |  |


### File: `postgresql.conf` — pgBackRest with S3 Remote Storage
pgBackRest can also store backups on remote storage — Amazon S3, Google Cloud Storage, Azure Blob, or a remote server via SSH. This is essential for disaster recovery — if your server dies, your backups should be on a different machine or in the cloud.

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `repo1-type` | `s3` | `[SETTING]` |  |
| `repo1-path` | `/pgbackrest` | `[SETTING]` |  |
| `repo1-s3-bucket` | `mycompany-pg-backups` | `[SETTING]` |  |
| `repo1-s3-region` | `ap-south-1` | `[SETTING]` |  |
| `repo1-s3-endpoint` | `s3.ap-south-1.amazonaws.com` | `[SETTING]` |  |
| `repo1-s3-key` | `AKIAIOSFODNN7EXAMPLE` | `[SETTING]` |  |
| `repo1-s3-key-secret` | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` | `[SETTING]` |  |
| `repo1-retention-full` | `4` | `[SETTING]` |  |
| `repo1-cipher-type` | `aes-256-cbc` | `[SETTING]` |  |
| `repo1-cipher-pass` | `your-encryption-passphrase` | `[SETTING]` |  |
| `compress-type` | `zstd` | `[SETTING]` |  |
| `pg1-path` | `/var/lib/postgresql/16/main` | `[SETTING]` |  |



---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review. pgBackRest is the enterprise standard for PostgreSQL backups. It replaces manual archive_command with automatic WAL management. Three backup types: full, differential, and incremental. Built-in compression, encryption, and checksum verification. Retention policies automatically clean up old backups. Remote storage with S3, GCS, and Azure. One-command restore with --delta for speed. PITR with --type=time and --target. Weekly verify checks backup integrity. Schedule with cron: weekly full, daily diff, optional hourly incr.

- **pgBackRest: enterprise backup — replaces manual archive_command**
- **Stanza: named config for one PG cluster**
- **archive_command = 'pgbackrest --stanza=X archive-push %p'**
- **3 backup types: full (all), diff (since full), incr (since last)**
- **Built-in: compression (lz4/zstd), encryption (AES-256), checksums**
- **Retention: repo1-retention-full=2 auto-expires old backups**
- **Restore: --delta (fast, only changed files), --db-include (selective)**
- **PITR: --type=time --target='timestamp' --target-action=promote**
- **Remote storage: S3, GCS, Azure, SSH**
- **Schedule: weekly full + daily diff + weekly verify**


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
