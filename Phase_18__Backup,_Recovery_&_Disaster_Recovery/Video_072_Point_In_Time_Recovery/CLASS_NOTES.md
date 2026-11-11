# Point-in-Time Recovery (PITR)
**Series:** PostgreSQL Mastery | **Phase:** Phase 18: Backup, Recovery & Disaster Recovery | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! This is the most important backup class in the entire course. Point-in-Time Recovery — PITR — lets you restore your database to any specific second in the past. Accidentally dropped a table at 2:15 PM? PITR can restore to 2:14:59 PM — right before the disaster. This is the gold standard of PostgreSQL recovery and every production DBA must know it. We will do a complete walkthrough, step by step. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Archive Command — Linux vs Windows
On Windows, the archive_command uses copy instead of cp, and the paths use Windows format. Let me show both. The archive command must return exit code 0 on success — PostgreSQL will retry failed archives. The command must also not overwrite existing files — if the target file already exists, it should succeed silently.

| Linux | Windows |
| :--- | :--- |
| archive_command = | archive_command = |
|   'cp %p /backups/wal/%f' |   'copy "%p" |
|  |    "C:/backups/wal/%f"' |
| Or with test to avoid overwrite: |  |
|   'test ! -f /backups/wal/%f | Or with xcopy: |
|    && cp %p /backups/wal/%f' |   'xcopy "%p" |
|  |    "C:/backups/wal/%f*" /Y' |
| mkdir -p /backups/wal |  |
| chown postgres: /backups/wal | Create C:\backups\wal\ first |

### Recovery Target Types
PITR has three recovery target types. recovery_target_time stops at a timestamp — the most common. recovery_target_xid stops at a specific transaction ID — useful if you know the exact transaction that caused damage. recovery_target_name stops at a named restore point that you created earlier with pg_create_restore_point.

| Term | Meaning / Explanation |
| :--- | :--- |
| **recovery_target_time** | Stop at a specific timestamp: '2026-11-04 10:30:00+05:30' |
| **recovery_target_xid** | Stop at a specific transaction ID: '12345' |
| **recovery_target_name** | Stop at a named restore point: 'before_migration' |
| **recovery_target_lsn** | Stop at a specific WAL position: '0/5012340' |
| **recovery_target_inclusive** | true (default): include the target transaction. false: stop BEFORE it |

**Notes:**
- Create named points: SELECT pg_create_restore_point('before_migration');
- Use before risky operations: migrations, bulk updates, schema changes

### recovery_target_action Options
The recovery_target_action parameter controls what happens after recovery reaches its target. 'promote' makes the server a normal primary — this is what you want for disaster recovery. 'pause' stops recovery at the target and lets you inspect the data before committing — useful for verification. 'shutdown' stops PostgreSQL after reaching the target.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | The recovery_target_action parameter controls what happens after recovery reaches its target |
| **Point 2** | 'promote' makes the server a normal primary — this is what you want for disaster recovery |
| **Point 3** | 'pause' stops recovery at the target and lets you inspect the data before committing — useful for verification |
| **Point 4** | 'shutdown' stops PostgreSQL after reaching the target |

### Support & Materials
If you are enjoying this course, please consider supporting it. You can donate through PayPal or UPI — the links are in the description. Every contribution helps keep this course free and growing. You can also download the class materials from GitHub — the link is in the description too.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### PITR Beginner Traps
Here are the beginner traps with PITR. First, forgetting to archive WAL — without archived WAL between the base backup and now, PITR is impossible. Second, the archive directory fills up — WAL files accumulate forever unless you clean old ones. Third, recovery.signal must be in the data directory root — a common mistake is putting it in the wrong place. Fourth, not testing recovery — you will not discover your archive_command is broken until it is too late.

| Common Mistakes | Prevention |
| :--- | :--- |
| archive_command fails silently | Monitor: archive_command exit code |
| Archive disk fills up → archiving stops | Monitor archive disk + retention policy |
| recovery.signal in wrong location | recovery.signal in data directory ROOT |
| Wrong timezone in recovery_target_time | Always include timezone: +05:30 or UTC |
| Forgot recovery_target_action | Default action is 'pause' — set 'promote' |
| Never tested a recovery | Monthly DR drill: full PITR test |

### PITR Checklist — Complete Steps
Here is the complete PITR checklist — the steps you follow every time you need to perform a Point-in-Time Recovery.

- 1 -- sudo systemctl stop postgresql
- 2 -- mv main main_damaged (NEVER delete — you might need it)
- 3 -- Extract base.tar.gz + pg_wal.tar.gz, fix ownership
- 4 -- How to fetch archived WAL: 'cp /archive/%f %p'
- 5 -- recovery_target_time, _xid, _name, or _lsn
- 6 -- 'promote' for DR, 'pause' to inspect first
- 7 -- touch data_directory/recovery.signal
- 8 -- Watch logs: redo → recovery complete → ready
- 9 -- Check tables, row counts, critical data exists
- 10 -- If paused: SELECT pg_wal_replay_resume();

### Practice Exercises
Time to practice. First, enable WAL archiving on your server and verify with pg_switch_wal and checking the archive directory. Second, take a base backup with pg_basebackup. Third, insert test data, note the timestamp, then insert more data and drop the table. Fourth, perform a complete PITR to your noted timestamp. Fifth, verify that the data before the timestamp exists and the data after is gone.

- 1 -- archive_mode=on, archive_command, restart, pg_switch_wal, check archive dir
- 2 -- pg_basebackup -Ft -z -P with replication user
- 3 -- INSERT data, note timestamp, INSERT more, DROP TABLE
- 4 -- Restore base, configure restore_command + recovery_target_time, recovery.signal
- 5 -- Table exists, first data present, second data gone


---

## 3. Hands-On Commands & psql Output

### Step 1: Enable WAL Archiving
**Explanation:** The prerequisite for PITR is WAL archiving. You must configure PostgreSQL to copy every WAL segment file to an archive location before recycling it. Without archiving, WAL files are recycled after checkpoint and lost forever. Let us set up WAL archiving.

```sql
postgres=# -- Check current settings:
postgres=# SHOW archive_mode;
 archive_mode
--------------
 off
postgres=# -- Enable archiving (requires restart):
postgres=# ALTER SYSTEM SET archive_mode = 'on';
ALTER SYSTEM
postgres=# -- Set archive command (Linux):
postgres=# ALTER SYSTEM SET archive_command =
  'cp %p /backups/wal_archive/%f';
ALTER SYSTEM
postgres=# -- Ensure wal_level is at least replica:
postgres=# ALTER SYSTEM SET wal_level = 'replica';
ALTER SYSTEM
-- -- %p = full path of WAL file to archive
-- -- %f = filename only of WAL file
-- -- RESTART REQUIRED for archive_mode and wal_level
```

### Step 2: Restart and Verify Archiving
**Explanation:** After changing archive_mode and wal_level, restart PostgreSQL. Then create the archive directory and verify that WAL files are being archived. You can force a WAL switch with pg_switch_wal to test immediately.

```sql
$ # Create archive directory:
$ sudo mkdir -p /backups/wal_archive
$ sudo chown postgres:postgres /backups/wal_archive
$ # Restart PostgreSQL:
$ sudo systemctl restart postgresql
$ # Verify settings:
$ psql -U postgres -c "SHOW archive_mode; SHOW archive_command;"
 archive_mode
--------------
 on
          archive_command
-----------------------------------
 cp %p /backups/wal_archive/%f
$ # Force a WAL switch to test archiving:
$ psql -U postgres -c 'SELECT pg_switch_wal();'
$ ls /backups/wal_archive/
000000010000000000000001
-- -- WAL file archived! Archiving is working.
```

### Step 3: Take the Base Backup
**Explanation:** Step 3: take a base backup. This is your starting point for recovery. With WAL archiving enabled, pg_basebackup gives you a consistent snapshot. Combined with the archived WAL files, you can reach any point after this backup.

```sql
$ pg_basebackup -U replicator -D /backups/pitr_base \
  -Ft -z -P --checkpoint=fast
89234/89234 kB (100%), 1/1 tablespace
$ ls -lh /backups/pitr_base/
-rw-r--r-- 1 postgres 42M base.tar.gz
-rw-r--r-- 1 postgres 17M pg_wal.tar.gz
$ # Record the backup time:
$ date
Tue Nov  4 10:00:00 IST 2026
-- -- Base backup taken at 10:00 AM
-- -- All WAL after this point is archived continuously
-- -- We can recover to any time AFTER 10:00 AM
```

### Step 4: Simulate Work and Note Timestamp
**Explanation:** Now let us simulate real work. We will insert some important data, note the exact timestamp, then insert more data, then simulate a disaster. Our goal will be to recover the first batch of data but not the second — proving we can restore to a precise moment.

```sql
postgres=# \c trigger_lab
You are now connected to database "trigger_lab".
trigger_lab=# -- Important data we want to KEEP:
trigger_lab=# CREATE TABLE critical_report (id SERIAL, data TEXT, created_at TIMESTAMPTZ DEFAULT now());
CREATE TABLE
trigger_lab=# INSERT INTO critical_report (data) VALUES ('Q3 financial summary'), ('Annual audit');
INSERT 0 2
trigger_lab=# -- Note exact timestamp (THIS IS OUR RECOVERY TARGET):
trigger_lab=# SELECT now();
              now
-------------------------------
 2026-11-04 10:30:00.123+05:30
-- -- ^^^ SAVE THIS TIMESTAMP: 2026-11-04 10:30:00+05:30
trigger_lab=# -- Force WAL archive:
trigger_lab=# SELECT pg_switch_wal();
```

### Step 5: More Data, Then Disaster
**Explanation:** Now we add more data AFTER our recovery target — this is data we are willing to lose. Then we simulate a disaster: someone accidentally drops the critical table.

```sql
trigger_lab=# -- Data AFTER our recovery point (we will 'lose' this):
trigger_lab=# INSERT INTO critical_report (data) VALUES ('This data was added AFTER our target');
INSERT 0 1
trigger_lab=# SELECT * FROM critical_report;
 id |                 data                  |          created_at
----+---------------------------------------+-------------------------------
  1 | Q3 financial summary                  | 2026-11-04 10:29:50+05:30
  2 | Annual audit                          | 2026-11-04 10:29:50+05:30
  3 | This data was added AFTER our target  | 2026-11-04 10:35:00+05:30
-- 
trigger_lab=# -- DISASTER: Someone drops the table!
trigger_lab=# DROP TABLE critical_report;
DROP TABLE
trigger_lab=# SELECT * FROM critical_report;
ERROR:  relation "critical_report" does not exist
-- -- Table is GONE. pg_dump won't help (no recent dump).
-- -- But we have base backup + archived WAL. PITR to the rescue!
```

### Step 6-8: Stop, Move, Restore Base
**Explanation:** Now the recovery. Step 6: stop PostgreSQL. Step 7: move the current data directory aside — never delete it, you might need it. Step 8: restore the base backup. This gives us the database as it was at 10:00 AM — before our critical data was even inserted.

```sql
$ # Step 6: Stop PostgreSQL
$ sudo systemctl stop postgresql
$ # Step 7: Move damaged data directory aside
$ sudo mv /var/lib/postgresql/16/main /var/lib/postgresql/16/main_damaged
$ # Step 8: Restore the base backup (from 10:00 AM)
$ sudo mkdir /var/lib/postgresql/16/main
$ sudo tar xzf /backups/pitr_base/base.tar.gz \
  -C /var/lib/postgresql/16/main
$ sudo tar xzf /backups/pitr_base/pg_wal.tar.gz \
  -C /var/lib/postgresql/16/main/pg_wal
$ sudo chown -R postgres:postgres /var/lib/postgresql/16/main
-- -- We now have the database at 10:00 AM
-- -- But our data was inserted at 10:29 AM
-- -- We need to replay WAL to 10:30 AM!
```

### Step 9: Configure Recovery Target
**Explanation:** Step 9: configure the recovery target. We edit postgresql.conf — or better, create a postgresql.auto.conf entry — to tell PostgreSQL where to find the archived WAL files and when to stop replaying. The restore_command tells it how to fetch archived WAL. The recovery_target_time tells it the exact moment to stop. Then we create recovery.signal — this file tells PostgreSQL to enter recovery mode on next start.

```sql
$ # Write recovery settings to postgresql.auto.conf:
$ cat >> /var/lib/postgresql/16/main/postgresql.auto.conf << 'EOF'
restore_command = 'cp /backups/wal_archive/%f %p'
recovery_target_time = '2026-11-04 10:30:00+05:30'
recovery_target_action = 'promote'
EOF
$ # Create recovery.signal (empty file triggers recovery):
$ touch /var/lib/postgresql/16/main/recovery.signal
-- -- restore_command: how to fetch archived WAL files
-- --   %f = WAL filename, %p = destination path
-- -- recovery_target_time: STOP replaying at this moment
-- -- recovery_target_action = 'promote': become primary after recovery
-- -- recovery.signal: tells PG to enter recovery mode on start
```

### Step 10: Start Recovery
**Explanation:** Step 10: start PostgreSQL and watch recovery happen. Check the logs — you will see PostgreSQL replaying WAL files one by one, then stopping at your target time. After recovery completes, the recovery.signal file is automatically removed and the server becomes a normal primary.

```sql
$ sudo systemctl start postgresql
$ # Watch the logs:
$ tail -20 /var/log/postgresql/postgresql-16-main.log
LOG:  starting PostgreSQL 16.4
LOG:  redo starts at 0/3000028
LOG:  restored log file "000000010000000000000003" from archive
LOG:  restored log file "000000010000000000000004" from archive
LOG:  restored log file "000000010000000000000005" from archive
LOG:  recovery stopping before commit of transaction 745,
       time 2026-11-04 10:30:00.456789+05:30
LOG:  redo done at 0/5012340
LOG:  selected new timeline ID: 2
LOG:  archive recovery complete
LOG:  database system is ready to accept connections
-- -- Recovery complete! New timeline = 2 (branched from timeline 1)
```

### Step 11: Verify Recovery — The Moment of Truth
**Explanation:** Step 11: verify the recovery. Let us check that our critical data exists and that the data added AFTER our recovery target is gone. This is the moment of truth.

```sql
$ psql -U postgres -d trigger_lab
trigger_lab=# -- Does the table exist?
trigger_lab=# \dt critical_report
             List of relations
 Schema |      Name       | Type  |  Owner
--------+-----------------+-------+----------
 public | critical_report | table | postgres
trigger_lab=# -- What data is there?
trigger_lab=# SELECT * FROM critical_report;
 id |         data           |          created_at
----+------------------------+-------------------------------
  1 | Q3 financial summary   | 2026-11-04 10:29:50+05:30
  2 | Annual audit           | 2026-11-04 10:29:50+05:30
(2 rows)
-- -- ✓ Table EXISTS (was dropped but recovered!)
-- -- ✓ Rows 1-2 present (inserted before target time)
-- -- ✓ Row 3 MISSING (inserted after target time — correctly excluded)
-- -- PITR SUCCESS!
```

### Named Restore Points — Safety Net
**Explanation:** Named restore points are extremely useful. Before any risky operation — a migration, a bulk delete, a schema change — create a named restore point. If the operation goes wrong, you have an exact marker to recover to. This is much easier than trying to figure out the exact timestamp.

```sql
trigger_lab=# -- Before a risky migration:
trigger_lab=# SELECT pg_create_restore_point('before_v2_migration');
 pg_create_restore_point
-------------------------
 0/6000100
trigger_lab=# -- Run the migration...
trigger_lab=# ALTER TABLE orders ADD COLUMN status TEXT;
trigger_lab=# UPDATE orders SET status = 'pending';  -- oops, should have been 'active'
-- 
-- -- To recover to BEFORE the migration:
-- -- In postgresql.auto.conf:
-- --   restore_command = 'cp /backups/wal_archive/%f %p'
-- --   recovery_target_name = 'before_v2_migration'
-- --   recovery_target_action = 'promote'
-- -- Then: touch recovery.signal, restart PG
```

### Monitoring WAL Archiving
**Explanation:** How do you monitor WAL archiving? Check pg_stat_archiver. It tells you how many WAL files have been archived, when the last archive happened, and whether any archives have failed. If last_failed_time is recent, your archiving is broken and PITR will not work.

```sql
postgres=# SELECT * FROM pg_stat_archiver;
 archived_count | last_archived_wal          | last_archived_time
----------------+----------------------------+-------------------------------
            142 | 00000001000000000000008E    | 2026-11-04 14:30:00+05:30

 failed_count | last_failed_wal | last_failed_time
---------------+-----------------+-------------------
             0 |                 |
-- -- Good: 142 archived, 0 failed
-- -- ALERT if: failed_count > 0 or last_archived_time is old
postgres=# -- How much WAL is waiting to be archived:
postgres=# SELECT count(*) FROM pg_ls_waldir()
WHERE name NOT IN (SELECT last_archived_wal FROM pg_stat_archiver);
-- -- If this grows: archiving is falling behind
```


---

## 5. Common Beginner Traps & How to Fix Them

### PITR Beginner Traps
Here are the beginner traps with PITR. First, forgetting to archive WAL — without archived WAL between the base backup and now, PITR is impossible. Second, the archive directory fills up — WAL files accumulate forever unless you clean old ones. Third, recovery.signal must be in the data directory root — a common mistake is putting it in the wrong place. Fourth, not testing recovery — you will not discover your archive_command is broken until it is too late.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review. PITR combines a base backup with archived WAL files to restore to any moment in time. Setup: archive_mode on, archive_command configured, wal_level replica. Take base backups regularly with pg_basebackup. WAL files archive continuously. To recover: restore base backup, set restore_command and recovery_target_time in auto.conf, create recovery.signal, start PostgreSQL. Each recovery creates a new timeline. Monitor pg_stat_archiver for failures. Use pg_create_restore_point before risky operations. And test your PITR regularly — monthly is the minimum.

- **PITR = base backup + archived WAL → any point in time**
- **Setup: archive_mode=on, archive_command, wal_level=replica**
- **restore_command: how to fetch WAL from archive**
- **recovery_target_time: exact timestamp to recover to**
- **recovery_target_name: named restore point (pg_create_restore_point)**
- **recovery_target_action: promote | pause | shutdown**
- **recovery.signal in data directory root triggers recovery**
- **Each PITR creates a new timeline (branching history)**
- **Monitor: pg_stat_archiver for archive failures**
- **TEST YOUR PITR MONTHLY — untested recovery = no recovery**


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
