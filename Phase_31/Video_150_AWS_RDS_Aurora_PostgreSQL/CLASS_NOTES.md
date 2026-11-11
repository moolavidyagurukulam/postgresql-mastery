# AWS RDS & Aurora PostgreSQL — Setup, Features, and Management
**Series:** PostgreSQL Mastery | **Phase:** 31 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. In this class, we cover AWS RDS PostgreSQL and Aurora PostgreSQL — Amazon's two managed PostgreSQL services. You will learn how to create instances, configure them, manage backups, scale, and understand when to choose RDS versus Aurora.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites
Before this class, you should understand PostgreSQL administration — installation, configuration, backup, replication, and monitoring from earlier phases. You need an AWS account. All AWS CLI examples use the aws rds commands. You should also understand the Terraform concepts from the previous class.

| Term | Meaning / Explanation |
| :--- | :--- |
| **PG Administration** | Install, configure, backup, replication — Phases 2-24 |
| **AWS Account** | Free tier available for db.t3.micro (750 hours/month) |
| **AWS CLI** | Install and configure with aws configure |
| **Terraform** | Optional — from previous class for IaC approach |

### Comparison
A managed PostgreSQL service means AWS handles the infrastructure — server provisioning, patching, backups, failover, and monitoring. You focus on your application and data. You lose some control — no SSH access, no custom extensions without approval, limited postgresql.conf parameters. But you gain operational simplicity, automated backups, one-click scaling, and high availability.

| AWS Manages For You | You Still Manage |
| :--- | :--- |
| Server provisioning and OS patching | Schema design and queries |
| Automated daily backups (35 days) | Index creation and tuning |
| Minor version upgrades | Connection pooling (PgBouncer) |
| Multi-AZ failover (< 60 seconds) | Application-level optimization |
| Monitoring (CloudWatch) | Parameter group tuning |
| Storage scaling (auto-grow) | Major version upgrades (plan them) |

### RDS PostgreSQL — Key Features
RDS PostgreSQL provides several key features. Automated backups take daily snapshots and store transaction logs for point-in-time recovery up to 35 days. Multi-AZ deploys a synchronous standby in another availability zone — failover is automatic in under 60 seconds. Read replicas scale read traffic — you can create up to 15 replicas. Parameter groups let you customize postgresql.conf settings without SSH access.

- Automated Backups -- Daily snapshots + transaction logs. PITR up to 35 days. Stored in S3 automatically.
- Multi-AZ (High Availability) -- Synchronous standby in another AZ. Auto failover < 60 seconds. Same endpoint.
- Read Replicas -- Up to 15 async replicas for read scaling. Can be in different regions. Promote to standalone.
- Parameter Groups -- Custom postgresql.conf via parameter groups. shared_buffers, work_mem, max_connections.
- Storage Auto-Scaling -- Enable auto-scaling. Storage grows automatically when usage hits threshold. gp3 or io2.
- Encryption -- At-rest (KMS) and in-transit (SSL). Enable at creation — cannot add later.

### Aurora PostgreSQL — Key Differences
Aurora PostgreSQL is Amazon's cloud-native rewrite of PostgreSQL. It uses the same PostgreSQL engine for queries but replaces the storage layer with a distributed, fault-tolerant storage system. Aurora storage replicates data six times across three availability zones automatically. This makes Aurora faster for write-heavy workloads, more durable, and simpler to manage than standard RDS. But it costs more.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Engine** | Same PostgreSQL query engine — compatible with PG 13-16 |
| **Storage** | Distributed, auto-scaling up to 128 TB. 6 copies across 3 AZs. |
| **Write Performance** | Up to 3x faster than RDS PG (reduced write amplification) |
| **Failover** | < 30 seconds (faster than RDS Multi-AZ) |
| **Read Replicas** | Up to 15 replicas sharing same storage (no replication lag) |
| **Cost** | ~20% more than RDS for same instance class + I/O-based pricing |

### Aurora PostgreSQL Architecture
Aurora's architecture separates compute from storage. The writer instance handles all writes. Up to 15 reader instances share the same storage volume — they do not need to replicate data because they read directly from the shared storage. If the writer fails, Aurora promotes a reader in under 30 seconds. The storage layer handles replication across availability zones — you never manage standby servers.

```
[Application]
[Writer
Instance]
[Reader 1]
[Reader 2]
[Shared Storage (6 copies, 3 AZs, auto-scales to 128 TB)]
```

### Comparison
If this cloud PostgreSQL guide is helping you make the right choices, please support the course. Your donation keeps this content free. Links for PayPal and UPI are in the description.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials (.sql) |
| UPI: Link in description | AWS CLI commands included |
| Every donation helps! | Practice exercises included |

### RDS vs Aurora PostgreSQL
Choose RDS PostgreSQL when cost matters most, your workload is moderate, and you do not need the fastest failover. Choose Aurora when you need high write throughput, fast failover under 30 seconds, or many read replicas sharing the same storage. Aurora Serverless v2 is ideal for variable workloads — it scales down to save money during off-peak hours and scales up automatically under load.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Storage** | RDS PostgreSQL: EBS (gp3/io2) | Aurora PostgreSQL: Shared, auto-scale to 128 TB |
| **Write Speed** | RDS PostgreSQL: Standard | Aurora PostgreSQL: Up to 3x faster |
| **Failover Time** | RDS PostgreSQL: < 60 seconds | Aurora PostgreSQL: < 30 seconds |
| **Read Replicas** | RDS PostgreSQL: Up to 15 (async) | Aurora PostgreSQL: Up to 15 (shared storage) |
| **Replica Lag** | RDS PostgreSQL: Seconds to minutes | Aurora PostgreSQL: Milliseconds (shared storage) |
| **Cost** | RDS PostgreSQL: Lower | Aurora PostgreSQL: ~20% more + I/O charges |
| **Serverless** | RDS PostgreSQL: No | Aurora PostgreSQL: Serverless v2 (auto-scale) |
| **Best For** | RDS PostgreSQL: Cost-sensitive, moderate load | Aurora PostgreSQL: High throughput, fast failover |

### RDS Monitoring — Key Metrics
RDS publishes metrics to CloudWatch automatically — CPU utilization, free storage, database connections, read and write IOPS, replication lag, and more. Enable Enhanced Monitoring for OS-level metrics at 1-second granularity. Enable Performance Insights to see which queries are consuming the most time — it is the cloud equivalent of pg_stat_statements with a visual dashboard.

- CPUUtilization -- Alert at 80%. Sustained high CPU = scale up instance class or optimize queries.
- FreeStorageSpace -- Alert at 20% remaining. Enable storage auto-scaling to prevent disk full.
- DatabaseConnections -- Alert at 80% of max_connections. Add PgBouncer if approaching limit.
- ReadIOPS / WriteIOPS -- Monitor I/O patterns. Switch from gp3 to io2 if hitting IOPS limits.
- ReplicaLag -- For read replicas. Alert if lag > 10 seconds. Check write volume.
- Performance Insights -- Enable it. Shows top queries by wait events. Free for 7-day retention.

### Beginner Traps
Watch out for these traps. First, enable encryption at creation — you cannot add it later without creating a new instance. Second, RDS is not accessible from the internet by default — you must configure the VPC security group to allow your application's IP. Third, always test major version upgrades on a snapshot restore first — never upgrade production directly. Fourth, Aurora I/O charges can surprise you — monitor I/O costs separately from compute.

- Encryption: enable at creation -- Cannot add encryption to existing instance. Must create new encrypted instance and migrate.
- VPC security groups -- RDS is private by default. Configure security group to allow your app's CIDR. Never open 0.0.0.0/0.
- Major upgrades: test first -- Restore snapshot → upgrade → test → then upgrade production. Never upgrade production directly.
- Aurora I/O costs -- Aurora charges per million I/O requests. High-IOPS workloads can get expensive. Monitor billing.
- No superuser access -- RDS master user is NOT superuser. Some operations need rds_superuser role. CREATE EXTENSION works.

### Practice Exercises
Here are your practice exercises. First, create an RDS PostgreSQL instance using the AWS CLI or Console — use the free tier db.t3.micro. Connect with psql. Second, create a custom parameter group and modify shared_buffers and work_mem. Third, enable automated backups and perform a point-in-time restore. Fourth, create a read replica and test reading from it. Fifth, if budget allows, create an Aurora cluster and compare failover time with RDS Multi-AZ.

- Exercise 1 -- Create RDS PostgreSQL (free tier: db.t3.micro, 20GB). Connect with psql. Create a test table.
- Exercise 2 -- Create custom parameter group. Set shared_buffers, work_mem, log_statement. Apply to instance.
- Exercise 3 -- Enable automated backups. Insert data. Perform point-in-time restore to 5 minutes ago.
- Exercise 4 -- Create a read replica. Connect to it. Verify it has the same data. Test that writes are rejected.
- Exercise 5 -- Optional: Create Aurora cluster (writer + reader). Compare failover time with RDS Multi-AZ.


---

## 3. Hands-On Commands & psql Output

### AWS CLI — Create RDS PostgreSQL
**Explanation:** Create an RDS PostgreSQL instance with the AWS CLI. Specify the engine version, instance class, storage, credentials, and whether you want Multi-AZ for high availability. The instance takes about 10 minutes to create. AWS assigns an endpoint — a DNS name — that your application connects to. You can also create instances through the AWS Console or Terraform.

```sql
$ aws rds create-db-instance \
  --db-instance-identifier myapp-pg \
  --engine postgres \
  --engine-version 16.4 \
  --db-instance-class db.t3.medium \
  --allocated-storage 50 \
  --storage-type gp3 \
  --master-username app_admin \
  --master-user-password 'SecurePass123!' \
  --multi-az \
  --backup-retention-period 7 \
  --db-name myapp

DBInstance: myapp-pg | Status: creating
```

### RDS — Common CLI Operations
**Explanation:** Here are the AWS CLI commands you will use daily. Check the instance status with describe-db-instances. Create a manual snapshot before risky changes. Restore to a point in time when data is corrupted. Modify instance class to scale vertically. Create read replicas for read scaling. These operations take minutes, not hours.

```sql
# Check instance status
$ aws rds describe-db-instances --db-instance-identifier myapp-pg --query 'DBInstances[0].DBInstanceStatus'
"available"

# Create manual snapshot
$ aws rds create-db-snapshot --db-instance-identifier myapp-pg --db-snapshot-identifier myapp-pre-upgrade

# Point-in-time restore
$ aws rds restore-db-instance-to-point-in-time --source-db-instance-identifier myapp-pg --target-db-instance-identifier myapp-restored --restore-time 2026-11-05T10:00:00Z

# Create read replica
$ aws rds create-db-instance-read-replica --db-instance-identifier myapp-read1 --source-db-instance-identifier myapp-pg
```

### AWS CLI — Create Aurora PostgreSQL Cluster
**Explanation:** Aurora uses clusters — a writer instance plus optional reader instances sharing storage. Create the cluster first, then add instances. The cluster endpoint always points to the writer. The reader endpoint load-balances across readers. Aurora Serverless v2 can scale instances automatically based on load — you pay only for the compute you use.

```sql
$ aws rds create-db-cluster \
  --db-cluster-identifier myapp-aurora \
  --engine aurora-postgresql \
  --engine-version 16.4 \
  --master-username app_admin \
  --master-user-password 'SecurePass123!' \
  --database-name myapp \
  --backup-retention-period 7

# Add writer instance
$ aws rds create-db-instance --db-instance-identifier myapp-writer --db-cluster-identifier myapp-aurora --engine aurora-postgresql --db-instance-class db.r6g.large

# Add reader instance
$ aws rds create-db-instance --db-instance-identifier myapp-reader1 --db-cluster-identifier myapp-aurora --engine aurora-postgresql --db-instance-class db.r6g.large
```

### RDS — Custom Parameter Group
**Explanation:** You cannot SSH into RDS to edit postgresql.conf. Instead, you use parameter groups. A parameter group is a named collection of PostgreSQL settings. Create a custom group, set your parameters, and attach it to your instance. Dynamic parameters apply immediately. Static parameters require a reboot. Always create a custom parameter group — do not modify the default one.

```sql
$ aws rds create-db-parameter-group \
  --db-parameter-group-name myapp-pg16 \
  --db-parameter-group-family postgres16 \
  --description 'Custom PG 16 settings'

$ aws rds modify-db-parameter-group \
  --db-parameter-group-name myapp-pg16 \
  --parameters \
  'ParameterName=shared_buffers,ParameterValue={DBInstanceClassMemory/4},ApplyMethod=pending-reboot' \
  'ParameterName=work_mem,ParameterValue=16384,ApplyMethod=immediate' \
  'ParameterName=log_statement,ParameterValue=ddl,ApplyMethod=immediate'
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps
Watch out for these traps. First, enable encryption at creation — you cannot add it later without creating a new instance. Second, RDS is not accessible from the internet by default — you must configure the VPC security group to allow your application's IP. Third, always test major version upgrades on a snapshot restore first — never upgrade production directly. Fourth, Aurora I/O charges can surprise you — monitor I/O costs separately from compute.

- Encryption: enable at creation -- Cannot add encryption to existing instance. Must create new encrypted instance and migrate.
- VPC security groups -- RDS is private by default. Configure security group to allow your app's CIDR. Never open 0.0.0.0/0.
- Major upgrades: test first -- Restore snapshot → upgrade → test → then upgrade production. Never upgrade production directly.
- Aurora I/O costs -- Aurora charges per million I/O requests. High-IOPS workloads can get expensive. Monitor billing.
- No superuser access -- RDS master user is NOT superuser. Some operations need rds_superuser role. CREATE EXTENSION works.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review. AWS RDS PostgreSQL is a managed service — AWS handles patching, backups, failover, and monitoring. Aurora PostgreSQL replaces the storage layer with a distributed system — faster writes, faster failover, shared storage for replicas. Use RDS for cost-sensitive workloads and Aurora for high-performance needs. Enable encryption at creation, use parameter groups for configuration, and monitor with CloudWatch and Performance Insights.

- **RDS PostgreSQL: managed PG on EBS storage, Multi-AZ failover < 60s**
- **Aurora PostgreSQL: shared distributed storage, failover < 30s, 3x faster writes**
- **Automated backups: daily snapshots + PITR up to 35 days**
- **Read replicas: up to 15 (RDS: async, Aurora: shared storage)**
- **Parameter groups replace postgresql.conf (no SSH access)**
- **Enable encryption at creation — cannot add later**
- **Performance Insights: free query analysis dashboard**
- **Aurora costs ~20% more + I/O charges — monitor billing**


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
