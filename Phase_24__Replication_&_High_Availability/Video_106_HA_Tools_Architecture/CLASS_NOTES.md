# HA Tools & Architecture — Patroni, PgBouncer, HAProxy
**Series:** PostgreSQL Mastery | **Phase:** Phase 24: Replication & High Availability | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! This is the final class of Phase 24. We have built streaming replication, logical replication, and failover by hand. But in production, you do not promote standbys manually at 3 AM. You need automatic failover, connection pooling, and load balancing. In this class, we cover the HA ecosystem — Patroni with etcd for automatic failover, PgBouncer for connection pooling, HAProxy for load balancing, and how to architect a production HA cluster.


---

## 2. Core Technical Concepts & Mechanisms

### Manual vs Automatic Failover
Here is the problem we are solving. Manual failover requires a human to detect the failure, decide to promote, run pg_promote, update connection strings, and restart the application. This takes minutes to hours. Automatic failover detects the failure, promotes the best standby, and redirects traffic — all within seconds, without human intervention.

| Manual Failover | Automatic (Patroni) |
| :--- | :--- |
| 1. Alert fires (PagerDuty, etc.) | 1. Patroni detects primary failure |
| 2. Human wakes up, investigates | 2. Patroni picks best standby (lowest lag) |
| 3. Human decides to promote | 3. Patroni promotes automatically |
| 4. Human runs pg_promote() | 4. Patroni updates DCS (etcd/consul) |
| 5. Human updates connection strings | 5. HAProxy redirects traffic |
| 6. Human restarts application | 6. Application reconnects automatically |
| Downtime: minutes to hours | Downtime: seconds |

### Production HA Architecture
The production HA stack has four layers. PostgreSQL for the database, Patroni for failover management, etcd for consensus and leader election, and HAProxy or PgBouncer for routing connections. Let us see the full architecture.

```
[Application]
[HAProxy
(load balancer)]
[PgBouncer
(connection pool)]
[PgBouncer
(connection pool)]
[PgBouncer
(connection pool)]
[Patroni + PG
(Primary)]
[Patroni + PG
(Standby 1)]
[Patroni + PG
(Standby 2)]
[etcd cluster
(consensus)]
```

### Patroni — What It Does
Patroni is the most popular HA solution for PostgreSQL. It is a Python daemon that runs alongside each PostgreSQL instance. It manages replication, monitors health, handles failover, and stores cluster state in a distributed consensus store like etcd. Patroni handles everything we did manually in previous classes — automatically.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Cluster Management** | Bootstraps PostgreSQL, configures replication, manages roles |
| **Health Monitoring** | Checks PostgreSQL health, detects failures within seconds |
| **Automatic Failover** | Promotes best standby, demotes old primary, prevents split-brain |
| **Configuration Management** | Stores and distributes postgresql.conf settings via DCS |

**Notes:**
- One Patroni instance per PostgreSQL server
- Requires DCS: etcd, consul, or ZooKeeper
- REST API for monitoring and management
- patronictl command-line tool for operations

### etcd — The Consensus Store
etcd is the distributed consensus store that Patroni uses. It stores which node is the current leader, the cluster configuration, and the health status of each node. etcd uses the Raft consensus algorithm to ensure all nodes agree on who the leader is. You need at least 3 etcd nodes for fault tolerance.

| What etcd Stores | Why 3+ Nodes |
| :--- | :--- |
| Current leader (primary) identity | Raft needs majority to agree |
| Leader lock with TTL (time to live) | 3 nodes: tolerates 1 failure |
| Cluster membership (which nodes exist) | 5 nodes: tolerates 2 failures |
| PostgreSQL configuration | Even numbers (2, 4) offer no benefit |
| Node health timestamps | etcd nodes should be on separate hosts |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Patroni Automatic Failover — How It Works
How does Patroni perform automatic failover? The leader node holds a lock in etcd with a TTL. It must renew this lock every loop_wait seconds. If the leader fails to renew — because PostgreSQL crashed, the server died, or the network is broken — the lock expires. The remaining nodes hold an election, and the standby with the lowest replication lag becomes the new leader.

- 1. Leader holds lock in etcd (TTL = 30s) -- Renewed every 10s (loop_wait). If not renewed, lock expires.
- 2. Leader fails (crash, network, disk full) -- Cannot renew etcd lock. Lock expires after TTL.
- 3. Replicas detect leader absence -- etcd key is gone. Election begins.
- 4. Best replica wins election -- Lowest lag, passes health checks, acquires lock.
- 5. Winner promotes itself -- Runs pg_promote(), becomes new primary.
- 6. Other replicas follow new leader -- Update primary_conninfo to point to new primary.

### Patroni vs repmgr
repmgr is an alternative to Patroni. It is a lighter tool — it does not require etcd or any external consensus store. It uses a shared table in PostgreSQL itself to track cluster state. However, it is less robust for automatic failover because it lacks true distributed consensus.

| Patroni | repmgr |
| :--- | :--- |
| Requires etcd/consul/ZooKeeper | No external DCS needed |
| True distributed consensus | Uses PostgreSQL table for metadata |
| Prevents split-brain reliably | Simpler setup (fewer components) |
| Manages PostgreSQL lifecycle | repmgrd daemon for auto-failover |
| REST API + patronictl CLI | SSH-based operations |
| More infrastructure to manage | Split-brain risk without fencing |
| Industry standard for HA | Good for smaller deployments |

### PgBouncer — Connection Pooling
Now connection pooling. PgBouncer sits between your application and PostgreSQL. It maintains a pool of database connections and shares them among application clients. Without PgBouncer, 500 application threads create 500 PostgreSQL connections, each using about 10 MB of memory. With PgBouncer, those 500 threads share 50 actual connections.

| Without PgBouncer | With PgBouncer |
| :--- | :--- |
| 500 app threads → 500 PG connections | 500 app threads → PgBouncer → 50 PG connections |
| Each connection: ~10 MB RAM | 50 * 10 MB = 500 MB (10x less RAM) |
| 500 * 10 MB = 5 GB just for connections | PgBouncer connections: ~2 KB each |
| Context switching overhead | Much less context switching |
| max_connections often hit | PG handles 50 connections efficiently |

### PgBouncer Pooling Modes
PgBouncer has three pooling modes. Transaction mode is the most common — a server connection is assigned to a client only for the duration of a transaction. Between transactions, the connection goes back to the pool.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | PgBouncer has three pooling modes |
| **Transaction mode is the most common** | a server connection is assigned to a client only for the duration of a transaction |
| **Between transactions** | the connection goes back to the pool |

### Pgpool-II vs Patroni + PgBouncer + HAProxy
Pgpool-II is an alternative that combines connection pooling, load balancing, and replication management in one tool. However, it is more complex and can be harder to debug than the Patroni plus PgBouncer plus HAProxy stack.

| Pgpool-II (all-in-one) | Patroni + PgBouncer + HAProxy |
| :--- | :--- |
| Connection pooling | Each tool does one thing well |
| Load balancing | Easier to debug (isolated concerns) |
| Automatic failover | Industry standard combination |
| Watchdog for Pgpool HA | More components to manage |
| One tool to install | Patroni: failover + cluster management |
| Complex configuration | PgBouncer: connection pooling |
| Harder to debug failures | HAProxy: load balancing + routing |

### Production HA Deployment Checklist
Here is the complete HA deployment checklist for a production PostgreSQL cluster.

- 1. Deploy 3+ etcd nodes -- Separate hosts, odd number for quorum
- 2. Install Patroni on each PG node -- pip install patroni[etcd], configure patroni.yml
- 3. Bootstrap the cluster with Patroni -- patroni patroni.yml — first node becomes leader
- 4. Add replica nodes -- Start Patroni on each — auto-joins and syncs via pg_basebackup
- 5. Deploy PgBouncer on each PG node -- Transaction pooling, port 6432, reduces connection overhead
- 6. Deploy HAProxy (2 nodes for HA) -- Port 5432 → primary, port 5433 → replicas, health checks via Patroni API
- 7. Point application to HAProxy -- Connection string: host=haproxy port=5432 for writes, port=5433 for reads
- 8. Test failover -- patronictl switchover → verify app continues working

### HA Tools Reference
Here are the HA tools at a glance — what each one does and when to use it.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here are the HA tools at a glance — what each one does and when to use it |

### HA Beginner Traps
Here are the common beginner mistakes with HA setups.

| Mistake | Consequence |
| :--- | :--- |
| Only 1 etcd node | Single point of failure — cluster cannot elect leader |
| etcd on same host as PG | If host dies, lose both PG and consensus vote |
| No PgBouncer | 500 app connections = 5 GB RAM on PostgreSQL |
| App connects directly to PG | Must change connection string on every failover |
| No testing failover | First failover in production = surprise outages |
| No backup even with HA | HA protects against crashes, not data corruption or mistakes |


---

## 3. Hands-On Commands & psql Output

### patronictl — Cluster Management
**Explanation:** patronictl is the command-line tool for managing your Patroni cluster. It shows cluster status, lets you trigger switchovers, restart nodes, and change configuration.

```sql
# Show cluster status:
$ patronictl -c /etc/patroni.yml list
+ Cluster: pg-cluster (7298176234) -----+
| Member | Host       | Role    | State   | TL | Lag in MB |
+--------+------------+---------+---------+----+-----------+
| node1  | 10.0.1.1   | Leader  | running |  1 |           |
| node2  | 10.0.1.10  | Replica | running |  1 |         0 |
| node3  | 10.0.1.11  | Replica | running |  1 |         0 |
+--------+------------+---------+---------+----+-----------+
# Planned switchover:
$ patronictl -c /etc/patroni.yml switchover
Current cluster leader: node1
Candidate: node2
Are you sure? [y/N]: y
Switchover succeeded, new leader: node2
# Restart a node:
$ patronictl -c /etc/patroni.yml restart pg-cluster node1
```

### Patroni REST API Health Checks
**Explanation:** Patroni exposes a REST API that HAProxy queries. The primary responds with HTTP 200 to the /primary endpoint. Standbys respond with HTTP 200 to the /replica endpoint. When a failover happens, the new primary starts responding to /primary, and HAProxy automatically routes writes to it.

```sql
# Check if node is primary:
$ curl -s http://10.0.1.1:8008/primary
{"state": "running", "role": "master"}
# HTTP 200 → this is the primary
$ curl -s http://10.0.1.10:8008/primary
# HTTP 503 → this is NOT the primary
# Check if node is a replica:
$ curl -s http://10.0.1.10:8008/replica
{"state": "running", "role": "replica"}
# HTTP 200 → this is a replica
# Full cluster info:
$ curl -s http://10.0.1.1:8008/cluster | python3 -m json.tool
{
  "members": [
    {"name": "node1", "role": "leader", "state": "running",
     "host": "10.0.1.1", "port": 5432, "lag": 0},
    {"name": "node2", "role": "replica", "state": "running",
     "host": "10.0.1.10", "port": 5432, "lag": 0}
  ]
}
```

### Application Connection Strings
**Explanation:** Here is the application connection strategy. The application connects to HAProxy, not directly to PostgreSQL. HAProxy has two ports — one for writes that always routes to the primary, and one for reads that round-robins across standbys.

```sql
# Write connection (goes to primary via HAProxy):
DATABASE_WRITE_URL = 'postgresql://myuser:pass@haproxy:5432/mydb'
# Read connection (goes to replicas via HAProxy):
DATABASE_READ_URL = 'postgresql://myuser:pass@haproxy:5433/mydb'
# With PgBouncer in the path:
# App → HAProxy:5432 → PgBouncer:6432 → PostgreSQL:5432
# Alternative: use libpq multi-host (no HAProxy needed):
# postgresql://myuser:pass@node1:5432,node2:5432,node3:5432/mydb
#   ?target_session_attrs=read-write
# libpq tries each host until it finds the primary
# PG 16: target_session_attrs=primary (more explicit)
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `patroni.yml (on each PG node)` — Patroni Configuration — patroni.yml
Here is a Patroni configuration file. Each PostgreSQL node gets its own patroni.yml with the node name, connection details, etcd endpoints, and PostgreSQL settings. Crucially, parameters marked RESTART require stopping and restarting PostgreSQL, whereas parameters marked RELOAD take effect instantly with SELECT pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `scope` | `pg-cluster` | `[SETTING]` | Cluster identifier across all nodes |
| `name` | `node1` | `[SETTING]` | Unique Patroni node name |
| `dcs.etcd3.hosts` | `etcd1:2379,etcd2:2379,etcd3:2379` | `[SETTING]` | Distributed consensus endpoints |
| `restapi.listen` | `0.0.0.0:8008` | `[SETTING]` | Patroni REST health API port |
| `postgresql.listen` | `0.0.0.0:5432` | `[SETTING]` | PostgreSQL socket listen address |
| `postgresql.data_dir` | `/var/lib/postgresql/16/main` | `[SETTING]` | PostgreSQL data directory |
| `loop_wait` | `10` | `[SETTING]` | Seconds between DCS health polls |
| `ttl` | `30` | `[SETTING]` | Leader lease expiration time in seconds |


### File: `pgbouncer.ini` — PgBouncer Configuration — pgbouncer.ini
Here is a PgBouncer configuration. The key settings are the pool size, the pooling mode, and the database connection strings. Crucially, parameters marked RESTART require stopping and restarting PostgreSQL, whereas parameters marked RELOAD take effect instantly with SELECT pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `mydb` | `host=127.0.0.1 port=5432 dbname=mydb` | `[SETTING]` | [databases] Local PostgreSQL target |
| `listen_addr` | `0.0.0.0` | `[SETTING]` | [pgbouncer] Listen on all network interfaces |
| `listen_port` | `6432` | `[SETTING]` | PgBouncer proxy port (clients connect here) |
| `pool_mode` | `transaction` | `[SETTING]` | Server connection reused after each transaction |
| `max_client_conn` | `1000` | `[SETTING]` | Max concurrent application connections |
| `default_pool_size` | `50` | `[SETTING]` | Actual PostgreSQL backend connections per DB |
| `auth_type` | `scram-sha-256` | `[SETTING]` | Secure client password verification |
| `auth_file` | `/etc/pgbouncer/userlist.txt` | `[SETTING]` | Authorized client credentials |


### File: `haproxy.cfg` — HAProxy Configuration for PostgreSQL HA
HAProxy is a load balancer that routes application connections to the correct PostgreSQL node. For writes, it routes to the primary. For reads, it can distribute across standbys. Patroni provides health check endpoints that HAProxy uses to know which node is the primary. Crucially, parameters marked RESTART require stopping and restarting PostgreSQL, whereas parameters marked RELOAD take effect instantly with SELECT pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `frontend pg_write` | `bind *:5432` | `[SETTING]` | App write traffic entrypoint |
| `default_backend` | `pg_primary` | `[SETTING]` | Routes writes to current primary |
| `frontend pg_read` | `bind *:5433` | `[SETTING]` | Read-only traffic entrypoint |
| `default_backend` | `pg_replicas` | `[SETTING]` | Routes reads across standbys |
| `backend pg_primary` | `option httpchk GET /primary` | `[SETTING]` | Checks Patroni 8008 REST API |
| `server pg1` | `10.0.1.1:5432 check port 8008` | `[SETTING]` | Primary candidate node 1 |
| `server pg2` | `10.0.1.10:5432 check port 8008` | `[SETTING]` | Primary candidate node 2 |
| `backend pg_replicas` | `balance roundrobin` | `[SETTING]` | Distributes reads evenly across standbys |



---

## 5. Common Beginner Traps & How to Fix Them

### HA Beginner Traps
Here are the common beginner mistakes with HA setups.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary for this class. Patroni with etcd provides automatic failover with distributed consensus. PgBouncer pools connections to reduce PostgreSQL memory usage. HAProxy routes writes to the primary and reads to standbys using Patroni's REST API health checks. repmgr is a simpler alternative for smaller deployments. Always test failover before going to production. HA protects against crashes but not against data mistakes — you still need backups.

- **Patroni: automatic failover via leader election in etcd**
- **etcd: distributed consensus store (3+ nodes, odd number)**
- **PgBouncer: connection pooling (transaction mode recommended)**
- **HAProxy: load balancing + read/write port splitting**
- **Patroni REST API: /primary and /replica health checks**
- **patronictl: CLI for switchover, restart, cluster status**
- **repmgr: lighter alternative (no etcd, uses PG table)**
- **Pgpool-II: all-in-one alternative (more complex)**
- **App connects to HAProxy, not directly to PostgreSQL**
- **ALWAYS test failover before production launch**
- **HA ≠ backup — you still need pg_dump/pg_basebackup**
- **Phase 24 Complete!**


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
