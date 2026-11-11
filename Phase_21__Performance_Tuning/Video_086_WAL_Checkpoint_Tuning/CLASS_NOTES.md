# WAL & Checkpoint Tuning
**Series:** PostgreSQL Mastery | **Phase:** Phase 21: Performance Tuning | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In the previous class, we tuned memory — shared_buffers, work_mem, and the rest. Now we tune the WAL — Write-Ahead Log — and checkpoints. The WAL is how PostgreSQL guarantees your data survives a crash. Every change is written to the WAL before it is applied to the actual data files. Checkpoints flush all dirty pages from shared_buffers to disk. Tuning these controls the balance between write performance and crash recovery time. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Checkpoint Frequency Trade-off
The key insight for tuning: more frequent checkpoints mean faster crash recovery but more I/O during normal operation. Less frequent checkpoints mean better write performance but longer recovery after a crash. The default settings are conservative — designed for small databases. For production, you almost always need to increase max_wal_size and tune checkpoint behavior.

| Frequent Checkpoints | Less Frequent Checkpoints |
| :--- | :--- |
| More I/O spikes during operation | Smoother I/O during normal operation |
| Shorter crash recovery time | Longer crash recovery time |
| WAL files recycled sooner (less disk usage) | More WAL files on disk |
| Dirty pages flushed often | Dirty pages accumulate longer |
| More full-page writes in WAL | Fewer full-page writes overall |
| Default behavior (conservative) | Better write performance |

### full_page_writes — Torn Page Protection
full_page_writes is a critical WAL safety feature. After each checkpoint, the first time a data page is modified, PostgreSQL writes the ENTIRE page (8KB) to the WAL — not just the changed bytes. This protects against torn pages — partial writes during a crash. It increases WAL volume significantly, but you should almost never disable it.

| Term | Meaning / Explanation |
| :--- | :--- |
| **The Problem: Torn Pages** | OS writes 8KB page in two 4KB chunks — crash between them = corrupted page |
| **The Solution: Full Page Writes** | After checkpoint, first modification writes entire 8KB page to WAL |
| **The Cost** | WAL volume increases 2-3x after each checkpoint (more I/O) |
| **The Rule** | NEVER disable full_page_writes unless using ZFS or a battery-backed RAID |

**Notes:**
- full_page_writes = on (default — keep it on!)
- More frequent checkpoints = more full-page writes (another reason to increase checkpoint_timeout)
- wal_compression = on reduces the WAL size of full-page writes

### wal_level — How Much Goes Into WAL
wal_level controls how much information is written to WAL. The default in PG 16 is 'replica', which supports streaming replication. If you do not need replication or point-in-time recovery, you can use 'minimal' — but this is rare in production. If you need logical replication, set it to 'logical'.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | wal_level controls how much information is written to WAL |
| **The default in PG 16 is 'replica'** | which supports streaming replication |
| **If you do not need replication or point** | in-time recovery, you can use 'minimal' — but this is rare in production |
| **If you need logical replication** | set it to 'logical' |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### synchronous_commit — Speed vs Durability
The synchronous_commit parameter controls when a transaction commit returns to the client. By default, it waits for WAL to be flushed to disk — full durability. Setting it to 'off' means the commit returns immediately without waiting for the WAL flush. This is faster but risks losing the last few milliseconds of transactions after a crash.

| synchronous_commit = on (Default) | synchronous_commit = off |
| :--- | :--- |
| Commit waits for WAL disk flush | Commit returns immediately |
| Zero data loss on crash | May lose last ~600ms of commits on crash |
| Slower commits (disk latency) | 2-5x faster commit throughput |
| Required for financial data | OK for: logs, analytics, sessions |
| Default — always safe | NOT for: money, orders, inventory |

### WAL Tuning by Workload Type
Here is a decision framework for WAL tuning based on your workload type.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a decision framework for WAL tuning based on your workload type |


---

## 3. Hands-On Commands & psql Output

### max_wal_size — Checkpoint Trigger by WAL Volume
**Explanation:** Let us start with max_wal_size — this controls when a checkpoint is triggered by the amount of WAL generated. The default is only 1 gigabyte. On a busy server, that means checkpoints every few minutes, causing I/O spikes. For production, set it to 4 to 16 gigabytes.

```sql
postgres=# -- Check current settings:
postgres=# SHOW max_wal_size;
 max_wal_size
postgres=# --------------
 1GB
postgres=# SHOW min_wal_size;
 min_wal_size
postgres=# --------------
 80MB
postgres=# -- How it works:
postgres=# -- PostgreSQL triggers a checkpoint when WAL generated since
postgres=# -- last checkpoint exceeds max_wal_size
postgres=# -- With max_wal_size = 1GB on a busy server:
postgres=# -- 100 MB/min WAL → checkpoint every ~10 minutes
postgres=# -- I/O spike every 10 minutes as dirty pages flush
postgres=# -- With max_wal_size = 8GB:
postgres=# -- 100 MB/min WAL → checkpoint every ~80 minutes
postgres=# -- I/O spread out over longer periods
postgres=# -- Check checkpoint frequency:
postgres=# SELECT * FROM pg_stat_bgwriter;
postgres=# -- checkpoints_timed: from checkpoint_timeout
postgres=# -- checkpoints_req: from max_wal_size exceeded
```

### checkpoint_completion_target — Spreading I/O
**Explanation:** checkpoint_completion_target controls how quickly a checkpoint writes dirty pages. With a value of 0.9 and a checkpoint_timeout of 15 minutes, PostgreSQL spreads the writes over 13.5 minutes — 90% of 15 minutes. This prevents I/O spikes. If you set it to 0.5, writes are compressed into 7.5 minutes, causing sharper I/O spikes. Keep it at 0.9.

```sql
postgres=# -- Current setting:
postgres=# SHOW checkpoint_completion_target;
 checkpoint_completion_target
postgres=# -----------------------------
 0.9
postgres=# -- With checkpoint_timeout = 15min:
postgres=# -- target = 0.9 → spread writes over 13.5 minutes (smooth)
postgres=# -- target = 0.5 → compress writes into 7.5 minutes (spiky)
postgres=# -- target = 0.1 → rush writes in 1.5 minutes (very spiky!)
postgres=# -- Check checkpoint statistics:
postgres=# SELECT checkpoints_timed,
       checkpoints_req,
       buffers_checkpoint,
       buffers_clean,
       buffers_backend,
       pg_size_pretty(
         buffers_checkpoint * 8192::bigint
       ) AS checkpoint_data_written
postgres-# FROM pg_stat_bgwriter;
postgres=# -- checkpoints_timed: triggered by timeout (expected)
postgres=# -- checkpoints_req: triggered by WAL size (if frequent → increase max_wal_size)
postgres=# -- buffers_backend: dirty pages written by backends (should be low!)
postgres=# --   High buffers_backend = shared_buffers too small
```

### wal_buffers — WAL Write Buffer
**Explanation:** Now the WAL buffer — wal_buffers. This is a small buffer in shared memory where WAL records are collected before being flushed to disk. The default is auto-calculated as 1/32 of shared_buffers, capped at 64 megabytes. For most servers, the auto value is fine. Only increase it if you have extremely write-heavy workloads.

```sql
postgres=# -- Check current setting:
postgres=# SHOW wal_buffers;
 wal_buffers
postgres=# -------------
 4MB
postgres=# -- Default: -1 (auto = 1/32 of shared_buffers, max 64MB)
postgres=# -- shared_buffers = 8GB → wal_buffers = 256MB... capped to 64MB
postgres=# -- shared_buffers = 128MB → wal_buffers = 4MB
postgres=# -- For most workloads, auto is correct.
postgres=# -- Only set manually if:
postgres=# -- 1. You see WAL write contention in pg_stat_wal
postgres=# -- 2. You have extremely high transaction throughput
postgres=# -- Check WAL statistics (PG 16):
postgres=# SELECT wal_records,
       wal_fpi,
       wal_bytes,
       pg_size_pretty(wal_bytes) AS wal_generated,
       wal_buffers_full,
       wal_write,
       wal_sync
postgres-# FROM pg_stat_wal;
postgres=# -- wal_buffers_full > 0 means wal_buffers was too small
postgres=# -- at some point — consider increasing
```

### wal_compression — Reduce WAL Volume
**Explanation:** wal_compression reduces WAL volume by compressing full-page images. Since full-page writes are the biggest contributor to WAL size, compression can reduce WAL by 30 to 50 percent with minimal CPU overhead. Enable it on any server with PG 16.

```sql
postgres=# -- Check current setting:
postgres=# SHOW wal_compression;
 wal_compression
postgres=# -----------------
 off
postgres=# -- Enable WAL compression:
postgres=# -- postgresql.conf:
postgres=# -- wal_compression = 'zstd'  (PG 16 supports: pglz, lz4, zstd)
postgres=# -- PG 16 options:
postgres=# -- pglz: built-in, moderate compression, moderate CPU
postgres=# -- lz4: fast compression, moderate ratio (recommended)
postgres=# -- zstd: best compression ratio, moderate CPU
postgres=# -- Impact:
postgres=# -- Without compression: 10 GB WAL per hour
postgres=# -- With zstd: ~6 GB WAL per hour (40% reduction)
postgres=# -- Benefits:
postgres=# -- Less disk space for WAL
postgres=# -- Faster WAL archiving and replication
postgres=# -- Less I/O from WAL writes
postgres=# -- Trade-off: slight CPU overhead (minimal on modern CPUs)
```

### Per-Transaction synchronous_commit
**Explanation:** You can set synchronous_commit per-transaction. Use 'off' for bulk inserts or logging tables where losing a few rows is acceptable, and keep 'on' for critical transactions.

```sql
postgres=# -- Global default: on (safe)
postgres=# -- postgresql.conf: synchronous_commit = on
postgres=# -- For a logging session (loss acceptable):
postgres=# SET synchronous_commit = off;
postgres=# INSERT INTO access_log (user_id, action, ts)
postgres-# VALUES (42, 'page_view', now());
postgres=# -- Returns instantly — WAL flushed asynchronously
postgres=# -- For a critical transaction (no loss allowed):
postgres=# SET synchronous_commit = on;
postgres=# BEGIN;
postgres=# UPDATE accounts SET balance = balance - 100 WHERE id = 1;
postgres=# UPDATE accounts SET balance = balance + 100 WHERE id = 2;
postgres=# COMMIT;
postgres=# -- Waits for WAL to be on disk before returning
postgres=# -- Per-table approach using ALTER TABLE:
postgres=# -- Not directly supported — use SET LOCAL in transactions
postgres=# BEGIN;
postgres=# SET LOCAL synchronous_commit = off;
postgres=# INSERT INTO metrics (name, value) VALUES ('cpu', 85.5);
postgres=# COMMIT;
postgres=# -- synchronous_commit resets automatically after COMMIT
```

### Monitoring WAL & Checkpoint Performance
**Explanation:** Here is how to monitor checkpoint and WAL performance. These queries tell you whether your settings are working correctly.

```sql
-- Checkpoint statistics:
SELECT checkpoints_timed,    -- from timeout (expected)
       checkpoints_req,       -- from WAL size (reduce these!)
       buffers_checkpoint,    -- pages written by checkpoint
       buffers_clean,         -- pages written by bgwriter
       buffers_backend,       -- pages written by backends (BAD if high)
       maxwritten_clean       -- bgwriter stopped early (increase lru_maxpages)
FROM pg_stat_bgwriter;

-- If checkpoints_req >> checkpoints_timed:
--   → increase max_wal_size
-- If buffers_backend > 0.1 × buffers_checkpoint:
--   → increase shared_buffers or bgwriter throughput
-- If maxwritten_clean > 0:
--   → increase bgwriter_lru_maxpages

-- WAL generation rate:
SELECT pg_size_pretty(wal_bytes) AS total_wal_generated,
       wal_buffers_full
FROM pg_stat_wal;

-- WAL directory size:
SELECT count(*) AS wal_files,
       pg_size_pretty(sum(size)) AS total
FROM pg_ls_waldir();
```

### Beginner Trap: Checkpoint Warnings in Logs
**Explanation:** A common beginner trap: setting max_wal_size too small and seeing checkpoint warnings in the logs. If you see 'checkpoints are occurring too frequently', increase max_wal_size. Also, do not set synchronous_commit to off globally thinking it is just a performance tweak — understand the data loss window first.

```sql
postgres=# -- You see this in PostgreSQL logs:
postgres=# -- LOG: checkpoints are occurring too frequently
postgres=# --      (14 seconds apart)
postgres=# -- HINT: Consider increasing the configuration parameter
postgres=# --       "max_wal_size".
postgres=# -- This means:
postgres=# -- WAL is filling up faster than max_wal_size allows
postgres=# -- Checkpoints are being forced every 14 seconds
postgres=# -- Heavy I/O every 14 seconds = performance problems
postgres=# -- Fix:
postgres=# -- max_wal_size = '8GB'   (was 1GB)
postgres=# -- checkpoint_timeout = '15min'  (was 5min)
postgres=# -- Verify fix by checking pg_stat_bgwriter:
postgres=# -- checkpoints_req should stop growing rapidly
postgres=# -- Also check:
postgres=# -- If checkpoints_req > checkpoints_timed
postgres=# -- → WAL-triggered checkpoints dominate → increase max_wal_size
postgres=# -- If checkpoints_timed > checkpoints_req
postgres=# -- → Timeout checkpoints dominate → settings are good
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf — Checkpoint Configuration` — Checkpoint Timing Parameters
checkpoint_timeout is the other checkpoint trigger — maximum time between checkpoints. The default is 5 minutes. On production, increase it to 15 or 30 minutes. Combined with a larger max_wal_size, this dramatically reduces checkpoint frequency. You can apply these parameters without downtime by executing SELECT pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `max_wal_size` | `8GB` | `[RELOAD]` (Live Reload `SIGHUP`) | Trigger checkpoint after this much WAL (default 1GB) (Default: 1GB) |
| `min_wal_size` | `1GB` | `[RELOAD]` (Live Reload `SIGHUP`) | Keep at least this much WAL on disk (default 80MB) (Default: 80MB) |
| `checkpoint_timeout` | `15min` | `[RELOAD]` (Live Reload `SIGHUP`) | Max time between checkpoints (default 5min) (Default: 5min) |
| `checkpoint_completion_target` | `0.9` | `[RELOAD]` (Live Reload `SIGHUP`) | Spread checkpoint over 90% of the interval (default 0.9) (Default: 0.9) |
| `checkpoint_warning` | `30s` | `[SETTING]` | Log a warning if checkpoints happen more often than this |


### File: `postgresql.conf — Background Writer` — Background Writer Configuration
The background writer works alongside checkpoints to keep shared_buffers clean. It continuously writes dirty pages to disk between checkpoints, reducing the amount of work the checkpoint process has to do. If backends have to write dirty pages themselves — shown by high buffers_backend — it means both the background writer and checkpoints are not keeping up.

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `bgwriter_delay` | `200ms` | `[SETTING]` | How often the background writer runs (default 200ms) |
| `bgwriter_lru_maxpages` | `100` | `[SETTING]` | Max pages written per round (default 100) |
| `bgwriter_lru_multiplier` | `2.0` | `[SETTING]` | Pages to write = multiplier × recent demand (default 2.0) |
| `bgwriter_flush_after` | `512kB` | `[SETTING]` | Force OS flush after this many bytes (controls OS write cache) |


### File: `postgresql.conf — Production WAL Settings` — Complete WAL & Checkpoint Config — 32GB Server
Here is the complete WAL and checkpoint configuration for a 32 GB production server. These settings work well for OLTP workloads with moderate write activity. Remember: parameters requiring a RESTART must have PostgreSQL restarted before changes take effect. Parameters requiring a RELOAD can be applied live with pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `wal_buffers` | `-1 (auto: 64MB)` | **`[RESTART]`** (Postmaster Restart) | Auto-calculated from shared_buffers — usually fine (Default: -1) |
| `max_wal_size` | `8GB` | `[RELOAD]` (Live Reload `SIGHUP`) | Reduce checkpoint frequency for write-heavy workloads (Default: 1GB) |
| `min_wal_size` | `1GB` | `[RELOAD]` (Live Reload `SIGHUP`) | Keep WAL files pre-allocated for reuse (Default: 80MB) |
| `checkpoint_timeout` | `15min` | `[RELOAD]` (Live Reload `SIGHUP`) | Max interval between checkpoints (Default: 5min) |
| `checkpoint_completion_target` | `0.9` | `[RELOAD]` (Live Reload `SIGHUP`) | Spread checkpoint I/O over 90% of interval (Default: 0.9) |
| `wal_compression` | `zstd` | `[SETTING]` | Compress full-page writes (30-50% WAL reduction) |
| `wal_level` | `replica` | **`[RESTART]`** (Postmaster Restart) | Default — supports streaming replication and PITR (Default: replica) |
| `full_page_writes` | `on` | `[SETTING]` | NEVER disable unless on ZFS or battery-backed RAID |
| `synchronous_commit` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | Default — set off per-session for non-critical writes (Default: on) |



---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Checkpoint Warnings in Logs
A common beginner trap: setting max_wal_size too small and seeing checkpoint warnings in the logs. If you see 'checkpoints are occurring too frequently', increase max_wal_size. Also, do not set synchronous_commit to off globally thinking it is just a performance tweak — understand the data loss window first.

```sql
-- You see this in PostgreSQL logs:
-- LOG: checkpoints are occurring too frequently
--      (14 seconds apart)
-- HINT: Consider increasing the configuration parameter
--       "max_wal_size".
-- This means:
-- WAL is filling up faster than max_wal_size allows
-- Checkpoints are being forced every 14 seconds
-- Heavy I/O every 14 seconds = performance problems
-- Fix:
-- max_wal_size = '8GB'   (was 1GB)
-- checkpoint_timeout = '15min'  (was 5min)
-- Verify fix by checking pg_stat_bgwriter:
-- checkpoints_req should stop growing rapidly
-- Also check:
-- If checkpoints_req > checkpoints_timed
-- → WAL-triggered checkpoints dominate → increase max_wal_size
-- If checkpoints_timed > checkpoints_req
-- → Timeout checkpoints dominate → settings are good
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. max_wal_size controls checkpoint frequency by WAL volume — increase it from the default 1GB to 4-16GB for production. checkpoint_timeout sets the maximum interval — 15 to 30 minutes is typical. checkpoint_completion_target of 0.9 spreads I/O smoothly. wal_compression reduces WAL by 30-50% with minimal CPU. synchronous_commit can be set to off per-session for non-critical writes. Never disable full_page_writes. Monitor with pg_stat_bgwriter and pg_stat_wal. In the next class, we tune connections and disk I/O.

- **max_wal_size: 4-16GB (default 1GB is too small for production)**
- **checkpoint_timeout: 15-30min (default 5min is too frequent)**
- **checkpoint_completion_target: 0.9 (spread I/O over 90% of interval)**
- **wal_compression: zstd (reduce WAL volume by 30-50%)**
- **wal_buffers: auto (-1) is usually correct**
- **full_page_writes: ALWAYS on (protects against torn pages)**
- **synchronous_commit: on globally, off per-session for logs/metrics**
- **Monitor: pg_stat_bgwriter (checkpoints_req vs checkpoints_timed)**
- **Monitor: pg_stat_wal (wal_buffers_full, wal_bytes)**
- **High buffers_backend = shared_buffers or bgwriter too small**
- **Next: Connection & Disk I/O Tuning**


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
