# Replication Overview — Why, What, and How PostgreSQL Copies Data
**Series:** PostgreSQL Mastery | **Phase:** Phase 24: Replication & High Availability | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! We now enter Phase 24 — Replication and High Availability. This is the most hands-on phase of the entire course. Imagine your database server crashes at 2 AM. Without replication, your application is down until you restore from backup — which could take hours. With replication, a standby server takes over in seconds. Replication also lets you scale reads across multiple servers and keep a disaster recovery copy in another data center. Let us understand how it all works.

### Replication Overview
Why, What, and How
Welcome back to PostgreSQL Mastery! We now enter Phase 24 — Replication and High Availability. This is the most hands-on phase of the entire course. Imagine your database server crashes at 2 AM. Without replication, your application is down until you restore from backup — which could take hours. With replication, a standby server takes over in seconds. Replication also lets you scale reads across multiple servers and keep a disaster recovery copy in another data center. Let us understand how it all works.


---

## 2. Core Technical Concepts & Mechanisms

### Three Reasons to Replicate
There are three reasons to replicate your database. First, high availability — if the primary goes down, a standby takes over. Second, read scaling — send read queries to standbys to reduce load on the primary. Third, disaster recovery — keep a copy in another location in case of fire, flood, or data center failure.

| Term | Meaning / Explanation |
| :--- | :--- |
| **High Availability (HA)** | Primary fails → standby promotes to new primary in seconds, not hours |
| **Read Scaling** | Send SELECT queries to standbys → reduce load on primary, handle more traffic |
| **Disaster Recovery (DR)** | Copy in another data center → survives fire, power loss, regional outage |

**Notes:**
- Without replication: restore from backup = hours of downtime
- With replication: failover = seconds of downtime
- Most production databases use at least one standby

### Streaming vs Logical Replication
PostgreSQL supports two fundamentally different replication types: streaming replication and logical replication. Streaming replication copies the WAL byte stream — the raw changes at the storage level. Logical replication copies SQL-level changes — INSERT, UPDATE, DELETE operations. Each has different use cases.

| Streaming (Physical) | Logical Replication |
| :--- | :--- |
| Copies WAL byte stream (binary) | Copies SQL-level changes (row data) |
| Exact byte-for-byte copy of primary | Selective: specific tables only |
| Replicates EVERYTHING (all databases) | Subscriber can have local tables too |
| Standby is read-only | Subscriber is read-write |
| Very fast, low overhead | Slightly more overhead |
| Used for: HA, failover, read replicas | Used for: migrations, CDC, selective sync |
| Cannot replicate between versions | CAN replicate between PG versions |

### Streaming Replication Architecture
Let us understand the architecture of streaming replication. The primary server writes all changes to WAL — Write-Ahead Log files. A WAL sender process on the primary streams these WAL records to the standby. A WAL receiver process on the standby applies them. The standby becomes an exact copy of the primary, typically a few milliseconds behind.

```
[Primary Server]
[WAL Writer
(writes changes)]
[WAL Sender
(streams to standby)]
[Standby Server]
[WAL Receiver
(receives stream)]
[Recovery Process
(applies WAL)]
```

### Replication Terminology
Important terminology. The primary is the server that accepts writes. The standby receives WAL from the primary and applies it. A hot standby accepts read queries while replicating. A warm standby does not accept any queries — it only replays WAL. In PostgreSQL, standbys are hot by default when hot_standby is set to on.

| Term | Meaning |
| :--- | :--- |
| Primary | The server that accepts all writes (INSERT, UPDATE, DELETE) |
| Standby (Replica) | A server that receives WAL from primary and replays it |
| Hot Standby | Standby that accepts read-only queries (hot_standby = on) |
| Warm Standby | Standby that only replays WAL, no queries allowed |
| Promotion | Converting a standby to a new primary (failover) |
| Failover | Switching to standby when primary fails (emergency) |
| Switchover | Planned swap of primary and standby roles (maintenance) |
| WAL Sender | Process on primary that streams WAL to standby |
| WAL Receiver | Process on standby that receives WAL from primary |

### Asynchronous vs Synchronous Replication
Replication can be asynchronous or synchronous. Asynchronous is the default — the primary does not wait for the standby to confirm it received the WAL. This is fast but means you could lose a few transactions if the primary crashes before the standby catches up. Synchronous replication makes the primary wait, guaranteeing zero data loss but adding latency to every write.

| Asynchronous (Default) | Synchronous |
| :--- | :--- |
| Primary does NOT wait for standby | Primary WAITS for standby to confirm |
| Fastest writes (no extra latency) | Adds latency to every COMMIT |
| Standby may be milliseconds behind | Standby is always up to date |
| Risk: lose recent transactions on crash | Zero data loss guaranteed |
| Best for: read scaling, DR to remote DC | Risk: if standby is down, writes block! |
| synchronous_commit = on (local only) | Best for: financial, critical data |
|  | synchronous_standby_names required |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### WAL Levels for Replication
The WAL level parameter controls how much information is written to WAL. For replication, you need at least 'replica' level. For logical replication, you need 'logical' level. The default in PostgreSQL 16 is already 'replica', so streaming replication works without changing this.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | The WAL level parameter controls how much information is written to WAL |
| **For replication** | you need at least 'replica' level |
| **For logical replication** | you need 'logical' level |
| **Point 4** | The default in PostgreSQL 16 is already 'replica', so streaming replication works without changing this |

### Common Replication Topologies
Here is a topology overview of common replication setups. A single standby is the simplest. Multiple standbys split read load. Cascading replication reduces WAL sender load on the primary. Logical replication allows selective, cross-version replication.

```
[Primary]
[Standby 1
(sync)]
[Standby 2
(async)]
[Standby 3
(cascading from S1)]
[Subscriber
(logical, PG 17)]
```

### Replication Slots — Safety Net with a Risk
Replication slots prevent the primary from deleting WAL files that the standby has not yet received. Without slots, if the standby disconnects and the primary recycles WAL, the standby cannot reconnect — it needs a fresh pg_basebackup. With slots, WAL is retained until the standby catches up. But inactive slots are dangerous — they hold WAL forever and can fill your disk.

| Benefits | Risks |
| :--- | :--- |
| Prevents WAL deletion for slow standbys | Inactive slot holds WAL FOREVER |
| Standby reconnects smoothly after disconnect | Disk fills up → PostgreSQL crashes |
| No need to guess wal_keep_size | Must monitor: pg_replication_slots |
| Primary tracks each standby's progress | Drop inactive slots immediately |
|  | PG 16: max_slot_wal_keep_size limits retention |

### Configuration Overview
Here is the configuration overview for streaming replication. We will set up each piece in the following classes, but this gives you the big picture of what needs to be configured on each server.

| Primary Server Config | Standby Server Config |
| :--- | :--- |
| wal_level = replica | pg_basebackup from primary (initial copy) |
| max_wal_senders = 10 | primary_conninfo = 'host=... user=...' |
| wal_keep_size = 1GB | hot_standby = on (accept reads) |
| pg_hba.conf: replication entry | standby.signal file (marks as standby) |
| CREATE ROLE replicator REPLICATION | Optional: primary_slot_name |
| Optional: synchronous_standby_names | Optional: recovery_target_timeline |

### Choosing a Replication Strategy
Here is a decision framework for choosing your replication strategy.

- Need HA with automatic failover? -- Streaming replication + Patroni (or repmgr)
- Need read scaling for a web app? -- Streaming replication + multiple hot standbys + pgBouncer/HAProxy
- Need zero data loss? -- Synchronous replication (adds write latency)
- Need to replicate specific tables only? -- Logical replication (CREATE PUBLICATION / SUBSCRIPTION)
- Need to replicate between PG versions? -- Logical replication (e.g., PG 15 → PG 16 migration)
- Need real-time data feed to another system? -- Logical decoding + Debezium (CDC pipeline)


---

## 3. Hands-On Commands & psql Output

### Replication Monitoring Preview
**Explanation:** Let us briefly preview the key monitoring views for replication. On the primary, pg_stat_replication shows each connected standby and its lag. On the standby, pg_stat_wal_receiver shows the connection to the primary.

```sql
postgres=# -- On PRIMARY — connected standbys:
SELECT
    client_addr,
    state,
    sync_state,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
postgres-# FROM pg_stat_replication;
 client_addr  | state     | sync_state | lag_bytes
postgres=# --------------+-----------+------------+----------
 10.0.1.10    | streaming | async      |      1024
 10.0.1.11    | streaming | sync       |         0
postgres=# -- On STANDBY — connection to primary:
SELECT
    status,
    sender_host,
    sender_port,
    last_msg_receipt_time
postgres-# FROM pg_stat_wal_receiver;
  status   | sender_host | sender_port | last_msg_receipt_time
postgres=# -----------+-------------+-------------+------------------------
 streaming | 10.0.1.1    |        5432 | 2026-11-04 10:15:23+00
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. Replication copies data from a primary to one or more standbys for high availability, read scaling, and disaster recovery. Streaming replication copies WAL bytes — an exact binary copy of the entire database cluster. Logical replication copies row-level changes — selective, cross-version. Async replication is fast with possible data loss; sync guarantees zero loss but adds latency. Replication slots prevent WAL deletion but must be monitored. In the next class, we set up the primary server for streaming replication — every parameter, every line.

- **Why: High availability, read scaling, disaster recovery**
- **Streaming: WAL byte stream, exact copy, fast, read-only standby**
- **Logical: row-level changes, selective tables, read-write subscriber**
- **Async (default): no wait, fast, may lose recent commits on crash**
- **Sync: primary waits, zero data loss, adds write latency**
- **wal_level = replica (streaming) or logical (logical replication)**
- **Replication slots: prevent WAL deletion, but inactive = disk danger**
- **Hot standby: accepts read queries while replicating**
- **Promotion: standby → new primary (failover or switchover)**
- **Next: Streaming Replication — Primary Server Setup**


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
