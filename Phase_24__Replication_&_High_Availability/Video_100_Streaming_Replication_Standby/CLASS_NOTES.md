# Streaming Replication — Standby Server Setup
**Series:** PostgreSQL Mastery | **Phase:** Phase 24: Replication & High Availability | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In the previous class, we configured the primary server for streaming replication. Now we build the standby. In this class, we take a base backup from the primary using pg_basebackup, configure the standby server, create the standby.signal file, start the standby, and verify data flows from primary to standby in real time.


---

## 2. Core Technical Concepts & Mechanisms

### Standby Setup — Four Phases
The standby setup has four phases. First, take a base backup from the primary — this copies the entire data directory. Second, configure the standby's postgresql.conf with connection info. Third, create the standby.signal file that tells PostgreSQL this is a standby. Fourth, start the standby and verify replication.

- Phase 1: pg_basebackup -- Copy the entire data directory from the primary to the standby
- Phase 2: Configure postgresql.conf -- Set primary_conninfo, hot_standby, and optional slot name
- Phase 3: Create standby.signal -- Empty file that marks this server as a standby
- Phase 4: Start & Verify -- Start PostgreSQL, check pg_stat_replication on primary

### pg_basebackup Flags Explained
Let me explain every flag in that pg_basebackup command. Each one matters.

| Flag | Meaning |
| :--- | :--- |
| -h 10.0.1.1 | Hostname/IP of the primary server |
| -U replicator | Connect as the replication user |
| -D /var/lib/.../main | Destination directory on standby (must be empty) |
| -Fp | Format = plain (copies files as-is, not a tar archive) |
| -Xs | WAL method = stream (streams WAL during backup for consistency) |
| -P | Show progress (percentage complete) |
| -R | Auto-create standby.signal and write primary_conninfo |
| -C -S slot_name | Optional: create replication slot on primary |
| --checkpoint=fast | Optional: start backup immediately (default waits for next) |

### standby.signal — The Standby Marker
The standby.signal file is critical. It is an empty file in the data directory. When PostgreSQL starts and finds this file, it enters standby mode — it connects to the primary using primary_conninfo and starts receiving WAL. If you used pg_basebackup with -R, this file was already created. Without it, PostgreSQL starts as a primary.

| With standby.signal | Without standby.signal |
| :--- | :--- |
| PostgreSQL starts in standby mode | PostgreSQL starts as a PRIMARY |
| Connects to primary via primary_conninfo | Accepts writes immediately |
| Receives and replays WAL continuously | Does NOT connect to any other server |
| Accepts read-only queries (if hot_standby=on) | The data directory is treated as standalone |
| Cannot accept writes (INSERT/UPDATE/DELETE fail) | WARNING: can cause split-brain if both write! |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Streaming Replication — Under the Hood
Here is the complete architecture showing what happens under the hood. The primary's WAL sender streams WAL records over a TCP connection to the standby's WAL receiver. The recovery process on the standby applies those records to the data files.

```
[Primary Server
(10.0.1.1)]
[Client App
(INSERT/UPDATE)]
[WAL Writer
→ pg_wal/]
[WAL Sender
(TCP stream)]
[Standby Server
(10.0.1.10)]
[Read-Only Clients
(SELECT only)]
[WAL Receiver
→ pg_wal/]
[Recovery Process
(applies WAL)]
```

### hot_standby_feedback — Prevent Query Cancellations
hot_standby_feedback is an important parameter. When enabled, the standby tells the primary which rows it still needs for running queries. Without it, the primary might vacuum away rows the standby is reading, causing query cancellations on the standby.

| Without (off — default) | With (on — recommended) |
| :--- | :--- |
| Primary vacuums rows freely | Standby tells primary what it needs |
| If standby reads vacuumed rows → conflict | Primary delays vacuuming those rows |
| Standby cancels the query with error: | No query cancellations on standby |
| ERROR: canceling statement due to conflict | Slight trade-off: more bloat on primary |
| with recovery | Set: hot_standby_feedback = on |
| Annoying for long-running standby queries | Best for standbys running analytics queries |

### Common Standby Setup Errors
Here are the common errors you may encounter during standby setup and how to fix each one.

| Error | Cause & Fix |
| :--- | :--- |
| FATAL: no pg_hba.conf entry for replication | Missing 'host replication ...' line in primary's pg_hba.conf |
| FATAL: could not connect to primary | Wrong IP/port in primary_conninfo, or firewall blocking port 5432 |
| FATAL: password authentication failed | Wrong password in primary_conninfo or .pgpass — check both |
| pg_basebackup: directory not empty | Target -D directory must be empty — remove old data first |
| pg_basebackup: too many connections | max_wal_senders too low on primary — increase and restart |
| FATAL: hot standby is not possible | wal_level on primary is 'minimal' — set to 'replica' and restart |

### Standby Setup Checklist
Here is your complete standby setup checklist.

- 1. Stop PostgreSQL on standby -- sudo systemctl stop postgresql
- 2. Clear data directory -- sudo rm -rf /var/lib/postgresql/16/main/*
- 3. Run pg_basebackup -h ... -U replicator -D ... -Fp -Xs -P -R -- Copies entire data directory + creates standby.signal
- 4. Verify standby.signal exists -- ls /var/lib/postgresql/16/main/standby.signal
- 5. Check primary_conninfo in postgresql.auto.conf -- Move password to .pgpass (chmod 600)
- 6. Set hot_standby_feedback = on (optional) -- Prevents query cancellations on standby
- 7. Start PostgreSQL -- sudo systemctl start postgresql
- 8. Verify: pg_is_in_recovery() = true -- Check pg_stat_wal_receiver on standby, pg_stat_replication on primary


---

## 3. Hands-On Commands & psql Output

### Phase 1: pg_basebackup — Full Command
**Explanation:** pg_basebackup is the tool that creates a full copy of the primary's data directory. It connects to the primary as the replication user, takes a consistent snapshot of all files, and streams them to the standby. Let us look at the command with every flag explained.

```sql
# Stop PostgreSQL on standby first (if running):
sudo systemctl stop postgresql
# Remove or empty the data directory:
sudo rm -rf /var/lib/postgresql/16/main/*
# Run pg_basebackup:
sudo -u postgres pg_basebackup \
    -h 10.0.1.1 \
    -U replicator \
    -D /var/lib/postgresql/16/main \
    -Fp \
    -Xs \
    -P \
    -R
Password: SecurePass123!
 25312/25312 kB (100%), 1/1 tablespace
```

### What -R Creates Automatically
**Explanation:** The -R flag is very convenient. It does two things automatically: creates an empty standby.signal file in the data directory, and adds primary_conninfo to postgresql.auto.conf. Without -R, you must do both manually. Let us see what -R generates.

```sql
# Check that standby.signal was created:
ls -la /var/lib/postgresql/16/main/standby.signal
-rw------- 1 postgres postgres 0 Nov  4 10:30 standby.signal
# ^ Empty file — its presence marks this as a standby
# Check what -R added to postgresql.auto.conf:
cat /var/lib/postgresql/16/main/postgresql.auto.conf
primary_conninfo = 'user=replicator password=SecurePass123! \
  channel_binding=prefer host=10.0.1.1 port=5432 \
  sslmode=prefer sslcompression=0 \
  target_session_attrs=any'
# The password is stored in plain text!
# In production, use .pgpass file instead
```

### Production: Use .pgpass for Password
**Explanation:** In production, you should not store the replication password in postgresql.auto.conf in plain text. Instead, use a .pgpass file. This file stores passwords for automatic authentication, keeping them out of configuration files.

```sql
# Create .pgpass file for the postgres user:
sudo -u postgres bash -c 'cat > ~/.pgpass << EOF
# hostname:port:database:username:password
10.0.1.1:5432:replication:replicator:SecurePass123!
EOF'
# Set strict permissions (required — won't work without this):
sudo -u postgres chmod 600 ~/.pgpass
# Now remove password from primary_conninfo:
# Edit postgresql.auto.conf:
primary_conninfo = 'user=replicator host=10.0.1.1 port=5432'
# No password= parameter needed — .pgpass handles it
```

### Phase 4: Start the Standby
**Explanation:** Now start PostgreSQL on the standby. It will read standby.signal, connect to the primary, and begin streaming WAL.

```sql
# Start PostgreSQL:
sudo systemctl start postgresql
# Check the log for successful connection:
sudo tail -20 /var/log/postgresql/postgresql-16-main.log
2026-11-04 10:35:12 UTC LOG:  entering standby mode
2026-11-04 10:35:12 UTC LOG:  redo starts at 0/5000028
2026-11-04 10:35:12 UTC LOG:  consistent recovery state reached
2026-11-04 10:35:12 UTC LOG:  database system is ready to
  accept read-only connections
2026-11-04 10:35:12 UTC LOG:  started streaming WAL from
  primary at 0/6000000 on timeline 1
```

### Verify on PRIMARY — pg_stat_replication
**Explanation:** Verify on the PRIMARY that the standby has connected. pg_stat_replication shows one row per connected standby, with its address, state, and how far behind it is.

```sql
postgres=# SELECT
    pid,
    usename,
    client_addr,
    state,
    sync_state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
postgres-# FROM pg_stat_replication;
 pid  | usename    | client_addr | state     | sync_state | lag_bytes
postgres=# ------+------------+-------------+-----------+------------+----------
 1234 | replicator | 10.0.1.10   | streaming | async      |         0
postgres=# -- state = streaming means WAL is flowing
postgres=# -- lag_bytes = 0 means standby is fully caught up
```

### Verify on STANDBY — pg_stat_wal_receiver
**Explanation:** Now verify on the STANDBY. Check pg_stat_wal_receiver to see the connection details, and confirm that pg_is_in_recovery returns true — meaning this server is indeed a standby.

```sql
postgres=# -- Confirm this is a standby:
postgres=# SELECT pg_is_in_recovery();
 pg_is_in_recovery
postgres=# --------------------
 t
(1 row)
postgres=# -- Check WAL receiver status:
postgres=# SELECT
    status,
    sender_host,
    sender_port,
    slot_name,
    received_lsn,
    last_msg_send_time,
    last_msg_receipt_time
postgres-# FROM pg_stat_wal_receiver;
  status   | sender_host | sender_port | slot_name     | received_lsn
postgres=# -----------+-------------+-------------+---------------+--------------
 streaming | 10.0.1.1    |        5432 | standby1_slot | 0/6000148
```

### Test: INSERT on Primary → SELECT on Standby
**Explanation:** Let us test actual data replication. Insert a row on the primary, then immediately query it on the standby. With async replication, the data typically appears within milliseconds.

```sql
postgres=# -- ON PRIMARY:
postgres=# CREATE TABLE repl_test (id serial, msg text, ts timestamptz DEFAULT now());
postgres=# CREATE TABLE
postgres=# INSERT INTO repl_test (msg) VALUES ('Hello from primary!');
postgres=# INSERT 0 1
postgres=# -- ON STANDBY (within milliseconds):
postgres=# SELECT * FROM repl_test;
 id |        msg          |              ts
postgres=# ----+---------------------+-------------------------------
  1 | Hello from primary! | 2026-11-04 10:40:15.123456+00
(1 row)
postgres=# -- The row appeared on the standby!
postgres=# -- Replication is working.
```

### Standby is Read-Only
**Explanation:** What happens if you try to write on the standby? PostgreSQL returns an error. The standby is read-only — this is by design. All writes must go through the primary.

```sql
postgres=# -- Try to INSERT on the standby:
postgres=# INSERT INTO repl_test (msg) VALUES ('From standby');
ERROR:  cannot execute INSERT in a read-only transaction
postgres=# -- Try to CREATE a table:
postgres=# CREATE TABLE test (id int);
ERROR:  cannot execute CREATE TABLE in a read-only transaction
postgres=# -- Try to UPDATE:
postgres=# UPDATE repl_test SET msg = 'changed';
ERROR:  cannot execute UPDATE in a read-only transaction
postgres=# -- All write operations are blocked on a hot standby
postgres=# -- Only SELECT, SHOW, EXPLAIN, and other read-only
postgres=# -- commands are allowed
```

### Measuring Replication Lag
**Explanation:** Let us measure the replication lag — how far behind the standby is from the primary. There are several ways to measure this. On the primary, compare LSN positions. On the standby, check the last replay timestamp.

```sql
postgres=# -- ON PRIMARY — lag in bytes:
SELECT
    client_addr,
    pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes,
    pg_size_pretty(
      pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)
    ) AS lag_pretty
postgres-# FROM pg_stat_replication;
 client_addr | lag_bytes | lag_pretty
postgres=# -------------+-----------+-----------
 10.0.1.10   |       128 | 128 bytes
postgres=# -- ON STANDBY — lag in time:
SELECT
    now() - pg_last_xact_replay_timestamp() AS replay_lag,
    pg_last_wal_receive_lsn() AS received,
    pg_last_wal_replay_lsn() AS replayed;
   replay_lag    |  received   |  replayed
postgres=# -----------------+-------------+------------
 00:00:00.002345 | 0/6000280   | 0/6000280
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf (on STANDBY)` — Standby Server — postgresql.conf
Now let us configure the standby's postgresql.conf. The key parameters are primary_conninfo for connecting to the primary, hot_standby to allow read queries, and optionally primary_slot_name if you created a replication slot on the primary. Crucially, parameters marked RESTART require stopping and restarting PostgreSQL, whereas parameters marked RELOAD take effect instantly with SELECT pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `primary_conninfo` | `'user=replicator host=10.0.1.1 port=5432'` | `[RELOAD]` (Live Reload `SIGHUP`) | Connect to primary (Default: '') |
| `hot_standby` | `on` | **`[RESTART]`** (Postmaster Restart) | Allow read-only queries (Default: on) |
| `primary_slot_name` | `'standby1_slot'` | `[RELOAD]` (Live Reload `SIGHUP`) | Use replication slot on primary |
| `max_wal_senders` | `10` | **`[RESTART]`** (Postmaster Restart) | Needed if cascading standbys (Default: 10) |
| `wal_level` | `replica` | **`[RESTART]`** (Postmaster Restart) | Needed for cascading (Default: replica) |
| `hot_standby_feedback` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | Report running queries to prevent vacuum conflicts |



---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. To set up a standby, use pg_basebackup with -R to copy the data directory and auto-create standby.signal plus primary_conninfo. Move the password to .pgpass for production. Enable hot_standby_feedback to prevent query cancellations. After starting, verify with pg_stat_replication on the primary and pg_is_in_recovery on the standby. Test with INSERT on primary, SELECT on standby. In the next class, we cover replication monitoring and handling failures — disconnects, WAL gaps, and failover.

- **pg_basebackup -h ... -U replicator -D ... -Fp -Xs -P -R**
- **-R auto-creates standby.signal and primary_conninfo**
- **-Fp = plain format, -Xs = stream WAL during backup**
- **standby.signal: empty file that marks server as standby**
- **primary_conninfo: connection string to the primary**
- **Move password to .pgpass (chmod 600) in production**
- **hot_standby = on → accept read-only queries**
- **hot_standby_feedback = on → prevent query cancellations**
- **Verify: pg_stat_replication (primary), pg_is_in_recovery (standby)**
- **Test: INSERT on primary → SELECT on standby within milliseconds**
- **Next: Replication Monitoring & Failover**


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
