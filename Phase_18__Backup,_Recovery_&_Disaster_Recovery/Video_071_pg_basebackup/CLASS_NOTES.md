# pg_basebackup
**Series:** PostgreSQL Mastery | **Phase:** Phase 18: Backup, Recovery & Disaster Recovery | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we learn pg_basebackup — the built-in tool for physical backups. Unlike pg_dump which exports SQL statements, pg_basebackup copies the raw data files — the actual bytes on disk. This is faster for large databases and, most importantly, it is the foundation for Point-in-Time Recovery. Without a physical base backup, PITR is impossible. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### pg_dump vs pg_basebackup
pg_basebackup works differently from pg_dump. It connects using the replication protocol, not a regular SQL connection. It copies the entire data directory — every file, every table, every index — as binary files. This means you get an exact copy of the database that can be started as-is. But it also means you cannot selectively restore a single table. It is all or nothing.

| pg_dump (Logical) | pg_basebackup (Physical) |
| :--- | :--- |
| Exports SQL statements | Copies raw data files |
| Regular SQL connection | Replication protocol connection |
| Selective restore (tables/schemas) | All-or-nothing restore |
| Cross-version compatible | Same major version only |
| Slow for large databases | Fast — streaming copy |
| No PITR support | PITR with WAL archiving |

### pg_basebackup Essential Options
Let us look at all the important pg_basebackup options. The -R flag is especially useful — it creates standby.signal and adds connection settings to postgresql.auto.conf, so you can start the backup as a streaming replica immediately.

| Term | Meaning / Explanation |
| :--- | :--- |
| **-D directory** | Destination directory or tar output location (required) |
| **-Fp (plain) / -Ft (tar)** | Output format: plain directory (default) or tar archives |
| **-z / --compress=METHOD** | Compress with gzip (-z) or lz4/zstd (PG 15+) |
| **-P (--progress)** | Show progress: bytes transferred and percentage |
| **--checkpoint=fast** | Force immediate checkpoint — start backup sooner (brief I/O spike) |
| **-R (--write-recovery-conf)** | Create standby.signal + write primary_conninfo to auto.conf |
| **-X stream (default)** | Stream WAL during backup — ensures backup is self-contained |
| **-X fetch** | Fetch WAL at end — needs wal_keep_size set high enough |
| **--max-rate=100M** | Throttle backup to 100MB/s — reduce I/O impact on production |

**Notes:**
- -X stream (default in PG 10+) uses a second connection for WAL streaming

### Beginner Trap: Missing WAL Files
Here is a beginner trap: forgetting the -X option. By default, pg_basebackup uses -X stream, which streams WAL during the backup. But if you use -X none or -X fetch with insufficient wal_keep_size, your backup may be missing WAL files needed for consistency. When you try to start PostgreSQL from that backup, it will fail with a missing WAL error. Always verify your backup includes pg_wal files.

| The Problem | The Fix |
| :--- | :--- |
| -X none: no WAL included at all | Use -X stream (default since PG 10) |
| -X fetch: WAL grabbed at end | Streams WAL in real-time during backup |
| If WAL recycled before fetch... | Backup always self-contained |
| Backup UNUSABLE! | Verify: ls backup_dir/pg_wal/ |
| FATAL: could not locate required | Should see .WAL segment files |
|   checkpoint record | Also set wal_keep_size as safety net |

### Support & Materials
If you are enjoying this course, please consider supporting it. You can donate through PayPal or UPI — the links are in the description. Every contribution helps keep this course free and growing. You can also download the class materials from GitHub — the link is in the description too.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### When to Use pg_basebackup vs pg_dump
Here is the complete decision framework for when to use pg_basebackup versus pg_dump.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is the complete decision framework for when to use pg_basebackup versus pg_dump |

### Practice Exercises
Time to practice. First, create a replication user and add a pg_hba.conf entry. Second, take a plain-format base backup with progress. Third, take a tar-format compressed backup. Fourth, restore from the tar backup to a new data directory. Fifth, try the -R flag and examine the generated standby.signal and postgresql.auto.conf.

- 1 -- CREATE ROLE replicator REPLICATION LOGIN PASSWORD 'pass'; update pg_hba.conf
- 2 -- pg_basebackup -U replicator -D /backups/plain -P --checkpoint=fast
- 3 -- pg_basebackup -U replicator -D /backups/tar -Ft -z -P
- 4 -- Extract base.tar.gz + pg_wal.tar.gz, fix ownership, start PG
- 5 -- pg_basebackup -R, examine standby.signal and auto.conf


---

## 3. Hands-On Commands & psql Output

### Prerequisites — Replication User & pg_hba.conf
**Explanation:** Before pg_basebackup will work, you need three things. First, a replication user with the REPLICATION privilege. Second, a pg_hba.conf entry allowing replication connections from your backup host. Third, wal_level set to replica or logical. Let us set all of these up.

```sql
postgres=# -- Step 1: Create replication user:
postgres=# CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'repl_pass_123';
CREATE ROLE
postgres=# -- Step 2: Check wal_level (must be replica or logical):
postgres=# SHOW wal_level;
 wal_level
-----------
 replica
(1 row)
-- -- If wal_level = 'minimal', change it and restart:
-- -- ALTER SYSTEM SET wal_level = 'replica';
-- -- Restart required (postmaster context)
-- 
-- -- Step 3: Add to pg_hba.conf:
-- -- host  replication  replicator  127.0.0.1/32  scram-sha-256
-- -- host  replication  replicator  10.0.0.0/8    scram-sha-256
-- -- Then: SELECT pg_reload_conf();
```

### Taking a Base Backup — Plain Format
**Explanation:** Now let us take our first physical backup. The simplest command copies the entire data directory to a target directory. The -D flag specifies where to put the backup. The -P flag shows a progress bar. The -R flag writes standby configuration — useful if you want to use this backup as a streaming replica later.

```sql
$ # Basic backup to a directory:
$ pg_basebackup -U replicator -D /backups/base_20261104 \
  -P --checkpoint=fast
89234/89234 kB (100%), 1/1 tablespace
$ ls /backups/base_20261104/
PG_VERSION    base/         global/       pg_commit_ts/
pg_dynshmem/  pg_hba.conf   pg_ident.conf pg_logical/
pg_multixact/ pg_notify/    pg_replslot/  pg_serial/
pg_snapshots/ pg_stat/      pg_stat_tmp/  pg_subtrans/
pg_tblspc/    pg_twophase/  pg_wal/       pg_xact/
postgresql.auto.conf  postgresql.conf  postmaster.opts
-- -- This IS a complete data directory — start PostgreSQL on it!
-- -- --checkpoint=fast: forces immediate checkpoint (starts backup sooner)
```

### Tar Format with Compression
**Explanation:** For production, use tar format with compression. The -Ft flag creates tar archives. The -z flag compresses with gzip. This is much easier to store and transfer than a raw directory. You get two files: base.tar.gz containing the data and pg_wal.tar.gz containing the WAL files needed for consistency.

```sql
$ # Compressed tar backup:
$ pg_basebackup -U replicator -D /backups/tar_20261104 \
  -Ft -z -P --checkpoint=fast
89234/89234 kB (100%), 1/1 tablespace
$ ls -lh /backups/tar_20261104/
-rw-r--r-- 1 postgres 42M base.tar.gz
-rw-r--r-- 1 postgres 17M pg_wal.tar.gz
-- -- base.tar.gz: data directory (compressed)
-- -- pg_wal.tar.gz: WAL needed for consistency
-- -- Total: 59MB compressed vs 87MB raw directory
-- 
$ # With higher compression (lz4, PG 15+):
$ pg_basebackup -U replicator -D /backups/lz4_20261104 \
  -Ft --compress=lz4 -P --checkpoint=fast
```

### Restoring from a Plain Backup
**Explanation:** Now the critical part — restoring from a physical backup. For a plain-format backup, you copy the directory to be your new data directory and start PostgreSQL. For a tar-format backup, you extract the archives first. Let us walk through both.

```sql
$ # Step 1: Stop PostgreSQL
$ sudo systemctl stop postgresql
$ # Step 2: Move old data directory aside (DO NOT delete yet!)
$ sudo mv /var/lib/postgresql/16/main /var/lib/postgresql/16/main_old
$ # Step 3: Copy backup to data directory location
$ sudo cp -r /backups/base_20261104 /var/lib/postgresql/16/main
$ # Step 4: Fix ownership
$ sudo chown -R postgres:postgres /var/lib/postgresql/16/main
$ # Step 5: Start PostgreSQL
$ sudo systemctl start postgresql
$ # Step 6: Verify
$ psql -U postgres -c 'SELECT count(*) FROM big_orders;'
  count
--------
 500000
```

### Restoring from a Tar Backup
**Explanation:** For tar-format backups, you need to extract the archives first. Extract base.tar.gz to a new data directory, then extract pg_wal.tar.gz into the pg_wal subdirectory. Same ownership fix, then start.

```sql
$ sudo systemctl stop postgresql
$ sudo mv /var/lib/postgresql/16/main /var/lib/postgresql/16/main_old
$ # Create new data directory:
$ sudo mkdir /var/lib/postgresql/16/main
$ # Extract base backup:
$ sudo tar xzf /backups/tar_20261104/base.tar.gz \
  -C /var/lib/postgresql/16/main
$ # Extract WAL files:
$ sudo tar xzf /backups/tar_20261104/pg_wal.tar.gz \
  -C /var/lib/postgresql/16/main/pg_wal
$ sudo chown -R postgres:postgres /var/lib/postgresql/16/main
$ sudo systemctl start postgresql
-- -- On Windows: extract to C:\Program Files\PostgreSQL\16\data\
-- -- Restart the PostgreSQL service from services.msc
```

### Throttling Backup I/O
**Explanation:** Another important consideration: performance impact. pg_basebackup reads the entire data directory — every byte on disk. On a production server, this creates significant I/O load. Use --max-rate to throttle the backup. On a 500GB database, an unrestricted backup might saturate your disk I/O for 30 minutes. With --max-rate=100M, it takes longer but your queries keep running smoothly.

```sql
$ # Unrestricted (uses all available I/O):
$ pg_basebackup -U replicator -D /backups/fast -Ft -z -P
500000000/500000000 kB (100%), 1/1 tablespace  [Time: 8m32s]
-- 
$ # Throttled to 100MB/s (kinder to production):
$ pg_basebackup -U replicator -D /backups/gentle -Ft -z -P \
  --max-rate=100M --checkpoint=spread
500000000/500000000 kB (100%), 1/1 tablespace  [Time: 45m10s]
-- -- 8 min vs 45 min, but queries unaffected
-- -- --checkpoint=spread (default): gradual checkpoint, less I/O spike
-- -- --checkpoint=fast: immediate checkpoint, backup starts sooner but I/O spike
```

### Creating a Standby with -R
**Explanation:** Let us also cover setting up pg_basebackup for a replica. With the -R flag, the backup is pre-configured as a standby. It creates standby.signal and writes primary_conninfo into postgresql.auto.conf. You just start PostgreSQL and it connects to the primary and starts replicating.

```sql
$ # Backup with standby configuration:
$ pg_basebackup -U replicator -D /var/lib/postgresql/16/standby \
  -Fp -R -P --checkpoint=fast
89234/89234 kB (100%), 1/1 tablespace
$ # -R created standby.signal:
$ ls /var/lib/postgresql/16/standby/standby.signal
/var/lib/postgresql/16/standby/standby.signal
$ # -R added primary_conninfo to auto.conf:
$ cat /var/lib/postgresql/16/standby/postgresql.auto.conf
primary_conninfo = 'user=replicator host=10.0.1.1 port=5432'
-- -- Start this as a separate PG instance → instant streaming replica
-- -- We cover replication in detail in Phase 24
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Missing WAL Files
Here is a beginner trap: forgetting the -X option. By default, pg_basebackup uses -X stream, which streams WAL during the backup. But if you use -X none or -X fetch with insufficient wal_keep_size, your backup may be missing WAL files needed for consistency. When you try to start PostgreSQL from that backup, it will fail with a missing WAL error. Always verify your backup includes pg_wal files.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review. pg_basebackup creates physical backups by copying the raw data directory using the replication protocol. Prerequisites: replication user, pg_hba.conf entry, wal_level = replica. Use -Ft -z for compressed tar format in production. Use --max-rate to throttle I/O on busy servers. Use -R to create a standby-ready backup. The backup is self-contained with -X stream — the default. Always verify after restore. And combined with WAL archiving, pg_basebackup is the foundation of Point-in-Time Recovery, which we cover next.

- **Physical backup: copies raw data files via replication protocol**
- **Prerequisites: REPLICATION role + pg_hba.conf + wal_level=replica**
- **Formats: -Fp (plain directory) or -Ft (tar archives)**
- **Compression: -z (gzip) or --compress=lz4 (PG 15+)**
- **-X stream (default): WAL streamed during backup — self-contained**
- **--checkpoint=fast: start sooner but brief I/O spike**
- **--max-rate=100M: throttle for production safety**
- **-R: creates standby.signal + primary_conninfo for replica**
- **Restore: stop PG → replace data dir → fix ownership → start PG**
- **Combined with WAL archiving → Point-in-Time Recovery (PITR)**


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
