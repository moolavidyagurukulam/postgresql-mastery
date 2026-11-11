# Azure & GCP Cloud PostgreSQL — Setup, Features, and Management
**Series:** PostgreSQL Mastery | **Phase:** 31 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. In this class, we cover Azure Database for PostgreSQL Flexible Server and Google Cloud SQL for PostgreSQL, plus Google's AlloyDB. You will learn how to create instances, configure them, and understand the unique features each cloud provider offers.


---

## 2. Core Technical Concepts & Mechanisms

### Azure Database for PostgreSQL — Flexible Server
Azure Database for PostgreSQL Flexible Server is Microsoft's managed PostgreSQL service. It replaced the older Single Server offering which was retired in 2025. Flexible Server gives you more control — you choose the compute tier, storage size, availability zone, and maintenance window. It supports PostgreSQL 13 through 16 and integrates with Azure's networking, monitoring, and identity services.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Service Type** | Managed PostgreSQL with full admin control |
| **PG Versions** | 13, 14, 15, 16 supported |
| **Compute Tiers** | Burstable (B-series), General Purpose (D-series), Memory Optimized (E-series) |
| **Storage** | 32 GB to 32 TB, Premium SSD or Premium SSD v2 |
| **High Availability** | Zone-redundant HA with automatic failover |
| **Networking** | Public access or Private endpoint (VNet integration) |

### Azure Flexible Server — Key Features
Azure Flexible Server provides zone-redundant high availability — a standby in another availability zone with automatic failover. Automated backups with up to 35 days retention and geo-redundant backup option for disaster recovery across regions. Read replicas up to 5 copies. Server parameters let you tune postgresql.conf settings through the portal or CLI. Intelligent Performance features include automatic tuning recommendations.

- Zone-Redundant HA -- Standby in another AZ. Auto failover. Same endpoint. RPO: 0, RTO: < 120 seconds.
- Automated Backups -- Daily full + continuous WAL. Retain 7-35 days. Geo-redundant backup option.
- Read Replicas -- Up to 5 replicas. Same region or cross-region. Async replication.
- Server Parameters -- Tune postgresql.conf via Portal or CLI. Dynamic changes apply immediately.
- Intelligent Performance -- Query Performance Insights, automatic index recommendations, Query Store.
- Microsoft Entra ID -- Azure AD authentication for PostgreSQL. No passwords — use managed identity.

### Google Cloud SQL for PostgreSQL
Google Cloud SQL for PostgreSQL is Google's managed PostgreSQL service. It supports PostgreSQL 13 through 16. Cloud SQL provides automated backups, high availability with regional failover, read replicas, and integration with Google's IAM for authentication. The gcloud CLI creates and manages instances. Cloud SQL is the standard choice for most Google Cloud PostgreSQL workloads.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Service Type** | Managed PostgreSQL on Google Cloud |
| **PG Versions** | 13, 14, 15, 16 supported |
| **Machine Types** | Shared-core to 96 vCPUs, custom configurations |
| **Storage** | SSD or HDD, auto-grow up to 64 TB |
| **High Availability** | Regional HA with automatic failover |
| **Networking** | Public IP, Private IP (VPC), or Cloud SQL Auth Proxy |

### Comparison
If this cloud PostgreSQL guide is helping you understand managed services, please support the course. Your donation keeps this content free. Links for PayPal and UPI are in the description.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials (.sql) |
| UPI: Link in description | Azure & GCP CLI commands |
| Every donation helps! | Practice exercises included |

### AlloyDB for PostgreSQL
AlloyDB is Google's high-performance PostgreSQL-compatible database. Think of it as Google's answer to Aurora. AlloyDB separates compute from storage like Aurora does, but adds a columnar engine for analytics queries. It claims up to 4 times faster than standard PostgreSQL for transactions and up to 100 times faster for analytical queries. It is fully PostgreSQL compatible — your existing code works without changes.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Type** | Google's cloud-native PostgreSQL (like Aurora for GCP) |
| **Compatibility** | Fully PostgreSQL compatible — existing code works |
| **Performance** | Up to 4x faster transactions, 100x faster analytics |
| **Columnar Engine** | Automatic columnar cache for analytical queries |
| **Storage** | Distributed, auto-scaling, 99.99% SLA with regional HA |
| **AI Integration** | Built-in ML with AlloyDB AI — vector embeddings in SQL |

### AlloyDB Architecture
AlloyDB's architecture separates compute from a distributed storage layer. The primary instance handles writes while read pool instances handle reads — similar to Aurora. The storage layer uses Google's distributed infrastructure with intelligent caching. What makes AlloyDB unique is the columnar engine — it automatically caches frequently accessed columns in a columnar format for fast analytical queries alongside your transactional workload.

```
[Application]
[Primary
Instance]
[Read Pool
(1-20 nodes)]
[Columnar Engine (auto-cache analytics columns)]
[Distributed Storage (Google infrastructure)]
```

### Cloud PostgreSQL Compared
Here is how the three cloud providers compare for managed PostgreSQL. AWS has the most mature offering with RDS and Aurora. Azure Flexible Server provides excellent integration with Microsoft tools and Entra ID. Google Cloud SQL is solid and the Auth Proxy simplifies connectivity. AlloyDB is the performance leader for mixed workloads but costs more. Choose based on your existing cloud platform — avoid multi-cloud for the database layer if possible.

| Term | Meaning / Explanation |
| :--- | :--- |
| **PG Versions** | AWS RDS/Aurora: 13-16 | Azure Flexible: 13-16 | GCP Cloud SQL: 13-16 |
| **HA Failover** | AWS RDS/Aurora: < 30-60s | Azure Flexible: < 120s | GCP Cloud SQL: < 60s |
| **Max Storage** | AWS RDS/Aurora: 128 TB (Aurora) | Azure Flexible: 32 TB | GCP Cloud SQL: 64 TB |
| **Read Replicas** | AWS RDS/Aurora: 15 (Aurora) | Azure Flexible: 5 | GCP Cloud SQL: 10 |
| **Serverless** | AWS RDS/Aurora: Aurora Serverless v2 | Azure Flexible: Burstable tier | GCP Cloud SQL: No |
| **Premium** | AWS RDS/Aurora: Aurora | Azure Flexible: N/A | GCP Cloud SQL: AlloyDB |

### Beginner Traps
Watch out for these traps. Azure Flexible Server firewall blocks all connections by default — you must add firewall rules or use VNet integration. Google Cloud SQL Auth Proxy requires proper IAM roles — Cloud SQL Client role is the minimum. AlloyDB has no public IP option — you must use VPC and the Auth Proxy. Each provider names parameters differently — Azure uses shared_buffers in bytes, Google uses megabytes. Always check the provider documentation for parameter formats.

- Azure: firewall blocks everything -- No connections allowed by default. Add your IP or use VNet. Do not open 0.0.0.0/0.
- GCP: IAM roles for Auth Proxy -- Service account needs Cloud SQL Client role. Missing role = connection refused.
- AlloyDB: no public IP -- VPC-only access. Must use AlloyDB Auth Proxy or connect from within VPC.
- Parameter format differs -- Azure: shared_buffers in 8KB pages. GCP: in MB string. Check provider docs.
- Pricing varies by provider -- Compare total cost: compute + storage + I/O + networking. Use pricing calculators.

### Practice Exercises
Here are your practice exercises. First, create an Azure Flexible Server with the CLI or Portal — use the Burstable tier for low cost. Connect with psql. Second, create a Google Cloud SQL instance and connect using the Cloud SQL Auth Proxy. Third, compare the server parameter interfaces — modify shared_buffers on each provider. Fourth, set up high availability on both and compare failover behavior. Fifth, if budget allows, create an AlloyDB cluster and run a mixed transactional-analytical workload.

- Exercise 1 -- Create Azure Flexible Server (Burstable tier). Add firewall rule. Connect with psql.
- Exercise 2 -- Create Cloud SQL instance. Set up Auth Proxy. Connect through localhost:5432.
- Exercise 3 -- Modify shared_buffers on Azure and GCP. Note the different parameter formats.
- Exercise 4 -- Enable HA on both providers. Trigger failover. Measure downtime.
- Exercise 5 -- Optional: Create AlloyDB cluster. Test columnar engine with analytics query.


---

## 3. Hands-On Commands & psql Output

### Azure CLI — Create Flexible Server
**Explanation:** Create a Flexible Server with the Azure CLI. Specify the resource group, location, PostgreSQL version, compute tier, storage size, and admin credentials. The server takes a few minutes to create. Azure assigns a fully qualified domain name as the endpoint. You can also create it through the Azure Portal or Terraform.

```sql
# Create resource group
$ az group create --name myapp-rg --location eastus

# Create Flexible Server
$ az postgres flexible-server create \
  --resource-group myapp-rg \
  --name myapp-pg \
  --location eastus \
  --version 16 \
  --sku-name Standard_D2ds_v5 \
  --storage-size 128 \
  --admin-user app_admin \
  --admin-password 'SecurePass123!'

Host: myapp-pg.postgres.database.azure.com
```

### Azure CLI — Common Operations
**Explanation:** Here are the Azure CLI commands for daily operations. List your servers, connect with psql, update server parameters, create backups, and restore. The firewall rule is important — by default, no external connections are allowed. You must add your client IP address to connect.

```sql
# Add firewall rule for your IP
$ az postgres flexible-server firewall-rule create --resource-group myapp-rg --name myapp-pg --rule-name allow-myip --start-ip-address 203.0.113.10 --end-ip-address 203.0.113.10

# Connect with psql
$ psql "host=myapp-pg.postgres.database.azure.com dbname=postgres user=app_admin sslmode=require"

# Update server parameter
$ az postgres flexible-server parameter set --resource-group myapp-rg --server-name myapp-pg --name shared_buffers --value 524288

# Restore to point in time
$ az postgres flexible-server restore --resource-group myapp-rg --name myapp-restored --source-server myapp-pg --restore-time 2026-11-05T10:00:00Z
```

### gcloud CLI — Create Cloud SQL Instance
**Explanation:** Create a Cloud SQL PostgreSQL instance with the gcloud CLI. Specify the database version, tier which is the machine type, storage size and type, and region. Enable high availability with the availability-type flag set to REGIONAL. The Cloud SQL Auth Proxy is the recommended way to connect — it handles SSL and IAM authentication without exposing a public IP.

```sql
$ gcloud sql instances create myapp-pg \
  --database-version=POSTGRES_16 \
  --tier=db-custom-2-8192 \
  --storage-size=50GB \
  --storage-type=SSD \
  --storage-auto-increase \
  --region=us-central1 \
  --availability-type=REGIONAL \
  --backup-start-time=03:00 \
  --database-flags=shared_buffers=2048MB

# Set root password
$ gcloud sql users set-password postgres --instance=myapp-pg --password='SecurePass123!'

# Create database
$ gcloud sql databases create myapp --instance=myapp-pg
```

### Cloud SQL Auth Proxy — Setup
**Explanation:** The Cloud SQL Auth Proxy is the recommended connection method. It runs locally and creates a secure tunnel to your Cloud SQL instance using IAM authentication. No public IP needed, no SSL certificates to manage, no firewall rules. Your application connects to localhost and the proxy forwards to Cloud SQL. Use it in development and in production on Google Kubernetes Engine.

```sql
# Download the proxy
$ curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.14.1/cloud-sql-proxy.linux.amd64
$ chmod +x cloud-sql-proxy

# Start proxy (runs in background)
$ ./cloud-sql-proxy --port 5432 PROJECT_ID:us-central1:myapp-pg &
Listening on 127.0.0.1:5432

# Connect through proxy
$ psql -h 127.0.0.1 -U postgres -d myapp
myapp=> SELECT version();
 PostgreSQL 16.4 on x86_64-pc-linux-gnu
```

### gcloud CLI — Create AlloyDB Cluster
**Explanation:** Create an AlloyDB cluster with the gcloud CLI. First create the cluster, then add a primary instance and optionally a read pool. AlloyDB requires a VPC with Private Service Access — it does not support public IPs. Connect through the AlloyDB Auth Proxy or from within the same VPC.

```sql
# Create AlloyDB cluster
$ gcloud alloydb clusters create myapp-alloy \
  --region=us-central1 \
  --password='SecurePass123!' \
  --network=default

# Create primary instance
$ gcloud alloydb instances create myapp-primary \
  --cluster=myapp-alloy \
  --region=us-central1 \
  --instance-type=PRIMARY \
  --cpu-count=4

# Create read pool
$ gcloud alloydb instances create myapp-readers \
  --cluster=myapp-alloy \
  --region=us-central1 \
  --instance-type=READ_POOL \
  --cpu-count=4 --read-pool-node-count=2
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps
Watch out for these traps. Azure Flexible Server firewall blocks all connections by default — you must add firewall rules or use VNet integration. Google Cloud SQL Auth Proxy requires proper IAM roles — Cloud SQL Client role is the minimum. AlloyDB has no public IP option — you must use VPC and the Auth Proxy. Each provider names parameters differently — Azure uses shared_buffers in bytes, Google uses megabytes. Always check the provider documentation for parameter formats.

- Azure: firewall blocks everything -- No connections allowed by default. Add your IP or use VNet. Do not open 0.0.0.0/0.
- GCP: IAM roles for Auth Proxy -- Service account needs Cloud SQL Client role. Missing role = connection refused.
- AlloyDB: no public IP -- VPC-only access. Must use AlloyDB Auth Proxy or connect from within VPC.
- Parameter format differs -- Azure: shared_buffers in 8KB pages. GCP: in MB string. Check provider docs.
- Pricing varies by provider -- Compare total cost: compute + storage + I/O + networking. Use pricing calculators.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review. Azure Flexible Server offers zone-redundant HA, Entra ID integration, and Intelligent Performance. Google Cloud SQL provides the Auth Proxy for secure connectivity without public IPs. AlloyDB is Google's high-performance option with a columnar engine for analytics. Choose your cloud PostgreSQL based on your existing cloud platform. All three support PostgreSQL 16, automated backups, high availability, and read replicas.

- **Azure Flexible Server: zone-redundant HA, Entra ID auth, Query Store**
- **Google Cloud SQL: Auth Proxy for secure connectivity, IAM integration**
- **AlloyDB: 4x faster transactions, 100x faster analytics, columnar engine**
- **All support PG 16, automated backups, HA, read replicas**
- **Azure firewall blocks everything by default — add rules**
- **GCP Auth Proxy needs Cloud SQL Client IAM role**
- **AlloyDB is VPC-only — no public IP**
- **Choose based on your existing cloud platform**


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
