# pg_dump & pg_restore
**Series:** PostgreSQL Mastery | **Phase:** Phase 18: Backup, Recovery & Disaster Recovery | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we go fully hands-on with pg_dump and pg_restore — the logical backup and restore tools built into PostgreSQL. pg_dump is the tool you will use most often. It exports your database as SQL statements or a compressed archive that can rebuild everything — tables, data, indexes, constraints, functions, triggers — from scratch. Let us learn every option and format. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### pg_dump Output Formats
pg_dump has four output formats. Plain SQL is the default — it writes CREATE TABLE and INSERT statements as readable text. Custom format is compressed and supports parallel restore. Directory format writes one file per table — best for parallel dump and restore. Tar format is an uncompressed archive. For production, always use custom format — it compresses well and restores fast.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Plain SQL** | the default — it writes CREATE TABLE and INSERT statements as readable text |
| **Custom format** | compressed and supports parallel restore |
| **Tar format** | an uncompressed archive |

### pg_dump Selective Options
pg_dump has many useful options for selective backups. You can dump specific tables, exclude tables, dump only the schema without data, or dump only the data without the schema. The --clean option adds DROP statements before CREATE — useful for refreshing a test database.

| Term | Meaning / Explanation |
| :--- | :--- |
| **--table (-t)** | Dump only specific tables: -t orders -t customers |
| **--exclude-table (-T)** | Dump everything EXCEPT: -T audit_log -T temp_data |
| **--schema (-n)** | Dump only specific schemas: -n public -n sales |
| **--schema-only (-s)** | Schema only — CREATE TABLE, no data (for recreating structure) |
| **--data-only (-a)** | Data only — COPY/INSERT, no schema (for refreshing data) |
| **--clean (-c)** | Add DROP statements before CREATE (refresh existing DB) |
| **--if-exists** | Add IF EXISTS to DROP — avoids errors on fresh DB |
| **--no-owner (-O)** | Skip ownership commands — useful when restoring as different user |

**Notes:**
- Combine options: pg_dump -Fc -t orders -t customers -d myapp -f orders.dump

### Beginner Trap: Misleading Restore Errors
Here is a critical beginner trap. When you restore a custom-format dump, pg_restore might print errors and appear to fail — but the restore actually succeeded. This happens when the dump was created with --clean and the target database does not have the objects yet, so the DROP commands fail. The CREATE and data loading still succeed. Use --if-exists with --clean to avoid these misleading errors.

| Scary but Harmless | Fix: Use --if-exists |
| :--- | :--- |
| pg_restore: error: DROP TABLE failed | pg_restore --clean --if-exists |
| pg_restore: error: table does not exist | DROP IF EXISTS — no error if missing |
| These happen with --clean on empty DB | Or: --no-data-for-failed-tables |
| The CREATES still succeed! | Check exit code: echo $? |
| Data loads correctly! | 0 = success (with warnings) |

### Support & Materials
If you are enjoying this course, please consider supporting it. You can donate through PayPal or UPI — the links are in the description. Every contribution helps keep this course free and growing. You can also download the class materials from GitHub — the link is in the description too. Now let us look at automation.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### pg_dump Consistency and Locking
One more important topic: pg_dump takes a consistent snapshot. When pg_dump starts, it takes a snapshot of the database using a serializable transaction. This means the dump is consistent — it captures the database as it was at one moment in time, even if other transactions are writing during the dump. However, pg_dump does take a shared lock on each table, which blocks DDL operations like ALTER TABLE and DROP TABLE. Never run DDL during a pg_dump.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Consistent Snapshot** | Dump captures all data at a single point in time — SERIALIZABLE transaction |
| **Shared Lock (AccessShareLock)** | Blocks DDL (ALTER TABLE, DROP TABLE) but NOT reads or writes |
| **Normal DML OK** | INSERT, UPDATE, DELETE continue normally during dump |
| **DDL Blocked** | ALTER TABLE, DROP TABLE, TRUNCATE wait until dump finishes |

**Notes:**
- pg_dump on a 100GB table can take 30+ minutes — plan DDL accordingly
- Use --lock-wait-timeout to avoid indefinite waits

### Quick Reference — Essential Options
Here is the complete pg_dump and pg_restore reference. These are the options you will use most often in production.

| Command | What It Does |
| :--- | :--- |
| pg_dump -Fc -d mydb -f backup.dump | Custom format backup (production standard) |
| pg_dump -Fd -j 4 -d mydb -f dir/ | Parallel directory backup (4 workers) |
| pg_dump -Fc -t orders -d mydb -f tbl.dump | Single table backup |
| pg_dump -s -d mydb > schema.sql | Schema only (no data) |
| pg_dumpall --globals-only > roles.sql | Roles and tablespaces only |
| pg_restore -d mydb -j 4 backup.dump | Parallel restore (4 workers) |
| pg_restore -d mydb -t orders backup.dump | Restore single table |
| pg_restore -l backup.dump > toc.list | List table of contents |
| pg_restore -d mydb -L toc.list backup.dump | Selective restore from TOC |

### Practice Exercises
Time to practice. First, create a custom format dump of your practice database. Second, list its Table of Contents with pg_restore -l. Third, create a fresh database and restore the dump into it with pg_restore. Fourth, try a selective restore — restore just one table from the full dump. Fifth, write a backup script with timestamped filenames and test it.

- 1 -- pg_dump -Fc -d trigger_lab -f trigger_lab.dump
- 2 -- pg_restore -l trigger_lab.dump — see all objects in the dump
- 3 -- createdb restored_db; pg_restore -d restored_db trigger_lab.dump
- 4 -- pg_restore -d restored_db -t employees --clean --if-exists trigger_lab.dump
- 5 -- Write a script with timestamp, pg_dump, pg_restore -l verify, find cleanup


---

## 3. Hands-On Commands & psql Output

### Basic pg_dump — Plain SQL
**Explanation:** Let us start with the simplest case — a plain SQL dump. This creates a readable SQL file that you can open in any text editor. It starts with SET statements, then CREATE TABLE, then COPY commands to load the data, then ALTER TABLE for constraints, and finally CREATE INDEX.

```sql
$ pg_dump -U postgres -d trigger_lab > trigger_lab_backup.sql

$ ls -lh trigger_lab_backup.sql
-rw-r--r-- 1 postgres postgres 4.2M Nov 04 10:00 trigger_lab_backup.sql
$ head -30 trigger_lab_backup.sql
--
-- PostgreSQL database dump
--
SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
...
CREATE TABLE public.big_orders (
    id integer NOT NULL,
    customer_id integer NOT NULL,
    ...
-- -- Plain SQL: readable but large and slow to restore
```

### Custom Format — Production Standard
**Explanation:** Now the production format — custom. The -Fc flag creates a compressed binary archive. It is typically 5 to 10 times smaller than plain SQL. And pg_restore can restore it in parallel using the -j flag — dramatically faster on multi-core servers. Always use -Fc for production backups.

```sql
$ pg_dump -U postgres -Fc -d trigger_lab -f trigger_lab.dump

$ ls -lh trigger_lab.dump
-rw-r--r-- 1 postgres postgres 892K Nov 04 10:01 trigger_lab.dump
-- -- 892KB compressed vs 4.2MB plain SQL — 5x smaller!
$ # Directory format for parallel dump:
$ pg_dump -U postgres -Fd -j 4 -d trigger_lab -f trigger_lab_dir/

$ ls trigger_lab_dir/
toc.dat  3456.dat.gz  3457.dat.gz  3458.dat.gz  ...
-- -- -j 4 = 4 parallel workers dumping tables simultaneously
-- -- Each table gets its own compressed .dat.gz file
```

### Selective Dumps — Hands On
**Explanation:** Let us see selective dumps in action. We will dump just one table, then dump the schema without any data, then dump everything except our big_orders table.

```sql
$ # Single table dump:
$ pg_dump -U postgres -Fc -t big_orders -d trigger_lab -f big_orders.dump

$ # Schema only (structure, no data):
$ pg_dump -U postgres -s -d trigger_lab > schema_only.sql

$ # Everything except big_orders:
$ pg_dump -U postgres -Fc -T big_orders -d trigger_lab -f without_big.dump

$ # Dump with compression level (0-9, default 6):
$ pg_dump -U postgres -Fc -Z 9 -d trigger_lab -f max_compress.dump

$ ls -lh *.dump
-rw-r--r-- 1 postgres  892K trigger_lab.dump
-rw-r--r-- 1 postgres  780K big_orders.dump
-rw-r--r-- 1 postgres  112K without_big.dump
-rw-r--r-- 1 postgres  845K max_compress.dump
```

### pg_dumpall — Globals and All Databases
**Explanation:** pg_dumpall is a separate tool that dumps ALL databases on the server plus global objects — roles, tablespaces, and role memberships. pg_dump only dumps one database and skips globals. If you use pg_dump alone, you lose your user accounts and their passwords. Always run pg_dumpall with --globals-only alongside your per-database pg_dump backups.

```sql
$ # Dump ONLY globals (roles, tablespaces):
$ pg_dumpall -U postgres --globals-only > globals.sql

$ cat globals.sql
CREATE ROLE alice;
ALTER ROLE alice WITH LOGIN PASSWORD 'md5abc123...';
CREATE ROLE bob;
ALTER ROLE bob WITH LOGIN PASSWORD 'SCRAM-SHA-256$...';
GRANT writer TO alice;
GRANT admin_role TO bob;
-- 
$ # Dump ALL databases (one giant SQL file):
$ pg_dumpall -U postgres > full_cluster.sql
-- -- pg_dumpall outputs plain SQL only — no custom/directory format
-- -- For large servers: pg_dumpall --globals-only + per-DB pg_dump -Fc
```

### Restoring — psql vs pg_restore
**Explanation:** Now let us restore. Restoring a plain SQL dump uses psql. Restoring a custom or directory format uses pg_restore. The key difference: pg_restore supports parallel restore with -j, selective restore from the Table of Contents, and many more options. Let us see both.

```sql
$ # Create a fresh target database:
$ createdb -U postgres trigger_lab_restored

$ # Restore plain SQL:
$ psql -U postgres -d trigger_lab_restored < trigger_lab_backup.sql
SET
CREATE TABLE
COPY 500000
...
$ # Restore custom format:
$ pg_restore -U postgres -d trigger_lab_restored trigger_lab.dump

$ # Restore with 4 parallel jobs (MUCH faster):
$ pg_restore -U postgres -d trigger_lab_restored -j 4 trigger_lab.dump
-- -- -j 4 restores 4 tables simultaneously — huge speed boost
```

### Selective Restore with Table of Contents
**Explanation:** pg_restore has a powerful feature: the Table of Contents. You can list every item in a dump file and selectively restore only what you need. This is extremely useful when you need to restore just one table from a full database backup.

```sql
$ # List the Table of Contents:
$ pg_restore -l trigger_lab.dump | head -20
;
; Archive created at 2026-11-04 10:00:00
;     Dump Version: 1.14-0
;
3456; 1259 16500 TABLE public big_orders postgres
3457; 1259 16510 TABLE public employees postgres
3458; 1259 16520 TABLE public audit_log postgres
3460; 0 16500 TABLE DATA public big_orders postgres
3461; 0 16510 TABLE DATA public employees postgres
...
$ # Save TOC to file, edit to keep only what you want:
$ pg_restore -l trigger_lab.dump > toc.list
$ # Edit toc.list — comment out (;) lines you don't want
$ pg_restore -U postgres -d target_db -L toc.list trigger_lab.dump
-- -- -L toc.list: restore ONLY the items listed in the file
```

### Restore a Single Table
**Explanation:** Here is another very useful restore pattern: restoring a single table from a full backup. Use the -t flag with pg_restore. You can also restore just the data with --data-only, or just the schema with --schema-only.

```sql
$ # Restore just the employees table:
$ pg_restore -U postgres -d trigger_lab_restored \
  -t employees --clean --if-exists trigger_lab.dump

$ # Restore only data (table already exists):
$ pg_restore -U postgres -d trigger_lab_restored \
  -t employees --data-only trigger_lab.dump

$ # Restore creating the database too (-C):
$ pg_restore -U postgres -C trigger_lab.dump
-- -- -C creates the database before restoring into it
-- -- --clean drops objects first, --if-exists avoids errors
-- -- Combine: pg_restore -C --clean --if-exists -d postgres dump.file
```

### Production Backup Script (Bash)
**Explanation:** In production, you automate pg_dump with a script. This script creates timestamped backups, compresses them, verifies the dump succeeded, and deletes backups older than 7 days. Run it via cron on Linux or Task Scheduler on Windows.

```sql
#!/bin/bash
# pg_dump backup script — run via cron

DB_NAME="myapp"
BACKUP_DIR="/backups/pg_dumps"
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.dump"

# Create backup directory if missing
mkdir -p "$BACKUP_DIR"

# Dump in custom format
pg_dump -U postgres -Fc -d "$DB_NAME" -f "$FILE"

# Verify the dump is valid
if pg_restore -l "$FILE" > /dev/null 2>&1; then
    echo "Backup OK: $FILE ($(du -h $FILE | cut -f1))"
else
    echo "ERROR: Backup verification failed!" >&2
    exit 1
fi

# Delete backups older than retention period
find "$BACKUP_DIR" -name '*.dump' -mtime +$RETENTION_DAYS -delete

echo "Cleanup done. Remaining backups:"
ls -lh "$BACKUP_DIR"/*.dump
```

### Scheduling with Cron
**Explanation:** For Linux, schedule the backup with cron. For Windows, use Task Scheduler. The cron entry runs the script every night at 2 AM. The pg_restore -l verification step is critical — it ensures the dump file is valid and not truncated or corrupted.

```sql
$ # Edit the crontab:
$ crontab -e

# Daily backup at 2:00 AM:
0 2 * * * /opt/scripts/pg_backup.sh >> /var/log/pg_backup.log 2>&1

# Hourly backup of critical tables:
0 * * * * pg_dump -U postgres -Fc -t orders -t payments \
    -d myapp -f /backups/hourly/critical_$(date +\%H).dump
-- 
-- -- Windows: use Task Scheduler with pg_dump.exe
-- -- "C:\Program Files\PostgreSQL\16\bin\pg_dump.exe" -Fc -d myapp -f backup.dump
-- -- Schedule: Daily trigger at 2:00 AM
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Misleading Restore Errors
Here is a critical beginner trap. When you restore a custom-format dump, pg_restore might print errors and appear to fail — but the restore actually succeeded. This happens when the dump was created with --clean and the target database does not have the objects yet, so the DROP commands fail. The CREATE and data loading still succeed. Use --if-exists with --clean to avoid these misleading errors.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review. pg_dump creates logical backups — SQL or compressed archives. Four formats: plain, custom, directory, tar. Use custom format for production — it compresses and supports parallel restore. pg_dumpall dumps global objects — roles and tablespaces. pg_restore restores custom, directory, and tar formats. Use -j for parallel restore. Use -l and -L for selective restore from the Table of Contents. Automate with cron and always verify with pg_restore -l. And remember: pg_dump provides a consistent snapshot but blocks DDL.

- **pg_dump: logical backup — exports SQL or compressed archive**
- **Use -Fc (custom format) for production — compressed + parallel**
- **Use -Fd (directory) for parallel dump AND restore**
- **Selective: -t table, -T exclude, -n schema, -s schema-only, -a data-only**
- **pg_dumpall --globals-only: roles + tablespaces (pg_dump misses these!)**
- **pg_restore -j N: parallel restore (4-8 workers typical)**
- **pg_restore -l: list TOC; -L file: selective restore**
- **--clean --if-exists: safe refresh of existing database**
- **Consistent snapshot: DML OK during dump, DDL blocked**
- **Always verify: pg_restore -l dump.file > /dev/null**


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
