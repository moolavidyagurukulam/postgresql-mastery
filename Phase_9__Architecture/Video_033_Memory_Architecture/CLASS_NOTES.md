# Memory Architecture — Shared Buffers, work_mem & Beyond
**Series:** PostgreSQL Mastery | **Phase:** Phase 9: Architecture | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we learn how PostgreSQL uses memory — shared memory that all processes access together, and private memory that each backend uses on its own. We will understand shared_buffers, work_mem, maintenance_work_mem, and how to check your buffer cache hit ratio. Let us dive in.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should understand the process architecture from the previous class — postmaster, backends, and background workers. We learned that each connection gets its own backend process. Now we learn how those processes use memory. There are two main areas: shared memory that EVERY process can access, and private memory that belongs to just ONE backend. Getting memory settings right is one of the most impactful performance optimizations you can make.

- You know the process architecture: postmaster + backends
- Each connection = one backend process
- Previous class: processes and connections
- This class: HOW those processes use memory
- Two areas: shared memory and per-backend memory
- Getting this right = huge performance impact

### PostgreSQL Memory Layout
PostgreSQL memory is divided into two parts. Shared memory is allocated once when the server starts. ALL processes — backends and background workers — read from and write to this shared area. The biggest piece is shared_buffers — the buffer cache where data pages live in RAM. Per-backend memory is private to each connection. The main settings are work_mem for sorts and hashes, and temp_buffers for temporary tables.

```
[Shared Memory]
[shared_buffers
(Buffer Cache)]
[WAL Buffers
(wal_buffers)]
[CLOG
Buffers]
[Per-Backend Memory (× N connections)]
[work_mem
(sorts, hashes)]
[maintenance_work_mem
(VACUUM, INDEX)]
[temp_buffers
(temp tables)]
```

### shared_buffers — The Buffer Cache
shared_buffers is the most important memory setting. It is PostgreSQL's buffer cache — a RAM cache for data pages read from disk. When a query needs a page, PostgreSQL checks shared_buffers FIRST. If the page is there — a cache hit — no disk read needed. If it is not there — a cache miss — PostgreSQL reads it from disk and stores it in shared_buffers for next time. The default is only one hundred twenty-eight megabytes, which is far too small for production. The general recommendation is twenty-five percent of total system RAM.

| Term | Meaning / Explanation |
| :--- | :--- |
| **What** | RAM cache for data pages (8 KB each) |
| **Default** | 128 MB (way too small for production!) |
| **Recommendation** | 25% of total RAM (e.g., 4 GB on 16 GB server) |
| **Cache Hit** | Page found in buffers → no disk I/O (fast!) |
| **Cache Miss** | Page not in buffers → read from disk (slow) |

**Notes:**
- Set in postgresql.conf, requires restart to change

### work_mem — Per-Operation Sort/Hash Memory
work_mem is the memory each OPERATION — not each connection — uses for sorting and hashing. If a query has two sorts and a hash join, it uses up to three times work_mem. The default is four megabytes. If you have one hundred connections and each runs a query with three sort operations, that is one hundred times three times four equals one point two gigabytes. Be careful when increasing work_mem — it multiplies fast.

| Term | Meaning / Explanation |
| :--- | :--- |
| **What** | Memory for sorting (ORDER BY) and hashing (JOIN, GROUP BY) |
| **Default** | 4 MB per operation |
| **Per Operation** | NOT per connection! A query with 3 sorts uses 3 × work_mem |
| **Too Small** | Sorts spill to disk temp files (very slow) |
| **Too Large** | 100 connections × 3 sorts × 64MB = 19 GB! |

**Notes:**
- Can be set per-session: SET work_mem = '64MB';
- Reset after: RESET work_mem;

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. You can download today's class materials and practice files from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Every bit helps us keep creating. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Memory Sizing Guide
Here are the production memory recommendations for different server sizes. These are starting points — you should monitor and adjust based on your workload. The key principle: give shared_buffers about twenty-five percent of RAM, leave the rest for the OS file cache and connections. Do not set shared_buffers to more than about forty percent of RAM — the OS needs memory for its own file cache, which PostgreSQL also benefits from.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here are the production memory recommendations for different server sizes |
| **These are starting points** | you should monitor and adjust based on your workload |
| **The key principle** | give shared_buffers about twenty-five percent of RAM, leave the rest for the OS file cache and connections |
| **Point 4** | Do not set shared_buffers to more than about forty percent of RAM — the OS needs memory for its own file cache, which PostgreSQL also benefits from |

### Detecting Memory Pressure
How do you know if work_mem is too small? If PostgreSQL runs out of work_mem during a sort or hash, it spills to disk — writing temporary files. You can detect this with EXPLAIN ANALYZE which shows Sort Method: external merge if it spilled. You can also check log_temp_files in postgresql.conf to log whenever temp files are created. If you see frequent temp file usage, increase work_mem.

| Signs of Too Little work_mem | Signs of Too Little shared_buffers |
| :--- | :--- |
| EXPLAIN shows 'Sort Method: external merge' | Cache hit ratio below 95% |
| Temp files in pg_stat_database | High blks_read in pg_stat_database |
| Slow sorts and hash joins | Slow sequential scans on hot tables |
| log_temp_files shows frequent entries | OS shows high disk I/O on data dir |

### Beginner Trap: shared_buffers Too High!
Beginner trap: setting shared_buffers too high — above forty percent of RAM — actually hurts performance. PostgreSQL relies on the operating system file cache to cache pages that do not fit in shared_buffers. If you give shared_buffers eighty percent of RAM, the OS has almost no memory left for its own cache, and reads that miss shared_buffers become slow disk reads instead of fast OS cache reads. The sweet spot is twenty-five percent. On Windows, keep it even lower — around fifteen percent — because Windows memory management handles large shared memory regions less efficiently.

| Good: 25% of RAM | Bad: 80% of RAM |
| :--- | :--- |
| shared_buffers = 4 GB (on 16 GB server) | shared_buffers = 13 GB (on 16 GB server) |
| OS file cache gets ~8 GB | OS file cache gets ~1 GB |
| Double caching: PG cache + OS cache | Reads missing shared_buffers → disk (SLOW) |
| Reads missing shared_buffers → OS cache (fast) | OS may start swapping → disaster |
| Total effective cache: 12+ GB | Total effective cache: ~13 GB but slower |

### Memory Tuning Decision Framework
Here is the decision framework for memory tuning. Start with the defaults, measure your cache hit ratio and temp file usage, then adjust. Change ONE setting at a time and measure. shared_buffers requires a restart — plan for that. work_mem can be changed per session for testing. Always leave at least fifty percent of RAM for the OS — it needs memory for the file cache, kernel, and other processes.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Start with the defaults** | measure your cache hit ratio and temp file usage, then adjust |
| **Point 2** | Change ONE setting at a time and measure |
| **Point 3** | shared_buffers requires a restart — plan for that |
| **Point 4** | work_mem can be changed per session for testing |
| **Point 5** | Always leave at least fifty percent of RAM for the OS — it needs memory for the file cache, kernel, and other processes |

### Practice Exercises
Time to practice. Check all your memory settings, calculate the buffer hit ratio, temporarily increase work_mem, and check for temp file usage. These diagnostic queries are essential for production tuning.

- 1. SHOW shared_buffers, work_mem, maintenance_work_mem
- 2. Calculate buffer cache hit ratio from pg_stat_database
- 3. SET work_mem = '64MB'; run a sort query; RESET
- 4. Check temp file usage: SELECT temp_files FROM pg_stat_database
- 5. Check total memory: SELECT pg_size_pretty(sum(setting::BIGINT * 8192)) FROM pg_settings WHERE name = 'shared_buffers'
- 6. Compare memory sizing to your server's total RAM
- 7. EXPLAIN (ANALYZE, BUFFERS) a query — look for buffer hits vs reads


---

## 3. Hands-On Commands & psql Output

### Check Memory Settings and Cache Hit Ratio
**Explanation:** Let us check the current memory settings and the buffer cache hit ratio. The hit ratio tells you what percentage of reads come from the cache versus disk. You want this above ninety-nine percent for OLTP workloads. If it is below ninety-five percent, you probably need more shared_buffers or more RAM.

```sql
-- Current shared_buffers setting
practice=# SHOW shared_buffers;
 shared_buffers
----------------
 128MB

-- Buffer cache hit ratio (should be > 99%)
practice=# SELECT
  ROUND(blks_hit * 100.0 / NULLIF(blks_hit + blks_read, 0), 2)
    AS cache_hit_pct
FROM pg_stat_database WHERE datname = 'practice';
 cache_hit_pct
---------------
         99.85

-- 99.85% = excellent! Most reads come from RAM
-- Below 95%? Increase shared_buffers or add RAM
```

### Memory Settings — Check All Key Parameters
**Explanation:** maintenance_work_mem is separate — used for maintenance operations like VACUUM, CREATE INDEX, and ALTER TABLE ADD FOREIGN KEY. These operations typically run one at a time, so you can set this much higher than work_mem. The default is sixty-four megabytes. For production with large tables, two hundred fifty-six megabytes to one gigabyte is common. Higher values make VACUUM and index creation much faster.

```sql
practice=# SHOW work_mem;
 work_mem
----------
 4MB

practice=# SHOW maintenance_work_mem;
 maintenance_work_mem
----------------------
 64MB

practice=# SHOW temp_buffers;
 temp_buffers
--------------
 8MB

practice=# SHOW wal_buffers;
 wal_buffers
-------------
 4MB

-- work_mem: per sort/hash operation (careful scaling)
-- maintenance_work_mem: for VACUUM, CREATE INDEX (set higher)
-- temp_buffers: for temp tables (per session)
-- wal_buffers: WAL write buffer (auto-tuned usually)
```

### Set work_mem Per Session
**Explanation:** You can temporarily change work_mem for a single session. This is useful when you have one complex query that needs more sort memory, but you do not want to increase it for ALL connections. SET work_mem only affects your current session. After the query, RESET work_mem to go back to the default. This is a common production technique.

```sql
-- Temporarily increase work_mem for a big query
practice=# SET work_mem = '256MB';
SET

practice=# SHOW work_mem;
 work_mem
----------
 256MB

-- Run your big query here...
-- Then reset back to default
practice=# RESET work_mem;
RESET
practice=# SHOW work_mem;
 work_mem
----------
 4MB

-- SET only affects YOUR session, not others
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: shared_buffers Too High!
Beginner trap: setting shared_buffers too high — above forty percent of RAM — actually hurts performance. PostgreSQL relies on the operating system file cache to cache pages that do not fit in shared_buffers. If you give shared_buffers eighty percent of RAM, the OS has almost no memory left for its own cache, and reads that miss shared_buffers become slow disk reads instead of fast OS cache reads. The sweet spot is twenty-five percent. On Windows, keep it even lower — around fifteen percent — because Windows memory management handles large shared memory regions less efficiently.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap. PostgreSQL memory is split into shared memory — shared_buffers, WAL buffers, CLOG — and per-backend memory — work_mem, maintenance_work_mem, temp_buffers. shared_buffers is the buffer cache: set it to about twenty-five percent of RAM, never more than forty percent. work_mem is per OPERATION, not per connection — it multiplies with concurrent queries. maintenance_work_mem can be set higher because maintenance operations are infrequent. Monitor the cache hit ratio — it should be above ninety-nine percent. In the next class, we look at Storage Architecture — how PostgreSQL stores data on disk. See you there!

- **shared_buffers: buffer cache, ~25% of RAM, requires restart**
- **work_mem: per sort/hash operation, 4 MB default, careful scaling**
- **maintenance_work_mem: VACUUM/INDEX, set higher (256MB-2GB)**
- **temp_buffers: per-session temp table cache, 8 MB default**
- **wal_buffers: WAL write buffer, usually auto-tuned**
- **Cache hit ratio > 99% = healthy (check pg_stat_database)**
- **SET work_mem per session for big queries; RESET after**
- **EXPLAIN (ANALYZE, BUFFERS) shows cache hits vs disk reads**


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
