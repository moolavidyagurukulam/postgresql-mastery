# Replication Monitoring & Failover
**Series:** PostgreSQL Mastery | **Phase:** Phase 24: Replication & High Availability | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! You have streaming replication running — primary and standby are connected. Now what happens when things go wrong? In this class, we cover monitoring replication health, handling disconnections, dealing with WAL segment removal errors, network timeouts, and most importantly — performing failover with pg_promote. We will also see the real error messages you will encounter.


---

## 2. Core Technical Concepts & Mechanisms

### Three Things to Monitor
Monitoring replication means watching three things: lag, connection state, and WAL retention. Lag tells you how far behind the standby is. Connection state tells you if the standby is streaming or disconnected. WAL retention tells you whether the primary still has the WAL the standby needs.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Replication Lag** | How far behind is the standby? Measured in bytes or time |
| **Connection State** | Is the standby streaming, catching up, or disconnected? |
| **WAL Retention** | Does the primary still have the WAL the standby needs? |

**Notes:**
- If lag grows: standby I/O or network issue
- If connection drops: network or standby crash
- If WAL removed: standby needs fresh pg_basebackup

### pg_stat_replication — Connection States
pg_stat_replication shows different connection states. 'streaming' means the standby is connected and receiving WAL in real time. 'catchup' means the standby was behind and is processing stored WAL. 'startup' means the standby just connected and is initializing. If a standby row disappears, the standby disconnected.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | pg_stat_replication shows different connection states |
| **Point 2** | 'streaming' means the standby is connected and receiving WAL in real time |
| **Point 3** | 'catchup' means the standby was behind and is processing stored WAL |
| **Point 4** | 'startup' means the standby just connected and is initializing |
| **If a standby row disappears** | the standby disconnected |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Reconfiguring the Old Primary
What happens to the old primary? If it comes back online, it thinks it is still a primary. You have two options. Option one: make it a standby of the new primary using pg_basebackup. Option two: use pg_rewind to fast-forward it without a full backup. pg_rewind is faster but requires wal_log_hints or checksums enabled.

| Option 1: Fresh pg_basebackup | Option 2: pg_rewind (faster) |
| :--- | :--- |
| Stop old primary | Stop old primary |
| Delete its data directory | Run pg_rewind --target-pgdata=... --source-server=... |
| pg_basebackup from new primary | Syncs only divergent WAL |
| Create standby.signal | Create standby.signal |
| Start as standby | Start as standby |
| Pros: always works, clean state | Pros: fast (minutes, not hours) |
| Cons: slow for large databases | Requires: wal_log_hints=on or checksums |

### Failover Procedure Checklist
Here is the complete failover procedure as a step-by-step checklist. Follow this order when the primary fails and you need to promote the standby.

- 1. Confirm primary is truly down -- Try connecting, check systemctl status, check from multiple clients
- 2. Check standby lag before promoting -- SELECT pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn();
- 3. Promote the standby -- SELECT pg_promote(); — wait for 'database system is ready'
- 4. Verify writes work -- INSERT INTO test_table VALUES (...); — must succeed
- 5. Update application connection strings -- Point app to the new primary IP/hostname
- 6. Reconfigure old primary as standby -- pg_rewind or fresh pg_basebackup pointing to new primary

### Switchover (Planned Role Swap)
Switchover is a planned, graceful role swap — unlike failover which is an emergency. In a switchover, you first stop writes on the primary, wait for the standby to catch up completely, promote the standby, then convert the old primary to a standby.

- 1. Stop application writes -- Pause app, or set default_transaction_read_only = on
- 2. Wait for standby to catch up -- Verify lag_bytes = 0 in pg_stat_replication
- 3. Stop the primary -- sudo systemctl stop postgresql (on old primary)
- 4. Promote the standby -- SELECT pg_promote(); on the standby
- 5. Convert old primary to standby -- pg_rewind + standby.signal + primary_conninfo → start
- 6. Redirect application to new primary -- Update connection strings, DNS, or load balancer

### Replication Troubleshooting Decision Table
Here is a decision framework for handling replication issues.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a decision framework for handling replication issues |

### Split-Brain — The Worst Scenario
Important: never run two servers as primary at the same time. This is called split-brain. If the old primary comes back after failover and you did not convert it to a standby, both servers accept writes, and the data diverges permanently. Always stop the old primary or convert it to standby before allowing it to accept connections.

| What Happens | How to Prevent |
| :--- | :--- |
| Old primary comes back online | ALWAYS stop old primary before it restarts |
| Both servers accept writes | Convert old primary to standby (pg_rewind) |
| Data diverges permanently | Use fencing (STONITH) in HA setups |
| No way to merge conflicting changes | Use Patroni — it handles this automatically |
| Users see different data on each server | Monitor timeline IDs to detect divergence |


---

## 3. Hands-On Commands & psql Output

### Complete Lag Monitoring Query
**Explanation:** Here is the complete lag monitoring query. Run this on the primary to see every connected standby, its state, and the lag in both bytes and human-readable format.

```sql
SELECT
    client_addr,
    state,
    sync_state,
    pg_wal_lsn_diff(sent_lsn, write_lsn) AS send_lag,
    pg_wal_lsn_diff(write_lsn, flush_lsn) AS flush_lag,
    pg_wal_lsn_diff(flush_lsn, replay_lsn) AS replay_lag,
    pg_wal_lsn_diff(
        pg_current_wal_lsn(), replay_lsn
    ) AS total_lag_bytes,
    pg_size_pretty(
        pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)
    ) AS total_lag
postgres-# FROM pg_stat_replication;
 client_addr | state     | sync_state | total_lag
postgres=# -------------+-----------+------------+----------
 10.0.1.10   | streaming | async      | 256 bytes
```

### Standby-Side Monitoring
**Explanation:** On the standby side, pg_stat_wal_receiver gives you a different view. It shows the connection status to the primary, what LSN has been received, and the last communication time. If last_msg_receipt_time is old, the connection may be stale.

```sql
SELECT
    status,
    sender_host,
    sender_port,
    received_lsn,
    pg_last_wal_receive_lsn() AS last_received,
    pg_last_wal_replay_lsn() AS last_replayed,
    pg_last_xact_replay_timestamp() AS last_replayed_at,
    now() - pg_last_xact_replay_timestamp() AS time_lag
postgres-# FROM pg_stat_wal_receiver;
  status   | sender_host | received_lsn |    time_lag
postgres=# -----------+-------------+--------------+----------------
 streaming | 10.0.1.1    | 0/7000148    | 00:00:00.003
```

### Error: WAL Segment Already Removed
**Explanation:** Now let us look at real error scenarios. Scenario one: the standby disconnects and the primary recycles the WAL segments the standby needs. When the standby tries to reconnect, it gets this fatal error. The only fix is a fresh pg_basebackup.

```sql
FATAL:  could not receive data from WAL stream:
  ERROR:  requested WAL segment 000000010000000000000005
  has already been removed
postgres=# -- What happened:
postgres=# -- 1. Standby was offline for hours/days
postgres=# -- 2. Primary recycled old WAL segments
postgres=# -- 3. Standby can no longer catch up from WAL
postgres=# -- Fix:
postgres=# -- 1. Stop the standby
postgres=# -- 2. Delete the data directory
postgres=# -- 3. Run pg_basebackup again from the primary
postgres=# -- 4. Start the standby
postgres=# -- Prevention:
postgres=# -- Use replication slots (WAL retained for each standby)
postgres=# -- OR set wal_keep_size large enough (2GB+)
postgres=# -- OR use WAL archiving (archive_mode = on)
```

### Error: Cannot Connect to Primary
**Explanation:** Scenario two: the standby cannot connect to the primary. This happens when the primary is down, the network is broken, or the firewall blocks port 5432. The standby retries automatically based on wal_retrieve_retry_interval.

```sql
FATAL:  could not connect to the primary server:
  Connection refused
  Is the server running on host "10.0.1.1" and
  accepting TCP/IP connections on port 5432?
LOG:  waiting for WAL to become available at 0/7000200
postgres=# -- What happened:
postgres=# -- Primary is down, or network issue, or firewall
postgres=# -- Standby behavior:
postgres=# -- Retries every wal_retrieve_retry_interval (default: 5s)
postgres=# -- Serves read-only queries from its current data
postgres=# -- Does NOT crash — it waits patiently
postgres=# -- Actions:
postgres=# -- 1. Fix the primary or network issue
postgres=# -- 2. Standby automatically reconnects when primary is back
postgres=# -- 3. No manual intervention needed on the standby
```

### Error: Database System Is Starting Up
**Explanation:** Scenario three: the standby shows 'database system is starting up' when you try to connect. This means the standby is still replaying WAL and has not reached a consistent state yet. You must wait for it to finish before connecting.

```sql
psql: error: connection to server failed:
  FATAL:  the database system is starting up
postgres=# -- What happened:
postgres=# -- Standby is replaying WAL to reach a consistent state
postgres=# -- This is normal right after pg_basebackup or restart
postgres=# -- Check the log:
sudo tail -5 /var/log/postgresql/postgresql-16-main.log
LOG:  redo starts at 0/5000028
LOG:  consistent recovery state reached at 0/5000100
LOG:  database system is ready to accept
  read-only connections
postgres=# -- Once you see 'consistent recovery state reached',
postgres=# -- the standby accepts connections
postgres=# -- Time depends on how much WAL needs to be replayed
```

### Error: Query Canceled Due to Recovery Conflict
**Explanation:** Scenario four: query conflicts on the standby. When the primary vacuums a row that the standby is still reading in a query, the standby must choose: cancel the query or delay recovery. The default cancels the query after max_standby_streaming_delay, which is 30 seconds.

```sql
ERROR:  canceling statement due to conflict
postgres=# with recovery
DETAIL:  User query might have needed to see row versions
  that must be removed.
postgres=# -- What happened:
postgres=# -- 1. Standby is running a long SELECT query
postgres=# -- 2. Primary VACUUMs the rows that query is reading
postgres=# -- 3. WAL replay needs to remove those rows
postgres=# -- 4. After 30s (default), the query is canceled
postgres=# -- Fix options:
postgres=# -- 1. Set hot_standby_feedback = on (on standby)
postgres=# --    → Primary delays vacuum of needed rows
postgres=# -- 2. Increase max_standby_streaming_delay
postgres=# --    → Standby waits longer before canceling
postgres=# -- 3. Set max_standby_streaming_delay = -1
postgres=# --    → Never cancel queries (WAL replay pauses)
```

### Failover: Promoting the Standby
**Explanation:** Now the most important operation — failover. When the primary dies and cannot be recovered, you promote the standby to become the new primary. PostgreSQL provides pg_promote for this. Once promoted, the standby stops replaying WAL and starts accepting writes.

```sql
postgres=# -- Method 1: SQL function (PG 12+)
postgres=# SELECT pg_promote();
 pg_promote
postgres=# ------------
 t
(1 row)
postgres=# -- Method 2: pg_ctl command line
postgres=# -- sudo -u postgres pg_ctl promote \
postgres=# --   -D /var/lib/postgresql/16/main
postgres=# -- Method 3: Create trigger file (legacy)
postgres=# -- touch /tmp/postgresql.trigger.5432
postgres=# -- After promotion:
postgres=# SELECT pg_is_in_recovery();
 pg_is_in_recovery
postgres=# --------------------
 f
(1 row)
postgres=# -- false = this is now a PRIMARY server
```

### After Promotion — What Changes
**Explanation:** After promotion, the standby.signal file is automatically removed. The server starts a new WAL timeline, which is critical — it prevents the old primary from accidentally writing conflicting data if it comes back. The timeline ID increments from 1 to 2.

```sql
postgres=# -- standby.signal is automatically deleted
postgres=# -- Server switches to new timeline (1 → 2)
postgres=# -- Check the log:
LOG:  received promote request
LOG:  redo done at 0/7000100
LOG:  selected new timeline ID: 2
LOG:  archive recovery complete
LOG:  database system is ready to accept connections
postgres=# -- Verify writes work:
postgres=# INSERT INTO repl_test (msg)
postgres-# VALUES ('First write after promotion!');
postgres=# INSERT 0 1
postgres=# -- Success! This server is now the primary.
postgres=# -- Check timeline:
postgres=# SELECT timeline_id FROM pg_control_checkpoint();
 timeline_id
postgres=# --------------
            2
```

### pg_rewind — Fast Re-sync
**Explanation:** Here is the pg_rewind command to convert the old primary into a standby of the new primary. This is much faster than pg_basebackup for large databases because it only copies the data that diverged.

```sql
# Stop the old primary:
sudo systemctl stop postgresql
# Run pg_rewind:
sudo -u postgres pg_rewind \
postgres=# --target-pgdata=/var/lib/postgresql/16/main \
postgres=# --source-server='host=10.0.1.10 user=postgres dbname=postgres'
pg_rewind: servers diverged at WAL location 0/7000100
  on timeline 1
pg_rewind: rewinding from last common checkpoint
  at 0/7000028 on timeline 1
pg_rewind: Done!
# Create standby.signal:
sudo -u postgres touch /var/lib/postgresql/16/main/standby.signal
# Update primary_conninfo to point to NEW primary:
# Edit postgresql.auto.conf:
# primary_conninfo = 'user=replicator host=10.0.1.10 port=5432'
# Start as standby:
sudo systemctl start postgresql
```

### Replication Health Check Script
**Explanation:** Here is a monitoring query you can run as a cron job or from your monitoring tool. It checks replication health and raises alerts when lag exceeds thresholds.

```sql
-- Run on PRIMARY: check all standbys
SELECT
    client_addr,
    state,
    sync_state,
    pg_size_pretty(
      pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)
    ) AS lag,
    CASE
      WHEN pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)
           > 1073741824 THEN 'CRITICAL (> 1 GB)'
      WHEN pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)
           > 104857600 THEN 'WARNING (> 100 MB)'
      ELSE 'OK'
    END AS status
FROM pg_stat_replication;

-- Check for inactive replication slots:
SELECT slot_name, active,
    pg_size_pretty(
      pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)
    ) AS retained_wal
FROM pg_replication_slots
WHERE NOT active;
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf` — Recovery Conflict Settings (on STANDBY)
Here is the recovery conflict configuration. These settings control how the standby handles conflicts between queries and WAL replay. Crucially, parameters marked RESTART require stopping and restarting PostgreSQL, whereas parameters marked RELOAD take effect instantly with SELECT pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `hot_standby_feedback` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | Prevents query cancellation conflicts |
| `max_standby_streaming_delay` | `30s` | `[RELOAD]` (Live Reload `SIGHUP`) | Max query delay before cancel (Default: 30s) |
| `max_standby_archive_delay` | `30s` | `[RELOAD]` (Live Reload `SIGHUP`) | Archive recovery query delay (Default: 30s) |
| `wal_receiver_timeout` | `60s` | `[RELOAD]` (Live Reload `SIGHUP`) | Standby WAL receive heartbeat (Default: 60s) |
| `wal_sender_timeout` | `60s` | `[RELOAD]` (Live Reload `SIGHUP`) | Primary sender heartbeat (Default: 60s) |
| `wal_retrieve_retry_interval` | `5s` | `[RELOAD]` (Live Reload `SIGHUP`) | Wait before re-requesting WAL (Default: 5s) |



---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. Monitor replication with pg_stat_replication on the primary and pg_stat_wal_receiver on the standby. Watch lag bytes, connection state, and WAL retention. Handle WAL removal errors with fresh pg_basebackup. Handle query conflicts with hot_standby_feedback. Failover uses pg_promote. After failover, convert the old primary to a standby using pg_rewind or pg_basebackup. Never allow split-brain. In the next class, we cover synchronous replication and replication slots in depth.

- **Monitor: pg_stat_replication (primary), pg_stat_wal_receiver (standby)**
- **Lag = pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)**
- **States: streaming (ok), catchup (catching up), missing (disconnected)**
- **WAL removed error → only fix is fresh pg_basebackup**
- **Query conflicts → hot_standby_feedback = on**
- **Failover: SELECT pg_promote(); or pg_ctl promote**
- **After promotion: new timeline (prevents split-brain)**
- **Old primary → pg_rewind (fast) or pg_basebackup (safe)**
- **NEVER run two primaries (split-brain = permanent data loss)**
- **Switchover: stop writes → wait lag=0 → promote → convert old**
- **Next: Synchronous Replication & Replication Slots**


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
