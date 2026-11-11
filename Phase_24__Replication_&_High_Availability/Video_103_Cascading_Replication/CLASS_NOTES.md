# Cascading Replication
**Series:** PostgreSQL Mastery | **Phase:** Phase 24: Replication & High Availability | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! When you have many standbys, each one connects to the primary and receives WAL through its own WAL sender process. With ten standbys, that is ten WAL sender processes all running on the primary. Cascading replication solves this: some standbys receive WAL from another standby instead of directly from the primary. In this class, we build a Primary to Standby 1 to Standby 2 chain.


---

## 2. Core Technical Concepts & Mechanisms

### Direct vs Cascading Replication
Here is the problem. Every standby connected directly to the primary uses one WAL sender process, CPU, and network bandwidth on the primary. With many standbys, this overhead adds up. Cascading replication lets Standby 1 forward WAL to Standby 2, reducing the load on the primary.

| Direct (all to primary) | Cascading (chain) |
| :--- | :--- |
| Primary → Standby 1 | Primary → Standby 1 |
| Primary → Standby 2 | Standby 1 → Standby 2 |
| Primary → Standby 3 | Standby 1 → Standby 3 |
| 3 WAL senders on primary | Only 1 WAL sender on primary |
| 3x network bandwidth from primary | Standby 1 forwards WAL downstream |
| Primary CPU overhead increases with each | Primary load stays constant |

### Cascading Replication Chain
Here is the architecture we will build. Primary sends WAL to Standby 1. Standby 1 acts as both a standby and a relay — it receives WAL from the primary and forwards it to Standby 2. Standby 2 gets its WAL from Standby 1, not from the primary.

```
[Primary
(10.0.1.1)]
[Standby 1
(10.0.1.10)
Relay + Hot Standby]
[Standby 2
(10.0.1.11)
Hot Standby]
```

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### When Standby 1 (Relay) Goes Down
What happens if Standby 1 goes down? Standby 2 loses its WAL source. It waits and retries, just like any standby whose upstream is unreachable. If Standby 1 is permanently down, you reconfigure Standby 2 to stream directly from the primary by changing primary_conninfo.

- 1. Standby 2 detects disconnect -- Log: could not connect to server at 10.0.1.10
- 2. Standby 2 retries every 5s -- Continues serving read queries from its current data
- 3. If Standby 1 recovers → auto-reconnect -- Standby 2 catches up from where it left off
- 4. If Standby 1 is permanently down: -- Change Standby 2's primary_conninfo to point to Primary (10.0.1.1)
- 5. Reload Standby 2 config -- ALTER SYSTEM SET primary_conninfo = '...host=10.0.1.1...'; restart

### Cascading Replication Rules
Here are the rules and limitations of cascading replication.

| Rule | Details |
| :--- | :--- |
| Any standby can relay | Just needs wal_level=replica and max_wal_senders > 0 |
| Chain length | No limit, but each hop adds latency |
| Sync replication | Only between primary and directly connected standbys |
| Cannot sync through cascade | Standby 2 cannot be a sync standby of the primary |
| Failover changes chain | If relay standby is promoted, downstream must reconfigure |
| Slots on relay standby | Can create physical slots on Standby 1 for Standby 2 |

### Cascading Limitation: No Sync Through Chain
An important limitation: synchronous replication does not work through cascading. If you need Standby 2 to be synchronous, it must connect directly to the primary. Cascading is always asynchronous from the primary's perspective for downstream standbys.

| What Works | If You Need Sync for All |
| :--- | :--- |
| Primary → Standby 1: can be synchronous | Connect all sync standbys directly to primary |
| Standby 1 → Standby 2: always async | Use cascading only for async read replicas |
| Primary sees only Standby 1 in pg_stat_replication | Or use: sync to Standby 1, cascade to rest |
| Primary cannot name Standby 2 as sync | Balance: sync safety vs primary load |

### Production Topology: Sync + Cascade
Here is a practical topology for a production setup: the primary has two direct standbys in sync mode for zero data loss, and one of those standbys cascades to two more async standbys for read scaling.

```
[Primary
(writes)]
[Standby 1 (sync)
Direct to Primary]
[Standby 2 (sync)
Direct to Primary]
[Standby 3 (async)
Cascade from S1]
[Standby 4 (async)
Cascade from S1]
```


---

## 3. Hands-On Commands & psql Output

### Standby 1: Allow Downstream Connections
**Explanation:** Standby 1 also needs a pg_hba.conf entry to allow Standby 2 to connect for replication — just like the primary needed one for Standby 1. And Standby 1 needs the replicator role. Since Standby 1 is a replica of the primary, it already has the role — it was replicated from the primary's data.

```sql
# Add to Standby 1's pg_hba.conf:
# host  replication  replicator  10.0.1.11/32  scram-sha-256
# The replicator role already exists!
# It was copied from the primary during pg_basebackup.
# Reload pg_hba.conf on Standby 1:
sudo -u postgres psql -c "SELECT pg_reload_conf();"
# Optional: create a replication slot on Standby 1:
sudo -u postgres psql -c \
  "SELECT pg_create_physical_replication_slot('standby2_slot');"
```

### Standby 2: pg_basebackup from Standby 1
**Explanation:** Now set up Standby 2. The process is identical to setting up any standby, except pg_basebackup and primary_conninfo point to Standby 1 instead of the primary.

```sql
# Stop PostgreSQL on Standby 2:
sudo systemctl stop postgresql
# Clear data directory:
sudo rm -rf /var/lib/postgresql/16/main/*
# Backup from STANDBY 1 (not primary!):
sudo -u postgres pg_basebackup \
    -h 10.0.1.10 \
    -U replicator \
    -D /var/lib/postgresql/16/main \
    -Fp -Xs -P -R
Password: SecurePass123!
 25312/25312 kB (100%), 1/1 tablespace
# -R creates standby.signal and writes:
# primary_conninfo = 'user=replicator host=10.0.1.10 ...'
# Note: host=10.0.1.10 = Standby 1, NOT the primary!
```

### Standby 2: Configure and Start
**Explanation:** Configure Standby 2 to use the replication slot on Standby 1 if you created one, then start it.

```sql
# Check postgresql.auto.conf (written by -R):
cat /var/lib/postgresql/16/main/postgresql.auto.conf
primary_conninfo = 'user=replicator host=10.0.1.10 port=5432'
# Optional: add slot name
# echo "primary_slot_name = 'standby2_slot'" >> \
#   /var/lib/postgresql/16/main/postgresql.auto.conf
# Start Standby 2:
sudo systemctl start postgresql
# Check the log:
sudo tail -10 /var/log/postgresql/postgresql-16-main.log
LOG:  entering standby mode
LOG:  consistent recovery state reached
LOG:  database system is ready to accept read-only connections
LOG:  started streaming WAL from primary at 0/8000000
       on timeline 1
```

### Verify the Cascade Chain
**Explanation:** Now verify the full chain. On the Primary, pg_stat_replication shows Standby 1. On Standby 1, pg_stat_replication shows Standby 2. On Standby 2, pg_stat_wal_receiver shows it is receiving from Standby 1.

```sql
postgres=# -- ON PRIMARY:
postgres=# SELECT client_addr, state, sync_state
postgres-# FROM pg_stat_replication;
 client_addr | state     | sync_state
postgres=# -------------+-----------+------------
 10.0.1.10   | streaming | async
postgres=# -- Only Standby 1 is connected to primary
postgres=# -- ON STANDBY 1:
postgres=# SELECT client_addr, state, sync_state
postgres-# FROM pg_stat_replication;
 client_addr | state     | sync_state
postgres=# -------------+-----------+------------
 10.0.1.11   | streaming | async
postgres=# -- Standby 2 is connected to Standby 1!
postgres=# -- ON STANDBY 2:
postgres=# SELECT sender_host, status
postgres-# FROM pg_stat_wal_receiver;
 sender_host | status
postgres=# -------------+-----------
 10.0.1.10   | streaming
postgres=# -- Receiving from Standby 1, not from primary
```

### Test: Data Flows Through the Chain
**Explanation:** Test the full chain. Insert on the primary, verify it appears on both standbys.

```sql
postgres=# -- ON PRIMARY:
postgres=# INSERT INTO repl_test (msg)
postgres-# VALUES ('Cascading test!');
postgres=# -- ON STANDBY 1 (milliseconds later):
postgres=# SELECT * FROM repl_test WHERE msg = 'Cascading test!';
 id |      msg        |              ts
postgres=# ----+-----------------+-------------------------------
  3 | Cascading test! | 2026-11-04 11:20:15.123+00
postgres=# -- ON STANDBY 2 (a few more milliseconds):
postgres=# SELECT * FROM repl_test WHERE msg = 'Cascading test!';
 id |      msg        |              ts
postgres=# ----+-----------------+-------------------------------
  3 | Cascading test! | 2026-11-04 11:20:15.123+00
postgres=# -- Data flows: Primary → Standby 1 → Standby 2
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf (on Standby 1)` — Standby 1 Config — Relay Requirements
The key to cascading is that a standby can also act as a WAL sender. For this, the standby needs wal_level = replica and max_wal_senders greater than zero. In PostgreSQL 16, both are already the defaults. So Standby 1 can forward WAL without any special configuration beyond what a normal standby already has. Crucially, parameters marked RESTART require stopping and restarting PostgreSQL, whereas parameters marked RELOAD take effect instantly with SELECT pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `wal_level` | `replica` | **`[RESTART]`** (Postmaster Restart) | Needed to forward WAL stream |
| `max_wal_senders` | `10` | **`[RESTART]`** (Postmaster Restart) | Allows downstream standbys to connect |
| `hot_standby` | `on` | **`[RESTART]`** (Postmaster Restart) | Accept read queries on intermediate standby |
| `primary_conninfo` | `'user=replicator host=10.0.1.1'` | `[RELOAD]` (Live Reload `SIGHUP`) | Connects intermediate to PRIMARY |
| `primary_slot_name` | `'standby1_slot'` | `[RELOAD]` (Live Reload `SIGHUP`) | Replication slot on primary |
| `hot_standby_feedback` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | Report query states upstream to primary |



---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. Cascading replication lets standbys receive WAL from another standby instead of directly from the primary. This reduces WAL sender load and network bandwidth on the primary. Any standby can relay WAL as long as wal_level is replica and max_wal_senders is greater than zero. Synchronous replication does not work through cascading — only between primary and its direct standbys. If the relay standby goes down, downstream standbys can be reconfigured to stream from the primary or another standby. In the next class, we start logical replication.

- **Cascading: standby receives WAL from another standby**
- **Reduces WAL sender load on primary**
- **Any standby can relay (wal_level=replica, max_wal_senders>0)**
- **Setup: pg_basebackup from relay standby, not from primary**
- **primary_conninfo points to relay standby, not primary**
- **Chain length: unlimited, but each hop adds lag**
- **Sync replication: only primary ↔ direct standbys**
- **Cannot sync through cascade chain**
- **If relay goes down: reconfigure downstream to new source**
- **Production pattern: sync direct + async cascading**
- **Next: Logical Replication Setup**


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
