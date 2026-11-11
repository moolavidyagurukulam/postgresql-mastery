# Crunchy Data, Percona & Choosing a PostgreSQL Distribution
**Series:** PostgreSQL Mastery | **Phase:** 29 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. In this class, we explore Crunchy Data and Percona — two more major PostgreSQL distributions — and then build a decision framework to help you choose the right distribution for your organization.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites
Before this class, you should have completed the previous classes in Phase 29 covering community PostgreSQL, EDB EPAS, and EDB tools. Understanding those options makes the comparison meaningful.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Phase 29 Videos** | Community PG vs EDB vs Cloud, EPAS, PEM, EFM, BART, pgd |
| **PG Administration** | Install, configure, backup, replication — Phases 1-28 |
| **Kubernetes Awareness** | Helpful for Crunchy's PGO operator (not required) |

### Crunchy Data
Crunchy Data is a PostgreSQL company focused on Kubernetes-native PostgreSQL and open-source tooling. Their key product is PGO — the Crunchy Postgres Operator for Kubernetes — which automates PostgreSQL deployment, scaling, backup, and failover on Kubernetes. They also offer Crunchy Bridge, a managed PostgreSQL cloud service, and pgMonitor for monitoring. Crunchy is known for contributing to the PostgreSQL community and keeping everything open source.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Focus** | Kubernetes-native PostgreSQL, open-source tools, managed cloud |
| **PGO (Operator)** | Kubernetes operator for automated PG deployment, HA, backup, scaling |
| **Crunchy Bridge** | Managed PostgreSQL cloud service (AWS, Azure, GCP) |
| **pgMonitor** | Open-source monitoring stack (Prometheus + Grafana dashboards) |
| **Philosophy** | 100% open source. No proprietary features. Community PostgreSQL. |
| **Best For** | Kubernetes deployments, cloud-native teams, open-source advocates |

### Crunchy PGO — What It Automates
PGO is Crunchy's Kubernetes operator for PostgreSQL. You define your desired database cluster in a YAML file — how many replicas, how much storage, backup schedule — and PGO creates and manages it. It handles high availability with automatic failover, automated backups using pgBackRest, connection pooling with PgBouncer, monitoring integration, and rolling upgrades. If a pod crashes, PGO recreates it automatically.

- Cluster Deployment -- Define PG cluster in YAML. PGO creates pods, PVCs, services, secrets. One command.
- High Availability -- Automatic failover using Patroni. Standby promotion if primary pod dies.
- Automated Backups -- pgBackRest integrated. Scheduled full + incremental. S3/GCS/Azure storage.
- Connection Pooling -- PgBouncer sidecar deployed automatically. Configured per cluster.
- Monitoring -- Prometheus exporter + Grafana dashboards included (pgMonitor).
- Rolling Upgrades -- Minor version upgrade with zero downtime. PGO handles pod rotation.

### Percona Distribution for PostgreSQL
Percona is known for their MySQL expertise, but they also offer a PostgreSQL distribution. Percona Distribution for PostgreSQL bundles community PostgreSQL with carefully tested extensions — pg_stat_monitor for enhanced query stats, pgAudit for compliance logging, pgBackRest for backup, Patroni for HA, and pgBouncer for connection pooling. Everything is open source, tested together, and supported by Percona.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Type** | Community PG + curated extensions bundle, tested and supported |
| **Includes** | pg_stat_monitor, pgAudit, pgBackRest, Patroni, PgBouncer, HAProxy |
| **Operators** | Percona Operator for Kubernetes (similar to Crunchy PGO) |
| **PMM** | Percona Monitoring and Management (web UI for PG, MySQL, MongoDB) |
| **Philosophy** | 100% open source. No proprietary features. Supported bundle. |
| **Best For** | Teams wanting a tested open-source bundle with vendor support |

### Percona PMM vs Other Monitoring
Percona Monitoring and Management — PMM — is Percona's free monitoring tool. Unlike PEM which only monitors PostgreSQL, PMM monitors PostgreSQL, MySQL, and MongoDB from one dashboard. It uses Prometheus, ClickHouse, and Grafana under the hood. For PostgreSQL specifically, it tracks query performance via pg_stat_monitor — an enhanced version of pg_stat_statements that captures query plans, histograms, and per-client stats.

| Term | Meaning / Explanation |
| :--- | :--- |
| **License** | PMM (Percona): Free (AGPL) | PEM (EDB): EDB subscription | DIY Grafana: Free |
| **PostgreSQL** | PMM (Percona): Yes | PEM (EDB): Yes | DIY Grafana: Yes (with exporter) |
| **MySQL/MongoDB** | PMM (Percona): Yes | PEM (EDB): No | DIY Grafana: Yes (with exporters) |
| **Query Stats** | PMM (Percona): pg_stat_monitor | PEM (EDB): SQL Profiler | DIY Grafana: pg_stat_statements |
| **Dashboards** | PMM (Percona): Pre-built Grafana | PEM (EDB): Built-in web UI | DIY Grafana: Custom Grafana |
| **Setup** | PMM (Percona): Docker one-liner | PEM (EDB): PEM install | DIY Grafana: Manual assembly |
| **Best For** | PMM (Percona): Multi-DB shops | PEM (EDB): EDB-only shops | DIY Grafana: Maximum control |

### All Distributions Compared
Now let us compare all four distributions side by side. Community PostgreSQL is the baseline — free, all features, you manage everything. EDB adds Oracle compatibility and enterprise tools. Crunchy focuses on Kubernetes and open source. Percona bundles tested extensions with multi-database monitoring. Here is the complete comparison.

| Term | Meaning / Explanation |
| :--- | :--- |
| **License** | Community: Free | EDB: Subscription | Crunchy: Free + Support | Percona: Free + Support |
| **Oracle Compat** | Community: No | EDB: Yes (EPAS) | Crunchy: No | Percona: No |
| **K8s Operator** | Community: No | EDB: EDB PGD | Crunchy: PGO (mature) | Percona: Operator (good) |
| **Monitoring** | Community: DIY | EDB: PEM | Crunchy: pgMonitor | Percona: PMM |
| **HA Tool** | Community: DIY Patroni | EDB: EFM | Crunchy: Patroni (PGO) | Percona: Patroni |
| **Backup Tool** | Community: DIY | EDB: BART/pgBR | Crunchy: pgBackRest | Percona: pgBackRest |
| **Managed Cloud** | Community: No | EDB: EDB BigAnimal | Crunchy: Crunchy Bridge | Percona: No |
| **Multi-DB Monitor** | Community: No | EDB: No | Crunchy: No | Percona: Yes (PG+MySQL+Mongo) |
| **Best For** | Community: DIY experts | EDB: Oracle shops | Crunchy: K8s teams | Percona: Multi-DB shops |

### Comparison
If this distribution comparison is helping you make the right choice, please support the course. Your donation keeps this content free. Links for PayPal and UPI are in the description.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials (.sql) |
| UPI: Link in description | All commands from this video |
| Every donation helps! | Practice exercises included |

### Beginner Traps
Watch out for these final traps. First, you do not need a commercial distribution to run PostgreSQL in production — community PostgreSQL powers some of the world's largest databases at Instagram, Spotify, and Apple. Second, do not choose a distribution just for support — community support through mailing lists and consultants is excellent. Third, all distributions use the same PostgreSQL engine — your data is not locked in. You can switch distributions with minimal effort.

- Community PG IS production-ready -- Instagram, Spotify, Apple run community PG at massive scale. You don't need a vendor to go to production.
- Support ≠ distribution -- You can buy support for community PG from EDB, Crunchy, Percona, 2ndQuadrant — without changing your PG install.
- Same engine underneath -- All distributions use the same PostgreSQL core. Switching from one to another is straightforward.
- Start simple, add later -- Start with community PG. Add Patroni for HA. Add pgBackRest for backup. Add Grafana for monitoring. Done.

### Practice Exercises
Here are your practice exercises. First, install Percona's pg_stat_monitor extension on community PostgreSQL — it works without the full Percona distribution. Second, deploy a PostgreSQL cluster on Kubernetes using Crunchy PGO — follow their quickstart guide. Third, install PMM using Docker and connect it to a PostgreSQL instance. Fourth, write a one-page recommendation for your team on which distribution to use, with justification.

- Exercise 1 -- Install pg_stat_monitor on community PG. Compare its output with pg_stat_statements.
- Exercise 2 -- Deploy PG on Kubernetes using Crunchy PGO quickstart. Create cluster, test failover.
- Exercise 3 -- Install PMM with Docker. Connect to PG instance. Explore the pre-built dashboards.
- Exercise 4 -- Write a 1-page recommendation: which distribution for your team? Include cost, features, team skills.


---

## 3. Hands-On Commands & psql Output

*(Refer to the attached `materials.sql` script for full runnable queries and setups for this topic.)*


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps
Watch out for these final traps. First, you do not need a commercial distribution to run PostgreSQL in production — community PostgreSQL powers some of the world's largest databases at Instagram, Spotify, and Apple. Second, do not choose a distribution just for support — community support through mailing lists and consultants is excellent. Third, all distributions use the same PostgreSQL engine — your data is not locked in. You can switch distributions with minimal effort.

- Community PG IS production-ready -- Instagram, Spotify, Apple run community PG at massive scale. You don't need a vendor to go to production.
- Support ≠ distribution -- You can buy support for community PG from EDB, Crunchy, Percona, 2ndQuadrant — without changing your PG install.
- Same engine underneath -- All distributions use the same PostgreSQL core. Switching from one to another is straightforward.
- Start simple, add later -- Start with community PG. Add Patroni for HA. Add pgBackRest for backup. Add Grafana for monitoring. Done.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review Phase 29. Community PostgreSQL is the foundation — all distributions build on it. EDB adds Oracle compatibility and enterprise tools — choose it for Oracle migrations. Crunchy Data focuses on Kubernetes-native PostgreSQL with PGO and open-source tooling — choose it for Kubernetes deployments. Percona bundles tested extensions with multi-database monitoring — choose it when you run PostgreSQL alongside MySQL or MongoDB. For most teams, community PostgreSQL with pgBackRest, Patroni, and Grafana is the recommended starting point.

- **Community PG: free, production-ready, used by Instagram/Spotify/Apple**
- **EDB: Oracle compatibility (EPAS) + enterprise tools (PEM, EFM)**
- **Crunchy Data: Kubernetes-native PGO operator + Crunchy Bridge cloud**
- **Percona: tested extension bundle + PMM multi-DB monitoring**
- **All use same PG core engine — no data lock-in between distributions**
- **Default recommendation: Community PG + pgBackRest + Patroni + Grafana**
- **Buy support separately if needed — from EDB, Crunchy, or Percona**


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
