# Ansible & Docker with PostgreSQL — Automated Deployment & Containerized Databases
**Series:** PostgreSQL Mastery | **Phase:** 30 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. In this class, we cover Ansible for automating PostgreSQL deployment and configuration, and Docker for running PostgreSQL in containers. These tools transform hours of manual setup into repeatable, versioned infrastructure.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites
Before this class, you should know how to install and configure PostgreSQL manually — the lessons from Phases 2 through 4. For the Ansible section, you need a Linux control machine with Ansible installed. For the Docker section, you need Docker Engine installed. No prior Ansible or Docker experience is required.

| Term | Meaning / Explanation |
| :--- | :--- |
| **PG Manual Install** | Installation, configuration, pg_hba.conf — Phases 2-4 |
| **Linux Basics** | SSH, sudo, package management, systemd |
| **Ansible** | Install with: pip install ansible |
| **Docker** | Docker Engine installed (docker.com) |

### Comparison
Setting up one PostgreSQL server manually takes 30 minutes — install packages, edit postgresql.conf, configure pg_hba.conf, create users, create databases, set up backups. Now imagine doing this for 50 servers. Or rebuilding after a disaster. Or ensuring every server has identical configuration. Manual setup does not scale. Ansible automates every step into a playbook you run once and it configures everything.

| Manual Setup Problems | Ansible Automation |
| :--- | :--- |
| 30 minutes per server | One playbook, any number of servers |
| 50 servers = 25 hours | 50 servers = same 5-minute run |
| Configuration drift over time | Identical config everywhere |
| No audit trail of changes | Playbook IS the audit trail |
| Disaster recovery = start over | Disaster recovery = run playbook |

### Comparison
If this automation guide is helping your team, please support the course. Your donation keeps this content free. Links for PayPal and UPI are in the description.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials (.sql) |
| UPI: Link in description | Ansible playbooks included |
| Every donation helps! | Docker Compose files included |

### Docker + PostgreSQL — Use Cases
Docker containers package PostgreSQL with all its dependencies into an isolated, portable unit. Why use it? Development environments — every developer gets an identical database with one command. Testing — spin up a clean database for each test run, destroy it after. CI/CD — automated tests against a real PostgreSQL instance. For production, containers work but require careful volume management for data persistence.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Development** | Every developer runs identical PG with one command |
| **Testing** | Fresh database per test suite. Destroy after. No cleanup. |
| **CI/CD** | Automated tests against real PostgreSQL in pipeline |
| **Production** | Works with careful volume management. K8s operators preferred. |
| **Data Persistence** | Docker volumes preserve data between container restarts |
| **Official Image** | postgres:16 on Docker Hub — maintained by Docker + PG community |

### Docker Volume Management
Data persistence is the most critical aspect of running PostgreSQL in Docker. Without a volume, all data is lost when the container is removed. Named volumes persist across container restarts and removals. For production, use bind mounts to a specific host directory for easier backup. Never store PostgreSQL data in the container's writable layer — it is slow and ephemeral.

- Named Volume (Recommended) -- docker run -v pgdata:/var/lib/postgresql/data. Docker manages the volume. Survives container removal.
- Bind Mount -- docker run -v /host/data:/var/lib/postgresql/data. Maps to host directory. Easy backup with cp/rsync.
- No Volume (DATA LOSS!) -- docker run postgres:16. Data in container layer. Container removed = data gone forever.
- Backup from Volume -- docker exec pg16 pg_dump -U postgres myapp > backup.sql. Or pg_basebackup for physical backup.
- Volume Inspection -- docker volume inspect pgdata. Shows mountpoint on host filesystem.

### Ansible vs Docker — When to Use
Ansible and Docker solve different problems. Ansible automates bare-metal or VM deployments — install PostgreSQL on a server, configure it, manage it. Docker packages PostgreSQL into a container — portable, isolated, identical everywhere. Use Ansible for production servers where you want full control. Use Docker for development, testing, and CI/CD. Use both together — Ansible deploys Docker containers to production servers.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Type** | Ansible: Configuration management | Docker: Containerization |
| **Target** | Ansible: Bare metal / VMs | Docker: Any Docker host |
| **State** | Ansible: Desired state (idempotent) | Docker: Immutable image |
| **Production** | Ansible: Yes (full control) | Docker: Yes (with volumes + K8s) |
| **Development** | Ansible: Overkill | Docker: Perfect (docker compose up) |
| **CI/CD Testing** | Ansible: Slower setup | Docker: Fast (seconds to start) |
| **Together** | Ansible: Ansible deploys Docker containers to production servers | Docker:  |

### Beginner Traps
Watch out for these traps. First, never run PostgreSQL in Docker without a volume — your data will be lost. Second, the Docker init scripts only run on the first startup — if the data directory already exists, they are skipped. Third, in Ansible, always use ansible-vault for passwords — never put them in plain text. Fourth, Docker's default shared memory is 64 megabytes — PostgreSQL needs more. Set shm_size in your compose file.

- Docker: No volume = data loss -- ALWAYS use -v pgdata:/var/lib/postgresql/data. No volume = data gone on container removal.
- Docker: Init scripts run once -- Files in docker-entrypoint-initdb.d/ only run when data dir is empty (first start).
- Ansible: Encrypt passwords -- Use ansible-vault encrypt_string for DB passwords. Never plain text in playbooks.
- Docker: Set shm_size -- Default 64MB is too small for PG. Add shm_size: '256m' in docker-compose.yml.
- Docker: Pin image versions -- Use postgres:16.4, not postgres:latest. Prevent surprise major version upgrades.

### Practice Exercises
Here are your practice exercises. First, write an Ansible playbook that installs PostgreSQL 16, configures it, creates a database and user. Run it against a test server or VM. Second, run PostgreSQL 16 in Docker with a named volume. Connect with psql, create data, stop and restart the container, verify data persists. Third, create a Docker Compose file with PostgreSQL and a web application. Fourth, build a custom Dockerfile with init scripts. Fifth, write an Ansible playbook that deploys a Docker Compose stack.

- Exercise 1 -- Ansible playbook: install PG 16, configure, create DB + user. Run on test VM.
- Exercise 2 -- Docker: run postgres:16 with named volume. Insert data. Stop/restart. Verify persistence.
- Exercise 3 -- Docker Compose: PG + web app + healthcheck. Run docker compose up. Test connectivity.
- Exercise 4 -- Custom Dockerfile: extend postgres:16. Add init scripts for schema + seed data.
- Exercise 5 -- Ansible + Docker: playbook that deploys Docker Compose stack to a remote server.


---

## 3. Hands-On Commands & psql Output

### Ansible — PostgreSQL Playbook
**Explanation:** An Ansible playbook is a YAML file that describes the desired state of your servers. For PostgreSQL, you define tasks — install the package, copy the configuration files, create users and databases, start the service. Ansible connects to each server via SSH and executes the tasks. It is idempotent — running the same playbook twice changes nothing if the server is already in the desired state.

```sql
# playbook.yml
---
- name: Deploy PostgreSQL 16
  hosts: db_servers
  become: yes
  vars:
    pg_version: "16"
    pg_db: "myapp"
    pg_user: "app_user"
    pg_pass: "{{ vault_pg_pass }}"

  tasks:
    - name: Install PostgreSQL
      apt:
        name:
          - postgresql-{{ pg_version }}
          - postgresql-client-{{ pg_version }}
        state: present
        update_cache: yes

    - name: Configure postgresql.conf
      template:
        src: postgresql.conf.j2
        dest: /etc/postgresql/
          {{ pg_version }}/main/postgresql.conf
      notify: Restart PostgreSQL

    - name: Configure pg_hba.conf
      template:
        src: pg_hba.conf.j2
        dest: /etc/postgresql/
          {{ pg_version }}/main/pg_hba.conf
      notify: Reload PostgreSQL
```

### Ansible — Create Users and Databases
**Explanation:** Ansible has built-in modules for PostgreSQL — postgresql_db creates databases, postgresql_user creates users with specific privileges, and postgresql_privs manages permissions. These modules are idempotent — if the user already exists, Ansible skips the task. You can also use postgresql_query to run any SQL statement during provisioning.

```sql
# continued from playbook.yml

    - name: Create database
      community.postgresql.postgresql_db:
        name: "{{ pg_db }}"
        encoding: UTF8
        lc_collate: en_US.UTF-8
        state: present
      become_user: postgres

    - name: Create app user
      community.postgresql.postgresql_user:
        name: "{{ pg_user }}"
        password: "{{ pg_pass }}"
        db: "{{ pg_db }}"
        priv: ALL
        state: present
      become_user: postgres

    - name: Grant schema privileges
      community.postgresql.postgresql_privs:
        database: "{{ pg_db }}"
        roles: "{{ pg_user }}"
        type: schema
        objs: public
        privs: ALL
      become_user: postgres

  handlers:
    - name: Restart PostgreSQL
      service:
        name: postgresql
        state: restarted

    - name: Reload PostgreSQL
      service:
        name: postgresql
        state: reloaded
```

### Ansible — Running the Playbook
**Explanation:** To run the playbook, define your inventory — the list of servers — and run ansible-playbook. Ansible connects to each server via SSH, executes the tasks in order, and reports the results. Green means no changes needed — the server is already in the desired state. Yellow means a change was made. Red means a task failed. Use ansible-vault for encrypting passwords.

```sql
# inventory.ini
[db_servers]
db1.example.com
db2.example.com
db3.example.com

$ ansible-playbook -i inventory.ini playbook.yml
PLAY [Deploy PostgreSQL 16]
TASK [Install PostgreSQL] .............. ok
TASK [Configure postgresql.conf] ....... changed
TASK [Configure pg_hba.conf] ........... changed
TASK [Create database] ................. ok
TASK [Create app user] ................. ok
PLAY RECAP: ok=5  changed=2  failed=0
```

### Docker — Running PostgreSQL
**Explanation:** The simplest way to run PostgreSQL in Docker is docker run with the official postgres image. Set the password with POSTGRES_PASSWORD, map port 5432, and mount a volume for data persistence. Without a volume, all data is lost when the container stops. The official image supports environment variables for creating a database and user on first startup.

```sql
$ docker run -d --name pg16 \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=myapp \
  -e POSTGRES_USER=app_user \
  -p 5432:5432 \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16
a1b2c3d4e5f6...

$ docker ps
CONTAINER ID  IMAGE        STATUS         PORTS
a1b2c3d4e5f6  postgres:16  Up 10 seconds  0.0.0.0:5432->5432/tcp

$ psql -h localhost -U app_user -d myapp
myapp=>
```

### docker-compose.yml — Full Stack
**Explanation:** Docker Compose defines your entire stack in one YAML file — PostgreSQL, your application, PgBouncer, monitoring. This is the standard way to set up development environments. Each developer clones the repo, runs docker compose up, and gets an identical environment. The init scripts directory lets you run SQL files on first startup to seed the database.

```sql
version: '3.8'
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: app_user
      POSTGRES_PASSWORD: secret
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./init:/docker-entrypoint-initdb.d
    healthcheck:
      test: pg_isready -U app_user -d myapp
      interval: 5s
      timeout: 5s
      retries: 5

  app:
    build: .
    depends_on:
      db:
        condition: service_healthy
    environment:
      DATABASE_URL: postgresql://
        app_user:secret@db:5432/myapp
    ports:
      - "3000:3000"

volumes:
  pgdata:
```

### Dockerfile — Custom PostgreSQL
**Explanation:** You can build a custom PostgreSQL image with your extensions, configuration, and initialization scripts baked in. Create a Dockerfile that extends the official image. Copy your postgresql.conf and pg_hba.conf. Add SQL files to the init directory — they run alphabetically on first startup. This ensures every environment starts identically.

```sql
FROM postgres:16

# Custom configuration
COPY postgresql.conf \
  /etc/postgresql/postgresql.conf
COPY pg_hba.conf \
  /etc/postgresql/pg_hba.conf

# Init scripts (run on first start)
COPY init/01_extensions.sql \
  /docker-entrypoint-initdb.d/
COPY init/02_schema.sql \
  /docker-entrypoint-initdb.d/
COPY init/03_seed_data.sql \
  /docker-entrypoint-initdb.d/

# Use custom config
CMD ["postgres",
  "-c", "config_file=" \
  "/etc/postgresql/postgresql.conf",
  "-c", "hba_file=" \
  "/etc/postgresql/pg_hba.conf"]

# Build:
# docker build -t myapp-pg:16 .
# Run:
# docker run -d -p 5432:5432 \
#   -e POSTGRES_PASSWORD=secret \
#   myapp-pg:16
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps
Watch out for these traps. First, never run PostgreSQL in Docker without a volume — your data will be lost. Second, the Docker init scripts only run on the first startup — if the data directory already exists, they are skipped. Third, in Ansible, always use ansible-vault for passwords — never put them in plain text. Fourth, Docker's default shared memory is 64 megabytes — PostgreSQL needs more. Set shm_size in your compose file.

- Docker: No volume = data loss -- ALWAYS use -v pgdata:/var/lib/postgresql/data. No volume = data gone on container removal.
- Docker: Init scripts run once -- Files in docker-entrypoint-initdb.d/ only run when data dir is empty (first start).
- Ansible: Encrypt passwords -- Use ansible-vault encrypt_string for DB passwords. Never plain text in playbooks.
- Docker: Set shm_size -- Default 64MB is too small for PG. Add shm_size: '256m' in docker-compose.yml.
- Docker: Pin image versions -- Use postgres:16.4, not postgres:latest. Prevent surprise major version upgrades.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review. Ansible automates PostgreSQL deployment and configuration on bare-metal servers and VMs — write a playbook once, run it on any number of servers. Docker packages PostgreSQL into containers — perfect for development, testing, and CI/CD. Always use volumes for data persistence. Pin image versions. Set shm_size. Use both together — Ansible deploys Docker containers to production infrastructure.

- **Ansible: automate PG install, config, users, databases on servers**
- **Ansible is idempotent — running twice changes nothing**
- **Docker: postgres:16 image, one command to run PG**
- **ALWAYS use volumes (-v pgdata:/var/lib/postgresql/data)**
- **Docker Compose: define full stack (PG + app) in one YAML**
- **Init scripts in docker-entrypoint-initdb.d/ run on first start only**
- **Pin versions (postgres:16.4), set shm_size, use healthchecks**
- **Use Ansible for production VMs, Docker for dev/test/CI**


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
