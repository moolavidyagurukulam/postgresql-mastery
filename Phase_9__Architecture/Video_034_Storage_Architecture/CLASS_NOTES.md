# Storage Architecture — Data Files, WAL & TOAST
**Series:** PostgreSQL Mastery | **Phase:** Phase 9: Architecture | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we explore how PostgreSQL stores data on disk. You will learn about the data directory structure, how tables map to files, what WAL files are, how TOAST handles large values, and the role of the Free Space Map and Visibility Map. Understanding storage helps you troubleshoot disk issues and plan capacity. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should understand the memory architecture from the previous class. We learned that shared_buffers caches data pages in RAM. Now we learn where those pages actually LIVE on disk. When PostgreSQL reads a page into shared_buffers, it reads from the data directory. When it writes dirty pages back, it writes to the data directory. And before any data page is modified, the change is FIRST written to WAL — the Write-Ahead Log — for crash safety.

- You know the memory architecture: shared_buffers caches pages
- Pages are 8 KB blocks — the unit of I/O
- Previous class: memory settings and cache hit ratio
- This class: WHERE those pages live on disk
- Data directory = home of all PostgreSQL data files
- WAL = crash safety log (write-ahead logging)

### Data Directory Structure (PGDATA)
Every PostgreSQL cluster has a data directory — set during initdb. This is the most important directory in PostgreSQL. ALL data, configuration, and WAL files live here or in subdirectories. The location is stored in the PGDATA environment variable. Inside you will find postgresql.conf, pg_hba.conf, and subdirectories like base, pg_wal, pg_xact, and global. Let us look at the structure.

```
[PGDATA/]
[base/
(table data)]
[pg_wal/
(WAL files)]
[global/
(shared catalogs)]
[pg_xact/
(commit status)]
[pg_stat/
(statistics)]
[postgresql.conf
pg_hba.conf]
```

### Files Per Table
Each table and index has associated files beyond the main data file. The Free Space Map tracks which pages have free space for new rows — the FSM file has the underscore fsm suffix. The Visibility Map tracks which pages have only visible tuples and can be skipped during VACUUM — the VM file has underscore vm. These helper files make INSERT and VACUUM operations efficient.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Main File** | 16400 — the actual data pages (8 KB each) |
| **FSM** | 16400_fsm — Free Space Map (where to insert new rows) |
| **VM** | 16400_vm — Visibility Map (clean pages for VACUUM) |
| **Init Fork** | 16400_init — only for unlogged tables |
| **Segments** | 16400.1, 16400.2 — when file exceeds 1 GB |

**Notes:**
- Each page = 8 KB, max ~232 rows per page for small rows

### TOAST — Oversized Attribute Storage
TOAST stands for The Oversized-Attribute Storage Technique. PostgreSQL pages are eight kilobytes, and a row must fit in a single page. But what if a column has a very large text value or a big JSONB document? TOAST compresses the value first. If it still does not fit, TOAST moves it to a separate TOAST table and stores a pointer in the original row. This happens automatically — you do not need to configure anything.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Problem** | Row must fit in one 8 KB page, but data can be huge |
| **Step 1** | Compress the value (pglz or lz4 in PG 14+) |
| **Step 2** | If still too big, move to a separate TOAST table |
| **Pointer** | Original row stores a small pointer to TOAST chunks |
| **Automatic** | No config needed — happens transparently |

**Notes:**
- Threshold: ~2 KB triggers TOAST (1/4 of page size)
- TOAST table name: pg_toast.pg_toast_<oid>

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### WAL — Write-Ahead Logging
WAL — Write-Ahead Logging — is PostgreSQL's crash safety mechanism. Before ANY data page change is written to disk, the change is FIRST recorded in the WAL. WAL files live in pg_wal inside the data directory. Each WAL file is sixteen megabytes by default. If the server crashes, PostgreSQL replays the WAL on startup to recover committed transactions. WAL is also used for replication — streaming the WAL to replicas keeps them in sync.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Rule** | EVERY change written to WAL BEFORE data files |
| **Location** | pg_wal/ directory inside PGDATA |
| **File Size** | 16 MB each (configurable with wal_segment_size) |
| **Crash Recovery** | Replay WAL on startup to recover committed transactions |
| **Replication** | Stream WAL to replicas for real-time sync |

**Notes:**
- Never delete WAL files manually!
- WAL archiving: copies completed WAL for PITR backup

### Other Key Directories
The pg_xact directory stores commit status for each transaction — whether it committed, aborted, or is still in progress. This is the CLOG — Commit Log. PostgreSQL checks the CLOG to know if a transaction's changes should be visible. The global directory contains cluster-wide system catalogs like pg_database and pg_authid that are shared across all databases.

| pg_xact (CLOG) | global/ |
| :--- | :--- |
| Commit Log: status of every transaction | Cluster-wide shared catalogs |
| States: committed, aborted, in-progress | pg_database, pg_authid, pg_tablespace |
| Used by MVCC visibility checks | Shared across ALL databases |
| Small files, grows with transaction count | Has its own FSM and VM files too |

### Data Directory Reference
Here is a complete reference of what lives in the data directory. This is the storage architecture you need to know for production PostgreSQL. Notice how everything — tables, indexes, WAL, transaction status, statistics — all lives under one directory tree. Back up this directory and you back up everything.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a complete reference of what lives in the data directory |
| **Point 2** | This is the storage architecture you need to know for production PostgreSQL |
| **Notice how everything** | tables, indexes, WAL, transaction status, statistics — all lives under one directory tree |
| **Point 4** | Back up this directory and you back up everything |

### Storage Monitoring Checklist
Here is a decision framework for storage monitoring in production. Check these regularly: total database size, largest tables, WAL directory size, replication slot retention, dead tuple counts, and temp file usage. Set alerts when disk usage crosses 80 percent. And never store anything else on the same disk as PGDATA — database files need all the I/O bandwidth they can get.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a decision framework for storage monitoring in production |
| **Check these regularly** | total database size, largest tables, WAL directory size, replication slot retention, dead tuple counts, and temp file... |
| **Point 3** | Set alerts when disk usage crosses 80 percent |
| **Point 4** | And never store anything else on the same disk as PGDATA — database files need all the I/O bandwidth they can get |

### Practice Exercises
Practice exercises: find your data directory, look up a table's file path, measure table sizes, check the WAL position and size, look at the database's OID, check for replication slots and dead tuples, and monitor temp file usage.

- 1. SHOW data_directory; — find your PGDATA
- 2. SELECT pg_relation_filepath('your_table');
- 3. Check table size vs total size with pg_size_pretty()
- 4. SELECT oid, datname FROM pg_database;
- 5. SELECT pg_current_wal_lsn();
- 6. SELECT pg_size_pretty(sum(size)) FROM pg_ls_waldir();
- 7. Check database total size: pg_database_size(current_database())


---

## 3. Hands-On Commands & psql Output

### Find Data Directory and Table Files
**Explanation:** You can find your data directory using SHOW data_directory. Inside the base folder, each database has its own subdirectory named by its OID — Object ID. Every table, index, and sequence within that database is stored as one or more files, also named by their OID. When a table file grows beyond one gigabyte, PostgreSQL splits it into one-gigabyte segments.

```sql
-- Where is my data directory?
practice=# SHOW data_directory;
       data_directory
-----------------------------
 /var/lib/postgresql/16/main

-- OID of the 'practice' database
practice=# SELECT oid, datname FROM pg_database WHERE datname = 'practice';
  oid  | datname
-------+----------
 16384 | practice

-- Table files live in: base/<db_oid>/<table_filenode>
practice=# SELECT pg_relation_filepath('employees');
 pg_relation_filepath
----------------------
 base/16384/16400
```

### Check Table and Index Sizes on Disk
**Explanation:** You can check the actual file size of any table on disk using pg_relation_size and pg_total_relation_size. The relation size is just the main data fork. The total size includes indexes, TOAST data, FSM, and VM. The difference between the two tells you how much overhead your indexes and TOAST add.

```sql
-- Table data file only
practice=# SELECT pg_size_pretty(pg_relation_size('employees')) AS table_size;
 table_size
------------
 8192 bytes

-- Total size (table + indexes + TOAST + FSM + VM)
practice=# SELECT pg_size_pretty(pg_total_relation_size('employees')) AS total_size;
 total_size
------------
 40 kB

-- All tables sorted by size
practice=# SELECT relname,
  pg_size_pretty(pg_relation_size(oid)) AS data,
  pg_size_pretty(pg_total_relation_size(oid)) AS total
FROM pg_class WHERE relkind = 'r'
  AND relnamespace = 'public'::regnamespace
ORDER BY pg_total_relation_size(oid) DESC;
```

### Check WAL Status
**Explanation:** You can check the current WAL position and file usage. The WAL grows and PostgreSQL recycles old files that are no longer needed. If WAL files accumulate and fill your disk, it usually means a replication slot is holding them, archiving is stuck, or wal_keep_size is set too high. Monitoring WAL size is critical in production.

```sql
-- Current WAL position
practice=# SELECT pg_current_wal_lsn();
 pg_current_wal_lsn
--------------------
 0/1A3B4C8

-- WAL directory size (from SQL)
practice=# SELECT pg_size_pretty(sum(size)) AS wal_size
FROM pg_ls_waldir();
 wal_size
----------
 48 MB

-- WAL settings
practice=# SHOW wal_level;
 wal_level
-----------
 replica

practice=# SHOW max_wal_size;
 max_wal_size
--------------
 1GB
```

### Beginner Trap: Disk Space Emergencies
**Explanation:** Beginner trap: running out of disk space is the number one PostgreSQL emergency. WAL files grow when replication slots are inactive or archiving is stuck. Temp files from large sorts or hash joins can fill pg_default tablespace. And table bloat from missed VACUUM means dead rows consume space that cannot be reused. Here is how to diagnose each one quickly.

```sql
-- Check WAL directory size (biggest offender)
practice=# SELECT pg_size_pretty(sum(size)) FROM pg_ls_waldir();
 48 MB  -- if this is many GB, check replication slots:

practice=# SELECT slot_name, active,
  pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(),
    restart_lsn)) AS retained
FROM pg_replication_slots;

-- Check temp file usage
practice=# SELECT pg_size_pretty(temp_bytes) AS temp_used
FROM pg_stat_database WHERE datname = current_database();

-- Check table bloat (dead rows)
practice=# SELECT relname, n_dead_tup,
  pg_size_pretty(pg_relation_size(oid)) AS size
FROM pg_stat_user_tables ORDER BY n_dead_tup DESC LIMIT 5;

-- Fix: VACUUM FULL reclaims space (locks table!)
-- Fix: drop inactive replication slots
-- Fix: set temp_file_limit to cap temp usage
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Disk Space Emergencies
Beginner trap: running out of disk space is the number one PostgreSQL emergency. WAL files grow when replication slots are inactive or archiving is stuck. Temp files from large sorts or hash joins can fill pg_default tablespace. And table bloat from missed VACUUM means dead rows consume space that cannot be reused. Here is how to diagnose each one quickly.

```sql
-- Check WAL directory size (biggest offender)
SELECT pg_size_pretty(sum(size)) FROM pg_ls_waldir();
 48 MB  -- if this is many GB, check replication slots:

SELECT slot_name, active,
  pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(),
    restart_lsn)) AS retained
FROM pg_replication_slots;

-- Check temp file usage
SELECT pg_size_pretty(temp_bytes) AS temp_used
FROM pg_stat_database WHERE datname = current_database();

-- Check table bloat (dead rows)
SELECT relname, n_dead_tup,
  pg_size_pretty(pg_relation_size(oid)) AS size
FROM pg_stat_user_tables ORDER BY n_dead_tup DESC LIMIT 5;

-- Fix: VACUUM FULL reclaims space (locks table!)
-- Fix: drop inactive replication slots
-- Fix: set temp_file_limit to cap temp usage
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap. PostgreSQL stores everything under the data directory — PGDATA. Each database gets a subdirectory in base, with files named by OID. Tables split into one-gigabyte segments. TOAST handles values too large for an eight-kilobyte page by compressing and moving them to a side table. WAL files in pg_wal record every change before it hits data files — this guarantees crash recovery. The FSM and VM help INSERT and VACUUM work efficiently. In the next class, we explore Query Flow and MVCC — how a query travels through PostgreSQL and how multi-version concurrency works. See you there!

- **PGDATA: home of all PostgreSQL data and config**
- **base/<db_oid>/<filenode>: table data files**
- **Pages are 8 KB, files split at 1 GB segments**
- **FSM: tracks free space for inserts**
- **VM: tracks all-visible pages for VACUUM**
- **TOAST: compresses/moves large values automatically**
- **pg_wal: WAL files for crash recovery and replication**
- **pg_xact: transaction commit status (CLOG)**


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
