# RTO, RPO & Backup Overview
**Series:** PostgreSQL Mastery | **Phase:** Phase 18: Backup, Recovery & Disaster Recovery | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! We are entering the most critical phase of the entire course — Backup, Recovery, and Disaster Recovery. This is the difference between sleeping well at night and getting a 3 AM phone call that your company's data is gone forever. In this class, we cover two foundational concepts: RTO and RPO — the numbers that drive every backup decision you will ever make. Then we survey all the backup methods PostgreSQL offers. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### RTO & RPO — The Two Numbers That Matter
Imagine your database server dies at 2 PM on a Tuesday. The CEO asks two questions. First: when will we be back online? That is your Recovery Time Objective — RTO. Second: how much data did we lose? That is your Recovery Point Objective — RPO. Everything in this phase — every tool, every config, every decision — exists to meet these two numbers.

| Term | Meaning / Explanation |
| :--- | :--- |
| **RTO (Recovery Time Objective)** | Maximum acceptable DOWNTIME — how long until the system is back online |
| **RPO (Recovery Point Objective)** | Maximum acceptable DATA LOSS — how far back is the most recent usable backup |
| **Example: RTO = 1 hour** | System must be restored and serving traffic within 60 minutes |
| **Example: RPO = 5 minutes** | At most 5 minutes of recent transactions can be lost |

**Notes:**
- Lower RTO/RPO = more expensive (faster hardware, more frequent backups)
- Business decides these numbers, not the DBA

### RTO/RPO by Business Type
Here are real-world RTO and RPO targets for different types of businesses. A personal blog might tolerate 24 hours of downtime and a day of data loss. An e-commerce site needs to be back in an hour with at most 5 minutes of lost orders. A bank or hospital? Near-zero for both — every second of downtime and every lost transaction is a disaster. Your backup strategy must match your business requirements.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Here are real** | world RTO and RPO targets for different types of businesses |
| **Point 2** | A personal blog might tolerate 24 hours of downtime and a day of data loss |
| **An e** | commerce site needs to be back in an hour with at most 5 minutes of lost orders |
| **Near** | zero for both — every second of downtime and every lost transaction is a disaster |
| **Point 5** | Your backup strategy must match your business requirements |

### Three Backup Categories
Now let us understand the backup methods PostgreSQL offers. There are three categories. Logical backups use pg_dump and pg_dumpall — they export SQL statements that recreate your data. Physical backups use pg_basebackup — they copy the raw data files. And filesystem snapshots use your OS or cloud provider to snapshot the entire disk. Each has trade-offs in speed, flexibility, and what recovery scenarios they support.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Logical (pg_dump)** | Exports SQL — portable, selective, slow for large DBs, no PITR |
| **Physical (pg_basebackup)** | Copies raw data files — fast, supports PITR with WAL, not selective |
| **Filesystem Snapshot** | OS/cloud disk snapshot — fastest, requires consistent state or WAL archiving |

**Notes:**
- Production databases typically use BOTH logical AND physical backups
- Logical for portability + selective restore, physical for speed + PITR

### Backup Methods Compared
Let us compare these backup methods side by side. This table shows what each method can and cannot do. The key difference is Point-in-Time Recovery — only physical backups combined with WAL archiving can restore to any specific moment. Logical backups restore to whenever the dump was taken, nothing in between.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | This table shows what each method can and cannot do |
| **The key difference is Point** | in-Time Recovery — only physical backups combined with WAL archiving can restore to any specific moment |
| **Point 3** | Logical backups restore to whenever the dump was taken, nothing in between |

### Without vs With WAL Archiving
WAL archiving is the key to Point-in-Time Recovery. Normally, PostgreSQL recycles old WAL files once they are checkpointed. But with archive_mode turned on, PostgreSQL copies each WAL file to an archive location before recycling. Combined with a base backup, these archived WAL files let you replay changes up to any specific timestamp. This is PITR — the gold standard of PostgreSQL recovery.

| Without Archiving | With WAL Archiving |
| :--- | :--- |
| WAL files recycled after checkpoint | WAL files copied to archive |
| Crash recovery: last checkpoint only | Base backup + WAL = any point in time |
| pg_dump restores to dump time only | PITR: restore to exact timestamp |
| Data between dumps is LOST | RPO ≈ 0 (only uncommitted txns lost) |
| RPO = time since last pg_dump | Gold standard for production |

### Choosing Your Backup Strategy
Here is the decision framework for choosing your backup strategy. Start with your RTO and RPO requirements, then pick the simplest strategy that meets them. Do not over-engineer — a blog does not need synchronous replication. And do not under-engineer — an e-commerce database should never rely on just a nightly pg_dump.

- 1 -- Ask the business: how long can we be down? How much data can we lose?
- 2 -- Simple, portable. Cron job + pg_dump to compressed file
- 3 -- Hourly logical dumps + weekly physical base backup
- 4 -- pg_basebackup + continuous WAL archiving (pgBackRest/Barman)
- 5 -- Hot standby + WAL archiving. Failover in seconds.
- 6 -- A backup you have not tested is not a backup. Schedule monthly DR drills.

### Beginner Trap: Untested Backups
The most dangerous beginner trap in backups: never testing your restore. Many teams run pg_dump every night for years and feel safe. Then the server dies, they try to restore, and discover the dump file is corrupted, or the restore takes 12 hours instead of the 1 hour they promised. A backup you have never restored is just a file — you do not know if it works. Test your restores regularly. This is non-negotiable in production.

| False Sense of Security | What You Should Do |
| :--- | :--- |
| pg_dump runs every night ✓ | Monthly: restore to test server |
| Backup file exists on disk ✓ | Verify data integrity after restore |
| Cron job never failed ✓ | Time the restore process (measure RTO) |
| Never actually restored... ✗ | Check backup file checksums |
| Restore takes 12 hours... ✗ | Document the restore steps |
| File corrupted silently... ✗ | Practice until it is routine |

### Support & Materials
If you are enjoying this course, please consider supporting it. You can donate through PayPal or UPI — the links are in the description. Every contribution helps keep this course free and growing. You can also download the class materials from GitHub — the link is in the description too. Now let us summarize.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Practice Exercises
Time to practice. First, define the RTO and RPO for a project you are working on or a hypothetical application. Second, decide which backup category fits those requirements — logical, physical, or both. Third, check your current PostgreSQL WAL settings: SHOW wal_level and SHOW archive_mode. Fourth, list the backup tools we will cover in the upcoming classes: pg_dump, pg_restore, pg_basebackup, pgBackRest, Barman, and WAL-G.

- 1 -- Pick an app: how long can it be down? How much data loss is acceptable?
- 2 -- Match your RTO/RPO to logical, physical, or both
- 3 -- SHOW wal_level; SHOW archive_mode; SHOW archive_command;
- 4 -- pg_dump → logical, pg_basebackup → physical, pgBackRest/Barman/WAL-G → enterprise


---

## 3. Hands-On Commands & psql Output

*(Refer to the attached `materials.sql` script for full runnable queries and setups for this topic.)*


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Untested Backups
The most dangerous beginner trap in backups: never testing your restore. Many teams run pg_dump every night for years and feel safe. Then the server dies, they try to restore, and discover the dump file is corrupted, or the restore takes 12 hours instead of the 1 hour they promised. A backup you have never restored is just a file — you do not know if it works. Test your restores regularly. This is non-negotiable in production.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review. RTO is maximum downtime — how fast you must recover. RPO is maximum data loss — how recent your backup must be. PostgreSQL offers three backup categories: logical with pg_dump, physical with pg_basebackup, and filesystem snapshots. WAL is the foundation of all physical recovery — every change logged before data files are updated. WAL archiving enables PITR — restoring to any point in time. And the most critical rule: always test your restores. A backup you have not tested is not a backup.

- **RTO: Recovery Time Objective — maximum acceptable downtime**
- **RPO: Recovery Point Objective — maximum acceptable data loss**
- **Business requirements drive backup strategy, not tools**
- **Logical backup (pg_dump): portable, selective, slow, no PITR**
- **Physical backup (pg_basebackup): fast, PITR-capable, not selective**
- **WAL: every change logged before data files — crash recovery foundation**
- **WAL archiving + base backup = Point-in-Time Recovery (PITR)**
- **Always test restores — untested backup = no backup**


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
