-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Ansible & Docker with PostgreSQL (Classes 276-277)
-- Phase 30: Integration with Other Technologies
-- ============================================================

-- ============================================================
-- 1. ANSIBLE — POSTGRESQL PLAYBOOK
-- ============================================================

-- Install Ansible: pip install ansible
-- Install PG modules: ansible-galaxy collection install community.postgresql

-- playbook.yml:
-- ---
-- - name: Deploy PostgreSQL 16
--   hosts: db_servers
--   become: yes
--   vars:
--     pg_version: "16"
--     pg_db: "myapp"
--     pg_user: "app_user"
--     pg_pass: "{{ vault_pg_pass }}"
--
--   tasks:
--     - name: Install PostgreSQL
--       apt:
--         name:
--           - postgresql-{{ pg_version }}
--           - postgresql-client-{{ pg_version }}
--         state: present
--         update_cache: yes
--
--     - name: Start and enable service
--       service:
--         name: postgresql
--         state: started
--         enabled: yes
--
--     - name: Configure postgresql.conf
--       template:
--         src: postgresql.conf.j2
--         dest: /etc/postgresql/{{ pg_version }}/main/postgresql.conf
--       notify: Restart PostgreSQL
--
--     - name: Configure pg_hba.conf
--       template:
--         src: pg_hba.conf.j2
--         dest: /etc/postgresql/{{ pg_version }}/main/pg_hba.conf
--       notify: Reload PostgreSQL
--
--     - name: Create database
--       community.postgresql.postgresql_db:
--         name: "{{ pg_db }}"
--         encoding: UTF8
--         state: present
--       become_user: postgres
--
--     - name: Create app user
--       community.postgresql.postgresql_user:
--         name: "{{ pg_user }}"
--         password: "{{ pg_pass }}"
--         db: "{{ pg_db }}"
--         priv: ALL
--         state: present
--       become_user: postgres
--
--   handlers:
--     - name: Restart PostgreSQL
--       service: name=postgresql state=restarted
--     - name: Reload PostgreSQL
--       service: name=postgresql state=reloaded

-- Run: ansible-playbook -i inventory.ini playbook.yml

-- ============================================================
-- 2. ANSIBLE — VAULT FOR PASSWORDS
-- ============================================================

-- Encrypt a password:
-- ansible-vault encrypt_string 'my_secure_password' --name 'vault_pg_pass'

-- Encrypt a file:
-- ansible-vault encrypt secrets.yml

-- Run with vault:
-- ansible-playbook playbook.yml --ask-vault-pass
-- OR
-- ansible-playbook playbook.yml --vault-password-file ~/.vault_pass

-- ============================================================
-- 3. DOCKER — RUNNING POSTGRESQL
-- ============================================================

-- Simple run with named volume:
-- docker run -d --name pg16 \
--   -e POSTGRES_PASSWORD=secret \
--   -e POSTGRES_DB=myapp \
--   -e POSTGRES_USER=app_user \
--   -p 5432:5432 \
--   -v pgdata:/var/lib/postgresql/data \
--   --shm-size=256m \
--   postgres:16

-- Connect:
-- psql -h localhost -U app_user -d myapp

-- Stop / Start / Remove:
-- docker stop pg16
-- docker start pg16
-- docker rm pg16  (volume survives!)

-- ============================================================
-- 4. DOCKER COMPOSE — FULL STACK
-- ============================================================

-- docker-compose.yml:
-- version: '3.8'
-- services:
--   db:
--     image: postgres:16
--     environment:
--       POSTGRES_DB: myapp
--       POSTGRES_USER: app_user
--       POSTGRES_PASSWORD: secret
--     ports:
--       - "5432:5432"
--     volumes:
--       - pgdata:/var/lib/postgresql/data
--       - ./init:/docker-entrypoint-initdb.d
--     shm_size: '256m'
--     healthcheck:
--       test: pg_isready -U app_user -d myapp
--       interval: 5s
--       timeout: 5s
--       retries: 5
--
--   app:
--     build: .
--     depends_on:
--       db:
--         condition: service_healthy
--     environment:
--       DATABASE_URL: postgresql://app_user:secret@db:5432/myapp
--     ports:
--       - "3000:3000"
--
-- volumes:
--   pgdata:

-- Run: docker compose up -d
-- Logs: docker compose logs db
-- Stop: docker compose down  (add -v to remove volumes)

-- ============================================================
-- 5. CUSTOM DOCKERFILE
-- ============================================================

-- FROM postgres:16
-- COPY postgresql.conf /etc/postgresql/postgresql.conf
-- COPY pg_hba.conf /etc/postgresql/pg_hba.conf
-- COPY init/01_extensions.sql /docker-entrypoint-initdb.d/
-- COPY init/02_schema.sql /docker-entrypoint-initdb.d/
-- COPY init/03_seed_data.sql /docker-entrypoint-initdb.d/
-- CMD ["postgres",
--   "-c", "config_file=/etc/postgresql/postgresql.conf",
--   "-c", "hba_file=/etc/postgresql/pg_hba.conf"]

-- Build: docker build -t myapp-pg:16 .
-- Run:   docker run -d -p 5432:5432 \
--          -e POSTGRES_PASSWORD=secret \
--          -v pgdata:/var/lib/postgresql/data \
--          myapp-pg:16

-- ============================================================
-- 6. INIT SCRIPTS
-- ============================================================

-- Files in /docker-entrypoint-initdb.d/ run on FIRST START ONLY
-- (when data directory is empty)
-- Supported formats: .sql, .sql.gz, .sh
-- Run in alphabetical order

-- init/01_extensions.sql:
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- init/02_schema.sql:
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),
    total NUMERIC(10,2)
);

-- init/03_seed_data.sql:
INSERT INTO users (name, email) VALUES
    ('Alice', 'alice@example.com'),
    ('Bob', 'bob@example.com');

-- ============================================================
-- 7. VOLUME MANAGEMENT
-- ============================================================

-- List volumes:
-- docker volume ls

-- Inspect volume:
-- docker volume inspect pgdata

-- Backup from container:
-- docker exec pg16 pg_dump -U app_user myapp > backup.sql

-- Restore to container:
-- cat backup.sql | docker exec -i pg16 psql -U app_user -d myapp

-- Remove volume (DATA LOSS!):
-- docker volume rm pgdata

-- ============================================================
-- 8. ANSIBLE vs DOCKER
-- ============================================================

-- Ansible: config management for bare metal / VMs
--          Production servers, full control
-- Docker:  containerization, portable, isolated
--          Development, testing, CI/CD
-- Both:    Ansible deploys Docker to production

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Ansible: write playbook to install PG 16, configure,
--    create DB + user. Run on test VM.

-- 2. Docker: run postgres:16 with named volume. Insert data.
--    Stop, restart. Verify data persists.

-- 3. Docker Compose: PG + web app + healthcheck.
--    Run docker compose up. Test connectivity.

-- 4. Custom Dockerfile: add init scripts for schema + seed data.
--    Build. Run. Verify schema and data exist on first start.

-- 5. Ansible + Docker: playbook deploys Docker Compose stack.
