# Memory Tuning — shared_buffers, work_mem & More
**Series:** PostgreSQL Mastery | **Phase:** Phase 21: Performance Tuning | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! We now enter Phase 21 — Performance Tuning. In the previous phase, we learned to optimize individual queries. Now we configure PostgreSQL itself for maximum performance. This class covers memory tuning — the four most critical memory parameters that determine how PostgreSQL uses your server's RAM. Get these right and everything gets faster. Get them wrong and PostgreSQL either wastes memory or constantly reads from disk. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### The Four Memory Parameters
Imagine your database is a library. shared_buffers is the desk where you keep books you are currently reading — bigger desk, fewer trips to the shelf. work_mem is the scratch paper for each person working at the library — sorting notes, organizing results. maintenance_work_mem is the large table used for reorganizing entire shelves — VACUUM, CREATE INDEX, and other maintenance. effective_cache_size is not memory PostgreSQL uses — it tells the planner how much total cache exists including the operating system page cache.

| Term | Meaning / Explanation |
| :--- | :--- |
| **shared_buffers** | PostgreSQL's own page cache — data pages kept in RAM to avoid disk reads |
| **work_mem** | Memory per sort/hash operation — controls whether sorts spill to disk |
| **maintenance_work_mem** | Memory for maintenance: VACUUM, CREATE INDEX, ALTER TABLE ADD FK |
| **effective_cache_size** | Hint to planner: total expected cache (PG buffers + OS page cache) |

**Notes:**
- These four parameters have the biggest impact on PostgreSQL performance
- All can be set in postgresql.conf (some require restart, some do not)

### shared_buffers Sizing Guide
The rule of thumb: set shared_buffers to 25% of total system RAM. On a 32 GB server, that is 8 GB. On a 64 GB server, 16 GB. Going above 25% rarely helps because the operating system also caches data pages — the OS page cache and shared_buffers work together, and you do not want them competing for the same memory.

| Term | Meaning / Explanation |
| :--- | :--- |
| **The rule of thumb** | set shared_buffers to 25% of total system RAM |
| **Point 2** | On a 32 GB server, that is 8 GB |
| **Point 3** | On a 64 GB server, 16 GB |
| **Point 4** | Going above 25% rarely helps because the operating system also caches data pages — the OS page cache and shared_buffers work together, and you do not want them competing for the same memory |

### work_mem — In Memory vs Disk Spill
Now work_mem — memory allocated per sort or hash operation. When PostgreSQL sorts results for ORDER BY, or builds a hash table for a Hash Join, it uses work_mem. If the data fits within work_mem, the operation runs in memory — fast. If it exceeds work_mem, PostgreSQL spills to disk — dramatically slower. The default is only 4 megabytes.

| In Memory (Fast) | Disk Spill (Slow) |
| :--- | :--- |
| Sort Method: quicksort Memory: 2048kB | Sort Method: external merge Disk: 8192kB |
| Hash Batches: 1 Memory: 3072kB | Hash Batches: 4 Memory: 4096kB |
| Data fits in work_mem allocation | Data exceeds work_mem allocation |
| Operation runs entirely in RAM | Temp files written to disk |
| No temporary files created | 10-100x slower than in-memory |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Beginner Trap: shared_buffers Too High
Here is the common beginner trap: setting shared_buffers too high. If you set it to 80% of RAM, the operating system has almost no memory left for its own page cache. PostgreSQL then fights with the OS for memory, causing double caching and even swapping. Stay at 25% — the OS page cache handles the rest.

| The Wrong Way (80% of RAM) | The Right Way (25% of RAM) |
| :--- | :--- |
| shared_buffers = 26GB (on 32GB server) | shared_buffers = 8GB (on 32GB server) |
| Only 6GB left for OS + apps | 24GB left for OS + apps + page cache |
| OS page cache gets almost nothing | OS caches additional ~16GB of data files |
| Double caching: PG + OS cache same pages | Total effective cache: 8GB + 16GB = 24GB |
| Server starts swapping → catastrophic slowdown | No swapping, smooth performance |
| Counterintuitively SLOWER than 25% | Set effective_cache_size = 24GB |

### Memory Configuration by Server Size
Here is a decision framework for different server sizes. Scale the values proportionally — the ratios stay the same.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a decision framework for different server sizes |
| **Scale the values proportionally** | the ratios stay the same |


---

## 3. Hands-On Commands & psql Output

### Check shared_buffers & Cache Hit Ratio
**Explanation:** Here is how to check your current shared_buffers setting and measure your cache hit ratio. A hit ratio below 99% on a production server usually means shared_buffers is too small.

```sql
postgres=# -- Current shared_buffers:
postgres=# SHOW shared_buffers;
 shared_buffers
postgres=# ----------------
 128MB
postgres=# -- Cache hit ratio (should be > 99%):
SELECT
  datname,
  blks_hit,
  blks_read,
  ROUND(
    100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0), 2
  ) AS hit_ratio_pct
postgres-# FROM pg_stat_database
postgres-# WHERE datname = current_database();
  datname     | blks_hit | blks_read | hit_ratio_pct
postgres=# --------------+----------+-----------+--------------
 trigger_lab  | 4523891  |    45678  |        98.99
postgres=# -- 98.99% — close but below 99%
postgres=# -- With more shared_buffers, those 45,678 disk reads
postgres=# -- could become cache hits
```

### work_mem — Per Operation, Not Per Query!
**Explanation:** The critical detail about work_mem: it is per operation, not per query. A complex query with 5 sort nodes and 3 hash joins uses up to 8 times work_mem. And every connection can run queries simultaneously. So if you have 100 connections and set work_mem to 256 megabytes, the worst case is 100 connections times multiple operations — you could exceed your total RAM and the server starts swapping.

```sql
postgres=# -- Check current work_mem:
postgres=# SHOW work_mem;
 work_mem
postgres=# ----------
 4MB
postgres=# -- A query with 3 sort operations uses 3 × work_mem:
postgres=# EXPLAIN ANALYZE
postgres=# SELECT * FROM orders o
postgres-# JOIN customers c ON o.customer_id = c.id
postgres-# WHERE o.status = 'pending'
postgres-# ORDER BY o.amount DESC;
postgres=# -- This plan might have:
postgres=# -- 1 Hash Join (uses work_mem)       = 4MB
postgres=# -- 1 Sort for ORDER BY (uses work_mem) = 4MB
postgres=# -- Total for ONE query: up to 8MB
postgres=# -- With 100 connections:
postgres=# -- Worst case: 100 × 8MB = 800MB
postgres=# -- DANGER: SET work_mem = '256MB' globally
postgres=# -- 100 connections × 2 operations × 256MB = 51.2 GB!
postgres=# -- Never set work_mem too high globally
```

### work_mem — Safe Global + Per-Session Strategy
**Explanation:** The safe approach: set work_mem conservatively in postgresql.conf — 16 to 64 megabytes for most servers. Then increase it per-session for known heavy queries like reports, batch jobs, or data exports.

```sql
postgres=# -- Global setting (postgresql.conf) — conservative:
postgres=# -- work_mem = '32MB'
postgres=# -- For a reporting session that needs more:
postgres=# SET work_mem = '256MB';
postgres=# EXPLAIN ANALYZE
postgres=# SELECT customer_id, SUM(amount)
postgres-# FROM orders
postgres-# GROUP BY customer_id
postgres-# ORDER BY sum DESC;
postgres=# -- Sort Method: quicksort Memory: 1024kB  ← in memory!
postgres=# -- Reset after the heavy query:
RESET work_mem;
postgres=# -- For a single transaction only:
postgres=# SET LOCAL work_mem = '256MB';
postgres=# -- Automatically resets when transaction ends
postgres=# -- Formula for global work_mem:
postgres=# -- (Total RAM - shared_buffers) / (max_connections × 3)
postgres=# -- 32GB server: (32GB - 8GB) / (100 × 3) ≈ 80MB
postgres=# -- Be conservative: set to 32-64MB globally
```

### Detecting Disk Spills — Temp File Monitoring
**Explanation:** How to find if work_mem is too low? Check for temporary file usage in pg_stat_database. If temp_bytes is growing, queries are spilling sorts and hashes to disk.

```sql
postgres=# -- Check temporary file usage:
postgres=# SELECT datname,
       temp_files,
       pg_size_pretty(temp_bytes) AS temp_size
postgres-# FROM pg_stat_database
postgres-# WHERE temp_bytes > 0;
  datname     | temp_files | temp_size
postgres=# --------------+------------+----------
 trigger_lab  |       234  | 1456 MB
postgres=# -- 234 temp files totaling 1.4 GB — sorts are spilling!
postgres=# -- Log temporary files for investigation:
postgres=# -- postgresql.conf:
postgres=# -- log_temp_files = 0
postgres=# -- (logs ALL temp file usage — set to e.g. 10240 for >10MB only)
postgres=# -- After enabling, check logs:
postgres=# -- LOG: temporary file: path "base/pgsql_tmp/pgsql_tmp12345.0",
postgres=# --      size 52428800
postgres=# -- This tells you which queries are spilling and how much
```

### maintenance_work_mem — Faster VACUUM & CREATE INDEX
**Explanation:** Now maintenance_work_mem — memory used by VACUUM, CREATE INDEX, ALTER TABLE ADD FOREIGN KEY, and CLUSTER. These operations are single-threaded and run one at a time, so you can safely give them much more memory than work_mem. The default is 64 megabytes. For production, set it to 1 to 2 gigabytes.

```sql
postgres=# -- Check current maintenance_work_mem:
postgres=# SHOW maintenance_work_mem;
 maintenance_work_mem
postgres=# ----------------------
 64MB
postgres=# -- With 64MB, creating an index on 50M rows is slow:
postgres=# -- CREATE INDEX takes ~45 seconds (multiple passes, disk spills)
postgres=# -- Increase to 2GB:
postgres=# -- postgresql.conf:
postgres=# -- maintenance_work_mem = '2GB'
postgres=# -- Or per-session for a one-time operation:
postgres=# SET maintenance_work_mem = '2GB';
postgres=# CREATE INDEX idx_orders_amount ON orders(amount);
postgres=# -- Now takes ~8 seconds (single pass, in memory)
RESET maintenance_work_mem;
postgres=# -- Also speeds up:
postgres=# -- VACUUM (can process more dead tuples per pass)
postgres=# -- ALTER TABLE ADD FOREIGN KEY (sorts the FK column)
postgres=# -- CLUSTER (sorts and rewrites the entire table)
```

### effective_cache_size — Planner Hint, Not Allocation
**Explanation:** Now effective_cache_size — this is NOT memory that PostgreSQL allocates. It is a hint to the query planner about how much total cache is available, including both shared_buffers and the operating system's page cache. Setting it too low makes the planner pessimistic about cache hits, causing it to avoid index scans when it should use them.

```sql
postgres=# -- Check current setting:
postgres=# SHOW effective_cache_size;
 effective_cache_size
postgres=# ----------------------
 4GB
postgres=# -- This tells the planner: 'about 4GB of data
postgres=# -- is likely already cached in RAM'
postgres=# -- On a 32GB server with shared_buffers = 8GB:
postgres=# -- OS usually caches another ~16GB of file data
postgres=# -- Set effective_cache_size = 8GB + 16GB = 24GB
postgres=# -- Rule of thumb:
postgres=# -- effective_cache_size = 50-75% of total RAM
postgres=# -- 32GB server → 24GB (75%)
postgres=# -- This does NOT reserve or allocate any memory!
postgres=# -- Impact on planner:
postgres=# -- Too low: planner avoids index scans (thinks random I/O is expensive)
postgres=# -- Too high: planner may over-rely on caching (plans that need cached data)
postgres=# -- Correct: planner makes realistic I/O cost estimates
```

### effective_cache_size Impact on Planner Decisions
**Explanation:** Let me show you the impact of effective_cache_size on the planner. With a low value, the planner prefers sequential scans because it assumes random I/O is expensive. With a correct value, it uses index scans where appropriate.

```sql
postgres=# -- With low effective_cache_size:
postgres=# SET effective_cache_size = '128MB';
EXPLAIN
postgres=# SELECT * FROM orders WHERE customer_id = 42;
 Seq Scan on orders  (cost=0.00..1459.00 rows=50 width=32)
   Filter: (customer_id = 42)
postgres=# -- Planner thinks: 'RAM is small, random I/O costly → scan all'
postgres=# -- With correct effective_cache_size:
postgres=# SET effective_cache_size = '24GB';
EXPLAIN
postgres=# SELECT * FROM orders WHERE customer_id = 42;
 Index Scan using idx_orders_customer_id on orders
   (cost=0.29..10.75 rows=50 width=32)
postgres=# -- Planner thinks: 'index pages are likely cached → index scan cheap'
RESET effective_cache_size;
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf — Memory Configuration` — Setting shared_buffers
Changing shared_buffers requires a PostgreSQL restart. Here is the exact process. Edit postgresql.conf, set the value, and restart the server. Then verify the new setting.

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `shared_buffers` | `8GB` | **`[RESTART]`** (Postmaster Restart) | 25% of 32GB RAM — requires server RESTART (Default: 128MB) |
| `# Verify after restart:` | `SHOW shared_buffers;` | `[SETTING]` | Must show new value (8GB) |
| `# On Windows:` | `Restart the postgresql-x64-16 service` | `[SETTING]` | Services > postgresql-x64-16 > Restart |
| `# On Linux:` | `sudo systemctl restart postgresql` | `[SETTING]` | Or: pg_ctl restart -D $PGDATA |


### File: `postgresql.conf — Autovacuum Memory` — autovacuum_work_mem — Separate from maintenance_work_mem
There is also autovacuum_work_mem — separate from maintenance_work_mem. If not set, autovacuum uses maintenance_work_mem. On servers where you set maintenance_work_mem very high for manual operations, you might want autovacuum_work_mem lower to prevent all autovacuum workers from using too much memory. Remember: parameters requiring a RESTART must have PostgreSQL restarted before changes take effect. Parameters requiring a RELOAD can be applied live with pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `maintenance_work_mem` | `2GB` | `[RELOAD]` (Live Reload `SIGHUP`) | For manual VACUUM, CREATE INDEX, ALTER TABLE (Default: 64MB) |
| `autovacuum_work_mem` | `512MB` | `[RELOAD]` (Live Reload `SIGHUP`) | Per autovacuum worker (default: -1 = use maintenance_work_mem) (Default: -1) |
| `autovacuum_max_workers` | `3` | **`[RESTART]`** (Postmaster Restart) | Max simultaneous autovacuum workers (default 3) (Default: 3) |
| `# Memory calculation:` | `3 workers × 512MB = 1.5GB` | `[SETTING]` | Total autovacuum memory — keep this under control |


### File: `postgresql.conf — Other Memory Settings` — Additional Memory Parameters
Two more memory parameters worth knowing: temp_buffers for temporary tables, and huge_pages for using operating system huge pages which reduce memory management overhead on large shared_buffers. Remember: parameters requiring a RESTART must have PostgreSQL restarted before changes take effect. Parameters requiring a RELOAD can be applied live with pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `temp_buffers` | `32MB` | `[SESSION]` (Per Connection) | Per-session cache for temporary tables (default 8MB) (Default: 8MB) |
| `huge_pages` | `try` | **`[RESTART]`** (Postmaster Restart) | Use huge pages if available (2MB pages vs 4KB — less TLB overhead) (Default: try) |
| `# huge_pages values:` | `off | try | on` | `[SETTING]` | 'try' = use if OS supports it, fall back to normal pages if not |
| `# When huge_pages matters:` | `shared_buffers >= 8GB` | `[SETTING]` | With 8GB buffers: 2M normal pages vs 4K huge pages — significant TLB savings |


### File: `postgresql.conf — Production Memory Settings` — Complete Memory Configuration — 32GB Server
Here is the complete memory configuration for a 32 GB production server. This is a solid starting point — monitor and adjust based on your workload. Remember: parameters requiring a RESTART must have PostgreSQL restarted before changes take effect. Parameters requiring a RELOAD can be applied live with pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `shared_buffers` | `8GB` | **`[RESTART]`** (Postmaster Restart) | 25% of 32GB — REQUIRES RESTART (Default: 128MB) |
| `effective_cache_size` | `24GB` | `[RELOAD]` (Live Reload `SIGHUP`) | 75% of 32GB — planner hint only, no restart needed (Default: 4GB) |
| `work_mem` | `32MB` | `[RELOAD]` (Live Reload `SIGHUP`) | Conservative global — increase per-session for reports (Default: 4MB) |
| `maintenance_work_mem` | `2GB` | `[RELOAD]` (Live Reload `SIGHUP`) | Fast VACUUM and CREATE INDEX (Default: 64MB) |
| `autovacuum_work_mem` | `512MB` | `[RELOAD]` (Live Reload `SIGHUP`) | Per autovacuum worker (3 workers = 1.5GB) (Default: -1) |
| `temp_buffers` | `32MB` | `[SESSION]` (Per Connection) | Per-session temp table cache (Default: 8MB) |
| `huge_pages` | `try` | **`[RESTART]`** (Postmaster Restart) | Use huge pages if OS supports them (Default: try) |



---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: shared_buffers Too High
Here is the common beginner trap: setting shared_buffers too high. If you set it to 80% of RAM, the operating system has almost no memory left for its own page cache. PostgreSQL then fights with the OS for memory, causing double caching and even swapping. Stay at 25% — the OS page cache handles the rest.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. shared_buffers is the most important parameter — set it to 25% of RAM and never above 40%. work_mem controls per-operation sort and hash memory — set it conservatively globally and increase per-session for heavy queries. maintenance_work_mem speeds up VACUUM and CREATE INDEX — set it high because maintenance runs single-threaded. effective_cache_size is just a planner hint — set it to 50 to 75% of RAM. Monitor your cache hit ratio and temp file usage to validate your settings. In the next class, we tune WAL and checkpoints.

- **shared_buffers = 25% of RAM (requires restart)**
- **Cache hit ratio should be > 99% (pg_stat_database)**
- **work_mem = per sort/hash operation (NOT per query!)**
- **Set work_mem conservative globally, high per-session**
- **maintenance_work_mem = 1-2GB for fast VACUUM/CREATE INDEX**
- **autovacuum_work_mem = separate from maintenance_work_mem**
- **effective_cache_size = 50-75% of RAM (planner hint only)**
- **Too-high shared_buffers causes double caching + swapping**
- **Monitor: pg_stat_database (hit ratio, temp files)**
- **huge_pages = try (reduces TLB overhead for large buffers)**
- **Next: WAL & Checkpoint Tuning**


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
