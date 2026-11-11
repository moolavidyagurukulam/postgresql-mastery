# Kubernetes & Terraform with PostgreSQL — Cloud-Native Deployment & Infrastructure as Code
**Series:** PostgreSQL Mastery | **Phase:** 30 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. In this class, we cover deploying PostgreSQL on Kubernetes using CloudNativePG and managing PostgreSQL infrastructure with Terraform. These tools represent the modern approach to running databases at scale.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites
Before this class, you should understand Docker from the previous class — containers, volumes, images. For Kubernetes, you need a cluster — Minikube for local testing or a cloud cluster on AWS, Azure, or GCP. For Terraform, install the Terraform CLI. Understanding basic PostgreSQL administration from earlier phases is essential.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Docker Knowledge** | Containers, volumes, images — previous class |
| **Kubernetes Cluster** | Minikube (local) or cloud cluster (EKS/AKS/GKE) |
| **kubectl** | Kubernetes CLI tool installed and configured |
| **Terraform CLI** | Install from terraform.io (v1.7+) |
| **Cloud Account** | AWS/Azure/GCP for Terraform section (optional) |

### Comparison
Running PostgreSQL on Kubernetes gives you automated failover, self-healing, scaling, and declarative configuration. If a pod crashes, Kubernetes restarts it. If a node dies, Kubernetes reschedules the pod to another node. Operators like CloudNativePG add PostgreSQL-specific intelligence — they handle replication, backup, switchover, and rolling upgrades. The trade-off is complexity — Kubernetes has a steep learning curve.

| Benefits on Kubernetes | Trade-offs |
| :--- | :--- |
| Self-healing (auto restart pods) | Steep learning curve |
| Automated failover (operator) | Storage complexity (PVC/PV) |
| Declarative config (YAML) | Networking complexity |
| Rolling upgrades | Operator required for HA |
| Same platform as your apps | Not simpler than bare metal |

### CloudNativePG Operator
CloudNativePG is the open-source Kubernetes operator for PostgreSQL — created by EDB and donated to the CNCF. It is the most popular PostgreSQL operator alongside Crunchy PGO. You define a Cluster resource in YAML — how many instances, storage size, backup schedule — and CloudNativePG creates the pods, persistent volumes, services, and handles replication automatically.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Type** | Kubernetes operator for PostgreSQL (CNCF Sandbox) |
| **Created By** | EDB, donated to CNCF community |
| **Manages** | Primary + standby pods, replication, failover, backup |
| **Backup** | Barman Cloud (S3/Azure/GCS) built-in |
| **HA** | Automatic failover — promotes standby if primary dies |
| **Install** | kubectl apply -f cloudnative-pg operator manifest |

### PostgreSQL on Kubernetes
Here is what the Kubernetes cluster looks like. The CloudNativePG operator runs as a deployment and watches for Cluster resources. When you create a Cluster, the operator creates pods — each with a PostgreSQL container — persistent volume claims for data, services for routing traffic to the primary and to read replicas, and secrets for credentials. Applications connect through the services.

```
[Application
Pods]
[PG Service
(primary-rw)]
[PG Service
(replicas-ro)]
[Primary Pod
+ PVC]
[Standby Pod 1
+ PVC]
[Standby Pod 2
+ PVC]
```

### Comparison
If this cloud-native PostgreSQL guide is helping you, please support the course. Your donation keeps this content free. Links for PayPal and UPI are in the description.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials (.sql) |
| UPI: Link in description | Kubernetes YAML examples |
| Every donation helps! | Terraform configs included |

### Terraform — Infrastructure as Code
Terraform is HashiCorp's infrastructure as code tool. You define your infrastructure in HCL files — servers, databases, networks, DNS — and Terraform creates, updates, and destroys them. For PostgreSQL, Terraform can provision cloud-managed databases like AWS RDS, Azure Database, or GCP Cloud SQL. It can also create PostgreSQL roles, databases, and schemas using the PostgreSQL provider.

| Term | Meaning / Explanation |
| :--- | :--- |
| **What** | Define infrastructure in code (HCL). Terraform creates/updates it. |
| **Cloud DBs** | Provision AWS RDS, Azure Database, GCP Cloud SQL |
| **PG Provider** | Create roles, databases, schemas, extensions on any PG |
| **State** | Terraform tracks what exists in a state file |
| **Plan** | terraform plan shows what WILL change before applying |
| **Idempotent** | Running apply twice changes nothing if state matches |

### Kubernetes Operators Compared
Let us compare the three main Kubernetes operators for PostgreSQL. CloudNativePG is the CNCF choice — newest, actively developed, Barman backup. Crunchy PGO is the most mature — pgBackRest backup, pgBouncer sidecar. Percona Operator is good for multi-database shops. All three handle replication, failover, and backup. Choose based on your ecosystem.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Organization** | CloudNativePG: CNCF (EDB origin) | Crunchy PGO: Crunchy Data |
| **Maturity** | CloudNativePG: Newer, fast-growing | Crunchy PGO: Most mature |
| **Backup Tool** | CloudNativePG: Barman Cloud | Crunchy PGO: pgBackRest |
| **Connection Pool** | CloudNativePG: PgBouncer (separate) | Crunchy PGO: PgBouncer sidecar |
| **Monitoring** | CloudNativePG: Prometheus metrics | Crunchy PGO: pgMonitor (Grafana) |
| **License** | CloudNativePG: Apache 2.0 | Crunchy PGO: Apache 2.0 |
| **Best For** | CloudNativePG: New K8s deployments | Crunchy PGO: Established K8s teams |

### Beginner Traps
Watch out for these traps. First, Kubernetes storage is not like local disk — always use a StorageClass that supports ReadWriteOnce and snapshots. Second, never store Terraform state locally in a team — use remote state in S3 or Terraform Cloud. Third, Terraform destroy is permanent — always review the plan. Fourth, PostgreSQL on Kubernetes is not simpler than bare metal — use it when your team already runs Kubernetes for applications.

- K8s: Storage matters -- Use a StorageClass with provisioner that supports snapshots (gp3, pd-ssd). Not all storage is equal.
- Terraform: Remote state -- Local state breaks team workflows. Use S3 + DynamoDB locking or Terraform Cloud.
- Terraform: Review plan -- terraform destroy deletes everything. Always run plan first. Use -target for specific resources.
- K8s: Not always simpler -- PG on K8s adds complexity. Use it when your apps already run on K8s. Otherwise, VMs are simpler.
- Never skip backups -- K8s HA is not backup. Pods restart, but data corruption spreads to replicas. Test restore regularly.

### Practice Exercises
Here are your practice exercises. First, install CloudNativePG on Minikube and create a 3-instance cluster. Test failover by deleting the primary pod. Second, write a Terraform configuration for AWS RDS PostgreSQL — use terraform plan to preview, apply to create, destroy to clean up. Third, use the Terraform PostgreSQL provider to create roles and databases on a running instance. Fourth, compare deployment time — CloudNativePG cluster versus manual Docker setup.

- Exercise 1 -- Minikube: install CloudNativePG, create 3-instance cluster. Delete primary pod, watch failover.
- Exercise 2 -- Terraform: write RDS PostgreSQL config. Plan → Apply → Connect → Destroy. Use variables for passwords.
- Exercise 3 -- Terraform PG provider: create readonly role + analytics DB on existing PG. Apply and verify with psql.
- Exercise 4 -- Compare: time to deploy PG cluster via CloudNativePG vs manual Docker Compose. Document differences.
- Exercise 5 -- CloudNativePG: configure backup to S3 (or MinIO locally). Take backup. Test restore to new cluster.


---

## 3. Hands-On Commands & psql Output

### CloudNativePG — Cluster YAML
**Explanation:** Here is a CloudNativePG cluster definition. You specify the number of instances — 3 means one primary and two standbys. Define the storage size and class. Set PostgreSQL parameters directly in the YAML. CloudNativePG creates the pods, configures streaming replication between primary and standbys, and monitors health. If the primary pod dies, it automatically promotes the most up-to-date standby.

```sql
# cluster.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: myapp-db
spec:
  instances: 3  # 1 primary + 2 standbys
  imageName: ghcr.io/cloudnative-pg/
    postgresql:16.4

  postgresql:
    parameters:
      shared_buffers: "256MB"
      max_connections: "100"
      work_mem: "16MB"
      log_statement: "ddl"

  storage:
    size: 50Gi
    storageClass: gp3

  bootstrap:
    initdb:
      database: myapp
      owner: app_user

  backup:
    barmanObjectStore:
      destinationPath: s3://my-backups/pg
      s3Credentials:
        accessKeyId:
          name: aws-creds
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: aws-creds
          key: SECRET_ACCESS_KEY
```

### CloudNativePG — Deploy and Operate
**Explanation:** Deploy the cluster with kubectl apply. CloudNativePG creates three pods — one primary and two standbys — with streaming replication configured automatically. Use kubectl cnpg status to check cluster health, kubectl cnpg promote to do a planned switchover, and kubectl cnpg backup to trigger an on-demand backup. The operator continuously monitors and heals the cluster.

```sql
$ kubectl apply -f cluster.yaml
cluster.postgresql.cnpg.io/myapp-db created

$ kubectl get pods -l cnpg.io/cluster=myapp-db
NAME          READY   STATUS    ROLE
myapp-db-1    1/1     Running   primary
myapp-db-2    1/1     Running   replica
myapp-db-3    1/1     Running   replica

$ kubectl cnpg status myapp-db
Cluster: myapp-db  Status: Healthy
Primary: myapp-db-1  Replicas: 2/2
```

### Terraform — AWS RDS PostgreSQL
**Explanation:** Here is a Terraform configuration that creates an AWS RDS PostgreSQL instance. You define the engine version, instance class, storage, credentials, and network settings. Run terraform plan to preview what will be created. Run terraform apply to create it. Terraform stores the current state — if you change the instance class later, Terraform modifies only that setting.

```sql
# main.tf
provider "aws" {
  region = "us-east-1"
}

resource "aws_db_instance" "myapp" {
  identifier        = "myapp-pg"
  engine            = "postgres"
  engine_version    = "16.4"
  instance_class    = "db.t3.medium"
  allocated_storage = 50
  storage_type      = "gp3"

  db_name  = "myapp"
  username = "app_user"
  password = var.db_password

  vpc_security_group_ids = [
    aws_security_group.pg.id
  ]
  db_subnet_group_name =
    aws_db_subnet_group.pg.name

  backup_retention_period = 7
  multi_az               = true
  skip_final_snapshot    = false
  final_snapshot_identifier =
    "myapp-pg-final"

  tags = {
    Environment = "production"
  }
}
```

### Terraform — PostgreSQL Provider
**Explanation:** Terraform also has a PostgreSQL provider that connects to any running PostgreSQL instance and manages roles, databases, schemas, and extensions. This is useful for managing the objects inside a database — not just the infrastructure. You can create read-only users, application databases, and grant privileges — all as code, versioned in source control.

```sql
# providers.tf
provider "postgresql" {
  host     = "myapp-pg.xxx.rds.amazonaws.com"
  port     = 5432
  username = "app_user"
  password = var.db_password
  database = "myapp"
  sslmode  = "require"
}

# Create a read-only role
resource "postgresql_role" "readonly" {
  name     = "readonly_user"
  login    = true
  password = var.ro_password
}

# Create analytics database
resource "postgresql_database" "analytics" {
  name  = "analytics"
  owner = "app_user"
}

# Grant read-only access
resource "postgresql_grant" "ro_tables" {
  database    = "myapp"
  role        = postgresql_role.readonly.name
  schema      = "public"
  object_type = "table"
  privileges  = ["SELECT"]
}
```

### Terraform — Workflow
**Explanation:** Terraform has four main commands. Init downloads the providers. Plan shows what will change — this is your safety net. Apply creates or updates the resources. Destroy tears everything down. Always run plan before apply to review changes. Store your state file remotely — in S3 or Terraform Cloud — so your team can share it.

```sql
$ terraform init
Initializing provider plugins...
- Installed hashicorp/aws v5.40.0
- Installed cyrilgdn/postgresql v1.22.0

$ terraform plan
Plan: 3 to add, 0 to change, 0 to destroy.

$ terraform apply
Do you want to perform these actions? (yes)
aws_db_instance.myapp: Creating...
Apply complete! Resources: 3 added.
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps
Watch out for these traps. First, Kubernetes storage is not like local disk — always use a StorageClass that supports ReadWriteOnce and snapshots. Second, never store Terraform state locally in a team — use remote state in S3 or Terraform Cloud. Third, Terraform destroy is permanent — always review the plan. Fourth, PostgreSQL on Kubernetes is not simpler than bare metal — use it when your team already runs Kubernetes for applications.

- K8s: Storage matters -- Use a StorageClass with provisioner that supports snapshots (gp3, pd-ssd). Not all storage is equal.
- Terraform: Remote state -- Local state breaks team workflows. Use S3 + DynamoDB locking or Terraform Cloud.
- Terraform: Review plan -- terraform destroy deletes everything. Always run plan first. Use -target for specific resources.
- K8s: Not always simpler -- PG on K8s adds complexity. Use it when your apps already run on K8s. Otherwise, VMs are simpler.
- Never skip backups -- K8s HA is not backup. Pods restart, but data corruption spreads to replicas. Test restore regularly.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review Phase 30. We covered integration with six major technologies. Python and Java connect via psycopg2 and JDBC with connection pooling and ORMs. Node.js and .NET use pg and Npgsql with Prisma and Entity Framework. Go uses pgx, and Kafka CDC streams changes via Debezium. Liquibase and Flyway manage schema migrations. Ansible automates server deployment. Docker containerizes PostgreSQL. Kubernetes runs PostgreSQL at scale with operators. Terraform provisions infrastructure as code.

- **Kubernetes: CloudNativePG or Crunchy PGO operator for automated HA**
- **Define PG clusters in YAML — operator handles replication + failover**
- **Terraform: provision cloud databases (RDS/Azure/GCP) as code**
- **Terraform PG provider: manage roles, databases, grants as code**
- **Always run terraform plan before apply**
- **K8s operators: CloudNativePG (CNCF), Crunchy PGO, Percona**
- **PG on K8s adds complexity — use when apps already on K8s**


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
