# Hands-On Projects: Multi-Tenant SaaS & Full HA Cluster
**Series:** PostgreSQL Mastery | **Phase:** 32 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. In this class, we build two advanced projects. First, a Multi-Tenant SaaS database — one database serving multiple customers with complete data isolation. Second, a full High Availability cluster with Patroni, etcd, and HAProxy — the production-grade setup that handles automatic failover.


---

## 2. Core Technical Concepts & Mechanisms

### Multi-Tenant Database Design
Multi-tenancy means one application and one database serving multiple customers — called tenants. Think of a project management SaaS — each company is a tenant. They share the same database but must never see each other's data. This is cheaper than running separate databases per customer but requires careful design. There are three main approaches — separate databases, separate schemas, or shared tables with a tenant ID column.

| Term | Meaning / Explanation |
| :--- | :--- |
| **What** | One database serving multiple customers (tenants) with complete data isolation. |
| **Why** | Cost efficiency. One server, one backup, one schema migration for all tenants. |
| **Approach 1: Separate databases** | Full isolation. Expensive. Hard to manage 1000+ databases. |
| **Approach 2: Separate schemas** | Good isolation. One DB, many schemas. Moderate management overhead. |
| **Approach 3: Shared tables** | All tenants in same tables. tenant_id column. Best scalability. Needs RLS. |
| **We will build** | Approach 3 (shared tables) with Row-Level Security for data isolation. |

### High Availability Cluster Architecture
Now the High Availability cluster. The architecture has four components. Patroni runs on each PostgreSQL node — it manages the database and handles promotion. etcd is the distributed consensus store — Patroni nodes register and coordinate through it. HAProxy is the load balancer — it routes writes to the primary and reads to standbys. The application connects to HAProxy, not directly to any PostgreSQL node.

```
[Application]
[HAProxy
(Load Balancer)]
[PG Node 1
(Primary)]
[PG Node 2
(Standby)]
[PG Node 3
(Standby)]
[etcd Cluster
(DCS)]
```

### Comparison
If this advanced HA cluster setup is helping you build production-grade PostgreSQL infrastructure, please support the course. The complete configuration files are available on GitHub for you to use in your own deployments.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Complete config files |
| UPI: Link in description | Patroni YAML template |
| Every donation helps! | HAProxy config template |

### Cluster Monitoring Checklist
Monitor the cluster with Patroni's REST API. Each node exposes port 8008. A GET to slash primary returns 200 if it is the leader, 503 otherwise. patronictl list shows the full status. Monitor etcd health separately — if etcd loses quorum, Patroni cannot coordinate and failover will not work. Set up alerts for: node down, lag above threshold, etcd unhealthy, and failover events.

- Patroni REST API — GET /primary → 200 (leader), 503 (not leader). GET /replica → 200 (standby).
- patronictl list — Shows all nodes, roles, state, and replication lag. Run from any node.
- etcd health — etcdctl endpoint health. Alert if any node unhealthy. 3-node quorum required.
- Replication lag — Alert at > 10s (warning), > 30s (critical). Check pg_stat_replication.
- Failover events — Monitor Patroni logs for 'promoted' events. Alert on every promotion.
- Connection count — Monitor via HAProxy stats page. Alert at 80% of max_connections.

### Beginner Traps
Critical traps. For multi-tenancy: never forget the WHERE tenant_id clause — use RLS to enforce it automatically. Never make tenant_id nullable — every row must belong to a tenant. For HA clusters: never run etcd on the same servers as PostgreSQL — etcd needs stable latency. Never skip failover testing — test monthly. Never set maximum_lag_on_failover too low — it prevents promotion. And never connect directly to PostgreSQL nodes — always go through HAProxy.

- Forgetting tenant_id filter — Without RLS, one missing WHERE clause leaks all tenants' data. Always use RLS.
- Nullable tenant_id — A row without tenant_id is invisible to all tenants. Never nullable.
- etcd on PG servers — etcd needs stable I/O. PG disk spikes cause etcd timeouts → false failovers.
- Never testing failover — Test monthly: stop primary, verify promotion, verify app recovery. Document timing.
- Direct PG connections — If app connects directly to node1, failover to node2 breaks the app. Use HAProxy.

### Practice Exercises
Practice exercises. First, build the multi-tenant schema with tenants, users, projects, and tasks. Enable RLS. Insert data for 3 tenants. Test that each tenant sees only their own data. Second, set up a 3-node PostgreSQL cluster with Patroni and etcd. Can be done on one machine with different ports. Third, configure HAProxy to route writes and reads. Fourth, test failover — stop the primary. Verify automatic promotion under 30 seconds.

- Exercise 1 — Create multi-tenant schema. Enable RLS. 3 tenants. Verify isolation with SET app.current_tenant.
- Exercise 2 — Add tenant_id indexes to all tables. EXPLAIN a query — verify index scan with tenant filter.
- Exercise 3 — Set up Patroni + etcd cluster (3 nodes, can use different ports on one machine).
- Exercise 4 — Configure HAProxy: port 5000 (writes) and 5001 (reads). Test with psql connections.
- Exercise 5 — Kill the primary. Measure failover time. Verify app reconnects. Restart old primary as standby.


---

## 3. Hands-On Commands & psql Output

### Multi-Tenant Schema
**Explanation:** Every table gets a tenant_id column. This is the tenant identifier — which company owns this row. We create a tenants table to store company information. Then the application tables — projects and tasks — each include tenant_id as a foreign key. We add tenant_id to every index and every unique constraint. The rule is simple: every query must filter by tenant_id.

```sql
CREATE TABLE tenants (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    slug VARCHAR(50) UNIQUE NOT NULL,
    plan VARCHAR(20) DEFAULT 'free'
        CHECK (plan IN
        ('free','starter','pro','enterprise')),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    tenant_id INT NOT NULL REFERENCES tenants(id),
    email VARCHAR(200) NOT NULL,
    name VARCHAR(200) NOT NULL,
    role VARCHAR(20) DEFAULT 'member',
    UNIQUE(tenant_id, email)
);

CREATE TABLE projects (
    id SERIAL PRIMARY KEY,
    tenant_id INT NOT NULL REFERENCES tenants(id),
    name VARCHAR(200) NOT NULL,
    owner_id INT REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE tasks (
    id SERIAL PRIMARY KEY,
    tenant_id INT NOT NULL REFERENCES tenants(id),
    project_id INT NOT NULL REFERENCES projects(id),
    title VARCHAR(300) NOT NULL,
    status VARCHAR(20) DEFAULT 'todo',
    assigned_to INT REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT now()
);
```

### Row-Level Security for Tenants
**Explanation:** Row-Level Security is the key to multi-tenancy. We enable RLS on every table. Then we create a policy — each user can only see rows where tenant_id matches their own tenant. The application sets a session variable — app.current_tenant — when the user logs in. PostgreSQL automatically filters every query to show only that tenant's data. Even if the application has a bug, RLS prevents data leakage.

```sql
-- Enable RLS on all tenant tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- Create policies: see only your tenant's data
CREATE POLICY tenant_isolation ON users
    USING (tenant_id =
        current_setting('app.current_tenant')::int);

CREATE POLICY tenant_isolation ON projects
    USING (tenant_id =
        current_setting('app.current_tenant')::int);

CREATE POLICY tenant_isolation ON tasks
    USING (tenant_id =
        current_setting('app.current_tenant')::int);

-- Application sets tenant on each connection:
-- SET app.current_tenant = '42';

-- Create app role (RLS applies to non-superusers)
CREATE ROLE app_user LOGIN;
GRANT SELECT, INSERT, UPDATE, DELETE
    ON ALL TABLES IN SCHEMA public TO app_user;
GRANT USAGE ON ALL SEQUENCES
    IN SCHEMA public TO app_user;
```

### Testing Tenant Isolation
**Explanation:** Let us test the isolation. We insert data for two tenants — Acme Corp and Beta Inc. Then we connect as the app_user role and set the current tenant to 1 — Acme Corp. When we query users, we only see Acme's users. When we query tasks, we only see Acme's tasks. Beta's data is completely invisible. Even a SELECT star without any WHERE clause only returns the current tenant's rows.

```sql
-- Insert test data for two tenants
myapp=> INSERT INTO tenants (name, slug) VALUES
('Acme Corp', 'acme'), ('Beta Inc', 'beta');
myapp=> INSERT INTO users (tenant_id, email, name) VALUES
(1, 'alice@acme.com', 'Alice'),
(2, 'bob@beta.com', 'Bob');

-- Connect as app_user, set tenant
app_user=> SET app.current_tenant = '1';
app_user=> SELECT * FROM users;
 id | tenant_id | email          | name
----+-----------+----------------+-------
  1 |         1 | alice@acme.com | Alice
(1 row) -- Bob is INVISIBLE!
```

### Multi-Tenant Performance
**Explanation:** For performance with multi-tenancy, every index must include tenant_id as the first column. This ensures that queries for one tenant scan only that tenant's portion of the index. Use composite indexes — tenant_id plus the columns you query. Partition large tables by tenant_id for very large deployments. And monitor per-tenant usage to identify tenants that consume disproportionate resources.

```sql
-- Every index includes tenant_id first
CREATE INDEX idx_users_tenant
    ON users(tenant_id);
CREATE INDEX idx_projects_tenant
    ON projects(tenant_id, created_at DESC);
CREATE INDEX idx_tasks_tenant_status
    ON tasks(tenant_id, status);
CREATE INDEX idx_tasks_tenant_project
    ON tasks(tenant_id, project_id);

-- For very large deployments: partition
CREATE TABLE tasks_partitioned (
    id SERIAL,
    tenant_id INT NOT NULL,
    title VARCHAR(300) NOT NULL,
    status VARCHAR(20) DEFAULT 'todo'
) PARTITION BY HASH (tenant_id);

CREATE TABLE tasks_p0
    PARTITION OF tasks_partitioned
    FOR VALUES WITH (modulus 4, remainder 0);
CREATE TABLE tasks_p1
    PARTITION OF tasks_partitioned
    FOR VALUES WITH (modulus 4, remainder 1);
-- ... (4 partitions spread tenants evenly)
```

### etcd Cluster Setup (3 nodes)
**Explanation:** etcd is the foundation. It stores the cluster state — who is the primary, who are the standbys, and their health. For production, run 3 etcd nodes for quorum — if one dies, the other two maintain consensus. We configure a 3-node etcd cluster. Each node knows the other nodes. Patroni reads and writes the cluster state here.

```sql
# Install etcd on all 3 nodes
$ sudo apt install etcd

# /etc/default/etcd on node 1 (10.0.1.30):
ETCD_NAME="etcd1"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_ADVERTISE_CLIENT_URLS="http://10.0.1.30:2379"
ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://10.0.1.30:2380"
ETCD_INITIAL_CLUSTER="etcd1=http://10.0.1.30:2380,etcd2=http://10.0.1.31:2380,etcd3=http://10.0.1.32:2380"

$ sudo systemctl start etcd
$ etcdctl member list
etcd1: http://10.0.1.30:2380 (healthy)
etcd2: http://10.0.1.31:2380 (healthy)
etcd3: http://10.0.1.32:2380 (healthy)
```

### HAProxy Configuration
**Explanation:** HAProxy routes traffic to the correct PostgreSQL node. It checks Patroni's REST API on port 8008. The primary endpoint returns 200 for the leader — HAProxy routes writes here. The replica endpoint returns 200 for standbys — HAProxy routes reads here. If the primary fails and Patroni promotes a standby, HAProxy automatically detects the change through the health checks and routes traffic to the new primary.

```sql
# /etc/haproxy/haproxy.cfg
listen pg_primary
    bind *:5000
    option httpchk GET /primary
    http-check expect status 200
    default-server inter 3s fall 3 rise 2
    server node1 10.0.1.10:5432 check port 8008
    server node2 10.0.1.20:5432 check port 8008
    server node3 10.0.1.25:5432 check port 8008

listen pg_replicas
    bind *:5001
    balance roundrobin
    option httpchk GET /replica
    http-check expect status 200
    default-server inter 3s fall 3 rise 2
    server node1 10.0.1.10:5432 check port 8008
    server node2 10.0.1.20:5432 check port 8008
    server node3 10.0.1.25:5432 check port 8008
```

### Start Cluster and Verify
**Explanation:** Start Patroni on each node. The first node bootstraps — it initializes PostgreSQL and becomes the primary. The second and third nodes join as standbys — Patroni runs pg_basebackup automatically. Use patronictl list to see the cluster status — one Leader and two Replicas. The application connects to HAProxy port 5000 for writes and port 5001 for reads.

```sql
# Start Patroni on each node
node1$ sudo systemctl start patroni
node2$ sudo systemctl start patroni
node3$ sudo systemctl start patroni

# Check cluster status
$ patronictl -c /etc/patroni/patroni.yml list
+ Cluster: pg-cluster -----+--------+---------+-----+
| Member | Host       | Role    | State   | Lag  |
+--------+------------+---------+---------+------+
| node1  | 10.0.1.10  | Leader  | running |      |
| node2  | 10.0.1.20  | Replica | running |    0 |
| node3  | 10.0.1.25  | Replica | running |    0 |
+--------+------------+---------+---------+------+

# App connects through HAProxy:
$ psql -h haproxy-host -p 5000 -U app_user myapp
-- Connected to primary (writes)
```

### Testing Automatic Failover
**Explanation:** The real test — kill the primary and watch Patroni handle it. We stop Patroni on node1. Within 30 seconds, Patroni detects the leader is gone. etcd's TTL expires. The most up-to-date standby — say node2 — is promoted to Leader. HAProxy detects the change through health checks and routes writes to node2. The application might see a brief connection error, then reconnects to the new primary. Zero manual intervention.

```sql
# Kill the primary
node1$ sudo systemctl stop patroni

# Wait ~30 seconds, then check cluster
$ patronictl -c /etc/patroni/patroni.yml list
+ Cluster: pg-cluster -----+--------+---------+-----+
| Member | Host       | Role    | State   | Lag  |
+--------+------------+---------+---------+------+
| node1  | 10.0.1.10  |         | stopped |      |
| node2  | 10.0.1.20  | Leader  | running |      |
| node3  | 10.0.1.25  | Replica | running |    0 |
+--------+------------+---------+---------+------+

# node2 is now the Leader! Automatic promotion.
# HAProxy routes writes to node2 automatically.
# Restart node1 — it rejoins as Replica:
node1$ sudo systemctl start patroni
```

### Planned Switchover (Zero Downtime)
**Explanation:** For planned maintenance, use patronictl switchover instead of stopping the primary. Switchover is graceful — Patroni drains connections, promotes the target standby, then demotes the old primary to standby. Zero data loss. The application sees a sub-second interruption. Use this for PostgreSQL upgrades, hardware maintenance, or rebalancing the cluster.

```sql
$ patronictl -c /etc/patroni/patroni.yml switchover
Current cluster topology
+ Cluster: pg-cluster -----+--------+---------+
| Member | Role    | State   |
| node2  | Leader  | running |
| node3  | Replica | running |
+--------+---------+---------+

Primary [node2]:
Candidate ['node3']:
When [now]:
Are you sure you want to switchover? [y/N]: y

Successfully switched over to "node3"
| node2  | Replica | running |    0 |
| node3  | Leader  | running |      |
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf` — Patroni Configuration (patroni.yml)
Patroni configuration goes in patroni.yml on each PostgreSQL node. The key sections: scope names the cluster, name identifies this node. restapi exposes Patroni's health check endpoint. etcd3 points to the etcd cluster. bootstrap sets the initial PostgreSQL configuration. And postgresql defines listen addresses and the data directory. Each node has the same config except for its name and listen addresses.

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `scope` | `pg-cluster` | `[SETTING]` | Cluster name — same on all nodes |
| `name` | `node1` | `[SETTING]` | Unique name for this node (node1, node2, node3) |
| `restapi.listen` | `0.0.0.0:8008` | `[SETTING]` | Health check API — HAProxy queries this |
| `etcd3.hosts` | `10.0.1.30:2379,10.0.1.31:2379` | `[SETTING]` | etcd endpoints for DCS |
| `bootstrap.dcs.ttl` | `30` | `[SETTING]` | Leader key TTL in seconds |
| `bootstrap.dcs.loop_wait` | `10` | `[SETTING]` | Patroni check interval |
| `bootstrap.dcs.maximum_lag_on_failover` | `1048576` | `[SETTING]` | Max 1MB lag for failover candidate |
| `postgresql.listen` | `0.0.0.0:5432` | `[SETTING]` | PostgreSQL listen address |
| `postgresql.data_dir` | `/var/lib/postgresql/16/main` | `[SETTING]` | Data directory path |



---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps
Critical traps. For multi-tenancy: never forget the WHERE tenant_id clause — use RLS to enforce it automatically. Never make tenant_id nullable — every row must belong to a tenant. For HA clusters: never run etcd on the same servers as PostgreSQL — etcd needs stable latency. Never skip failover testing — test monthly. Never set maximum_lag_on_failover too low — it prevents promotion. And never connect directly to PostgreSQL nodes — always go through HAProxy.

- Forgetting tenant_id filter — Without RLS, one missing WHERE clause leaks all tenants' data. Always use RLS.
- Nullable tenant_id — A row without tenant_id is invisible to all tenants. Never nullable.
- etcd on PG servers — etcd needs stable I/O. PG disk spikes cause etcd timeouts → false failovers.
- Never testing failover — Test monthly: stop primary, verify promotion, verify app recovery. Document timing.
- Direct PG connections — If app connects directly to node1, failover to node2 breaks the app. Use HAProxy.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Summary. Multi-tenant SaaS: shared tables with tenant_id on every row, Row-Level Security for automatic data isolation, composite indexes with tenant_id first, hash partitioning for very large deployments. HA Cluster: Patroni manages PostgreSQL lifecycle and failover, etcd stores cluster state with 3-node quorum, HAProxy routes writes to primary and reads to standbys, automatic failover under 30 seconds. Test monthly. This is the production-grade PostgreSQL stack used by companies worldwide.

- **Multi-tenant: tenant_id on every table, never nullable**
- **Row-Level Security: automatic isolation, prevents data leakage**
- **Composite indexes: tenant_id first column in every index**
- **Hash partitioning for 1000+ tenants on large tables**
- **HA: Patroni + etcd + HAProxy = automatic failover < 30 seconds**
- **etcd: 3-node quorum, never on PG servers, stable I/O**
- **HAProxy: port 5000 writes (primary), port 5001 reads (replicas)**
- **Test failover monthly — a plan never tested will fail**


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
