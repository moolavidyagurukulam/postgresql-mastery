# EDB Tools — Postgres Enterprise Manager (PEM) & Failover Manager (EFM)
**Series:** PostgreSQL Mastery | **Phase:** 29 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. In this class, we explore two critical EDB enterprise tools — Postgres Enterprise Manager for monitoring and administration, and EDB Failover Manager for automatic high availability. These tools are what EDB adds beyond the database engine itself.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites
Before this class, you should understand PostgreSQL monitoring concepts — pg_stat views, logging, and basic replication. Familiarity with pgAdmin helps since PEM is built on top of pgAdmin.

| Term | Meaning / Explanation |
| :--- | :--- |
| **PG Monitoring** | pg_stat_activity, pg_stat_statements, log configuration |
| **Replication** | Streaming replication, primary/standby concepts — Phase 23 |
| **pgAdmin Basics** | PEM extends pgAdmin — knowing pgAdmin helps |
| **HA Concepts** | Failover, switchover, split-brain — Phase 24 |

### Postgres Enterprise Manager (PEM)
PEM is EDB's enterprise monitoring and management tool. Think of it as pgAdmin plus enterprise monitoring. It provides a web-based dashboard to monitor multiple PostgreSQL and EPAS servers. It tracks performance metrics, sends alerts when thresholds are crossed, runs scheduled probes that collect statistics, provides capacity planning charts, and includes a SQL Profiler for query analysis. PEM agents run on each monitored server and report back to the PEM server.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Type** | Web-based enterprise monitoring and management console |
| **Based On** | pgAdmin 4 + enterprise monitoring extensions |
| **Monitors** | Multiple PG/EPAS servers, all from one dashboard |
| **Features** | Alerts, probes, charts, SQL Profiler, audit logging, capacity planning |
| **Architecture** | PEM Server (central) + PEM Agents (one per monitored server) |
| **Access** | Web browser — roles control what each user sees |

### PEM Architecture
PEM has a central server that stores all monitoring data in its own PostgreSQL database. PEM agents run on each monitored database server. The agents collect metrics — CPU, memory, disk, connections, replication lag, query stats — and send them to the PEM server. Administrators connect to the PEM server through a web browser. Alerts are triggered when metrics cross defined thresholds.

```
[Web Browser
(Admin)]
[PEM Server
(Central DB + Web)]
[PEM Agent
+ PG Server 1]
[PEM Agent
+ PG Server 2]
[PEM Agent
+ PG Server 3]
```

### PEM Key Features
PEM provides several key features. The dashboard shows real-time metrics for all servers. Alert templates let you define thresholds — for example, alert when connections exceed 80 percent of max_connections, or when replication lag exceeds 10 seconds. Scheduled probes collect historical data for trend analysis. The SQL Profiler traces individual query execution. And the Performance Diagnostics dashboard shows the top SQL queries by wait events.

- Multi-Server Dashboard -- Monitor all PG/EPAS servers from one web UI. Server health, connections, transactions per second.
- Alerting System -- 50+ built-in alert templates. Custom thresholds. Email/SNMP notifications. Escalation rules.
- Scheduled Probes -- Agents collect stats on schedule. CPU, memory, disk I/O, table bloat, lock waits. Historical trends.
- SQL Profiler -- Trace query execution. See actual vs estimated rows. Find slow queries without pg_stat_statements.
- Audit Log Manager -- Configure and review pgAudit logs. Compliance reporting for SOX, HIPAA, PCI-DSS.
- Capacity Planning -- Predict when you will run out of disk, connections, or transaction IDs. Plan upgrades ahead.

### PEM vs Open Source Monitoring Stack
You do not need PEM — community PostgreSQL users build equivalent monitoring with open-source tools. Grafana plus Prometheus plus postgres_exporter gives you dashboards and alerting. pgAdmin gives you management. pg_stat_statements gives you query stats. But PEM combines all of this into one integrated product with vendor support. The trade-off is cost versus convenience.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Dashboard** | PEM (EDB): Built-in web UI | Open Source Stack: Grafana + dashboards |
| **Metrics Collection** | PEM (EDB): PEM Agent (built-in) | Open Source Stack: Prometheus + postgres_exporter |
| **Alerting** | PEM (EDB): Built-in templates | Open Source Stack: Grafana alerts or Alertmanager |
| **SQL Profiling** | PEM (EDB): SQL Profiler built-in | Open Source Stack: pg_stat_statements + auto_explain |
| **Management** | PEM (EDB): pgAdmin-based | Open Source Stack: pgAdmin 4 (free) |
| **Audit** | PEM (EDB): Built-in audit viewer | Open Source Stack: pgAudit + log parsing |
| **Setup Effort** | PEM (EDB): Install PEM (1 day) | Open Source Stack: Assemble stack (3-5 days) |
| **Cost** | PEM (EDB): EDB subscription | Open Source Stack: Free |
| **Support** | PEM (EDB): EDB 24/7 | Open Source Stack: Community |

### EDB Failover Manager (EFM)
EDB Failover Manager — EFM — is EDB's automatic failover solution for PostgreSQL high availability. It monitors the primary server and automatically promotes a standby to primary if the primary fails. EFM uses a consensus-based approach to avoid split-brain — multiple EFM agents must agree that the primary is truly down before triggering failover. It integrates with load balancers and connection poolers for seamless application failover.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Type** | Automatic failover manager for PostgreSQL HA clusters |
| **Monitors** | Primary server health. Promotes standby on primary failure. |
| **Consensus** | Multiple agents vote — prevents split-brain (majority must agree) |
| **Integration** | Updates VIP, load balancer, PgBouncer on failover |
| **Operations** | Automatic failover + manual switchover (planned) |
| **Alternative** | Community: Patroni (free, etcd-based) |

### EFM Cluster Architecture
EFM runs an agent on each PostgreSQL node — primary, standbys, and an optional witness node. The agents communicate with each other to monitor cluster health. If the primary becomes unreachable, the agents vote. If a majority agrees the primary is down, EFM promotes the healthiest standby, reconfigures the other standbys to follow the new primary, and updates the virtual IP address.

```
[Application
(VIP: 10.0.1.100)]
[Primary PG
+ EFM Agent]
[Standby PG
+ EFM Agent]
[Witness Node
+ EFM Agent]
```

### EFM vs Patroni
The main open-source alternative to EFM is Patroni, developed by Zalando. Patroni uses etcd, Consul, or ZooKeeper for consensus. EFM uses its own built-in consensus protocol. Both provide automatic failover and planned switchover. Patroni is free and widely adopted. EFM is included with EDB subscriptions and has vendor support. If you already use EDB, EFM integrates seamlessly. If you use community PostgreSQL, Patroni is the standard choice.

| Term | Meaning / Explanation |
| :--- | :--- |
| **License** | EFM (EDB): EDB subscription | Patroni (Open Source): Free (MIT) |
| **Consensus** | EFM (EDB): Built-in protocol | Patroni (Open Source): etcd / Consul / ZooKeeper |
| **Auto Failover** | EFM (EDB): Yes | Patroni (Open Source): Yes |
| **Planned Switchover** | EFM (EDB): Yes | Patroni (Open Source): Yes |
| **VIP Management** | EFM (EDB): Built-in | Patroni (Open Source): Callback scripts |
| **Witness Node** | EFM (EDB): Supported | Patroni (Open Source): Not needed (etcd quorum) |
| **Configuration** | EFM (EDB): Properties file | Patroni (Open Source): YAML file |
| **Community Adoption** | EFM (EDB): EDB customers | Patroni (Open Source): Very widely adopted |
| **Support** | EFM (EDB): EDB 24/7 | Patroni (Open Source): Community |
| **Best For** | EFM (EDB): EDB/EPAS shops | Patroni (Open Source): Community PG shops |

### Comparison
If this course is helping you understand enterprise PostgreSQL tools, please support us. Your donation keeps this content free. Links for PayPal and UPI are in the description.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials (.sql) |
| UPI: Link in description | All commands from this video |
| Every donation helps! | Practice exercises included |

### Beginner Traps
Watch out for these mistakes. First, PEM is powerful but adds complexity — if you only have one or two PostgreSQL servers, pgAdmin plus Grafana is simpler and free. Second, EFM requires an odd number of nodes for consensus — two nodes cannot determine a majority, so always have a witness. Third, do not confuse automatic failover with zero downtime — there is always a brief period where connections fail during the switchover.

- PEM overkill for small setups -- 1-2 servers? pgAdmin + Grafana is simpler and free. PEM shines at 5+ servers.
- EFM needs odd node count -- 2 nodes cannot reach majority. Always add a witness for 3-node consensus (primary + standby + witness).
- Failover ≠ zero downtime -- Connections drop during failover (typically 10-30 seconds). App must handle reconnection.
- Test failover regularly -- Untested failover is broken failover. Run failover drills monthly. Verify app reconnects.

### Practice Exercises
Here are your practice exercises. First, set up a Grafana plus Prometheus monitoring stack for community PostgreSQL — this is the free equivalent of PEM. Second, install Patroni with etcd on three nodes — this is the free equivalent of EFM. Third, simulate a primary failure and verify automatic failover completes. Fourth, compare the setup complexity of Patroni versus EFM if you have access to both.

- Exercise 1 -- Set up Grafana + Prometheus + postgres_exporter. Create a dashboard with connections, TPS, replication lag.
- Exercise 2 -- Install Patroni + etcd on 3 nodes (primary + standby + etcd). This is the free EFM equivalent.
- Exercise 3 -- Simulate primary failure (stop PostgreSQL). Verify Patroni/EFM promotes standby automatically.
- Exercise 4 -- If you have EDB trial: install PEM and EFM. Compare setup effort with Grafana + Patroni stack.


---

## 3. Hands-On Commands & psql Output

*(Refer to the attached `materials.sql` script for full runnable queries and setups for this topic.)*


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps
Watch out for these mistakes. First, PEM is powerful but adds complexity — if you only have one or two PostgreSQL servers, pgAdmin plus Grafana is simpler and free. Second, EFM requires an odd number of nodes for consensus — two nodes cannot determine a majority, so always have a witness. Third, do not confuse automatic failover with zero downtime — there is always a brief period where connections fail during the switchover.

- PEM overkill for small setups -- 1-2 servers? pgAdmin + Grafana is simpler and free. PEM shines at 5+ servers.
- EFM needs odd node count -- 2 nodes cannot reach majority. Always add a witness for 3-node consensus (primary + standby + witness).
- Failover ≠ zero downtime -- Connections drop during failover (typically 10-30 seconds). App must handle reconnection.
- Test failover regularly -- Untested failover is broken failover. Run failover drills monthly. Verify app reconnects.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review. PEM is EDB's enterprise monitoring tool — a web-based dashboard built on pgAdmin with alerting, probes, SQL Profiler, and capacity planning. The open-source equivalent is Grafana plus Prometheus. EFM is EDB's automatic failover manager — it monitors the primary and promotes a standby on failure using consensus voting. The open-source equivalent is Patroni. Both tools integrate seamlessly with EPAS. For community PostgreSQL, the open-source stack provides equivalent functionality at zero cost.

- **PEM: enterprise monitoring, alerting, SQL Profiler (built on pgAdmin)**
- **PEM architecture: central server + agents on each monitored node**
- **Open source equivalent: Grafana + Prometheus + postgres_exporter**
- **EFM: automatic failover with consensus-based promotion**
- **EFM architecture: agents on primary + standby + witness**
- **Open source equivalent: Patroni + etcd**
- **Both tools included with EDB subscription**
- **Test failover regularly — untested failover is broken failover**


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
