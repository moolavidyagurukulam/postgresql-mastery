-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Projects: Multi-Tenant SaaS & Full HA Cluster (Classes 284-285)
-- Phase 32: Capstone Projects
-- ============================================================

-- ============================================================
-- PROJECT 1: MULTI-TENANT SAAS DATABASE
-- ============================================================

-- ============================================================
-- 1. SCHEMA — Core tables with tenant_id
-- ============================================================

CREATE TABLE tenants (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    slug VARCHAR(50) UNIQUE NOT NULL,
    plan VARCHAR(20) DEFAULT 'free'
        CHECK (plan IN ('free', 'starter', 'pro', 'enterprise')),
    max_users INT DEFAULT 5,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    tenant_id INT NOT NULL REFERENCES tenants(id),
    email VARCHAR(200) NOT NULL,
    name VARCHAR(200) NOT NULL,
    role VARCHAR(20) DEFAULT 'member'
        CHECK (role IN ('admin', 'manager', 'member', 'viewer')),
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, email)
);

CREATE TABLE projects (
    id SERIAL PRIMARY KEY,
    tenant_id INT NOT NULL REFERENCES tenants(id),
    name VARCHAR(200) NOT NULL,
    description TEXT,
    owner_id INT REFERENCES users(id),
    status VARCHAR(20) DEFAULT 'active'
        CHECK (status IN ('active', 'archived', 'deleted')),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE tasks (
    id SERIAL PRIMARY KEY,
    tenant_id INT NOT NULL REFERENCES tenants(id),
    project_id INT NOT NULL REFERENCES projects(id),
    title VARCHAR(300) NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'todo'
        CHECK (status IN ('todo', 'in_progress', 'review', 'done')),
    priority INT DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
    assigned_to INT REFERENCES users(id),
    due_date DATE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 2. INDEXES — tenant_id first in every index
-- ============================================================

CREATE INDEX idx_users_tenant ON users(tenant_id);
CREATE INDEX idx_users_tenant_email ON users(tenant_id, email);
CREATE INDEX idx_projects_tenant ON projects(tenant_id, status);
CREATE INDEX idx_projects_owner ON projects(tenant_id, owner_id);
CREATE INDEX idx_tasks_tenant_status ON tasks(tenant_id, status);
CREATE INDEX idx_tasks_tenant_project ON tasks(tenant_id, project_id);
CREATE INDEX idx_tasks_tenant_assigned ON tasks(tenant_id, assigned_to);
CREATE INDEX idx_tasks_tenant_due ON tasks(tenant_id, due_date)
    WHERE status != 'done';

-- ============================================================
-- 3. ROW-LEVEL SECURITY
-- ============================================================

-- Enable RLS on all tenant tables:
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- Policies: see only your tenant's data
CREATE POLICY tenant_isolation ON users
    USING (tenant_id = current_setting('app.current_tenant')::int);

CREATE POLICY tenant_isolation ON projects
    USING (tenant_id = current_setting('app.current_tenant')::int);

CREATE POLICY tenant_isolation ON tasks
    USING (tenant_id = current_setting('app.current_tenant')::int);

-- Note: policies apply to non-superuser roles.
-- Superusers bypass RLS by default.

-- Create application role:
CREATE ROLE app_user LOGIN PASSWORD 'app_password';
GRANT SELECT, INSERT, UPDATE, DELETE
    ON ALL TABLES IN SCHEMA public TO app_user;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_user;

-- ============================================================
-- 4. SAMPLE DATA
-- ============================================================

INSERT INTO tenants (name, slug, plan) VALUES
    ('Acme Corporation', 'acme', 'pro'),
    ('Beta Industries', 'beta', 'starter'),
    ('Gamma Labs', 'gamma', 'enterprise');

INSERT INTO users (tenant_id, email, name, role) VALUES
    (1, 'alice@acme.com', 'Alice Johnson', 'admin'),
    (1, 'bob@acme.com', 'Bob Smith', 'member'),
    (2, 'carol@beta.com', 'Carol Davis', 'admin'),
    (2, 'dave@beta.com', 'Dave Wilson', 'member'),
    (3, 'eve@gamma.com', 'Eve Brown', 'admin');

INSERT INTO projects (tenant_id, name, owner_id) VALUES
    (1, 'Website Redesign', 1),
    (1, 'API Migration', 2),
    (2, 'Mobile App', 3),
    (3, 'Data Pipeline', 5);

INSERT INTO tasks (tenant_id, project_id, title, status, assigned_to) VALUES
    (1, 1, 'Design homepage mockup', 'in_progress', 1),
    (1, 1, 'Implement responsive layout', 'todo', 2),
    (1, 2, 'Migrate REST to GraphQL', 'todo', 2),
    (2, 3, 'Setup React Native', 'done', 3),
    (2, 3, 'Build login screen', 'in_progress', 4),
    (3, 4, 'Design ETL pipeline', 'in_progress', 5);

-- ============================================================
-- 5. TESTING ISOLATION
-- ============================================================

-- As superuser (bypasses RLS):
SELECT 'Total users:', count(*) FROM users;  -- 5

-- As app_user with tenant 1 (Acme):
-- SET ROLE app_user;
-- SET app.current_tenant = '1';
-- SELECT * FROM users;     -- Only Alice and Bob
-- SELECT * FROM projects;  -- Only Website Redesign and API Migration
-- SELECT * FROM tasks;     -- Only Acme's 3 tasks

-- As app_user with tenant 2 (Beta):
-- SET app.current_tenant = '2';
-- SELECT * FROM users;     -- Only Carol and Dave
-- SELECT * FROM tasks;     -- Only Beta's 2 tasks

-- Test: try inserting for wrong tenant (should be blocked by RLS):
-- SET app.current_tenant = '1';
-- INSERT INTO users (tenant_id, email, name) VALUES (2, 'hack@acme.com', 'Hacker');
-- ERROR: new row violates row-level security policy

-- ============================================================
-- 6. USEFUL QUERIES
-- ============================================================

-- Tenant dashboard (as app_user):
-- SET app.current_tenant = '1';
SELECT
    (SELECT count(*) FROM users) AS total_users,
    (SELECT count(*) FROM projects WHERE status = 'active') AS active_projects,
    (SELECT count(*) FROM tasks WHERE status != 'done') AS open_tasks;

-- Task board for a project:
SELECT title, status, u.name AS assignee, t.due_date
FROM tasks t
LEFT JOIN users u ON t.assigned_to = u.id
WHERE t.project_id = 1
ORDER BY t.priority, t.created_at;

-- Admin: per-tenant usage (as superuser, bypasses RLS):
SELECT t.name AS tenant, t.plan,
    (SELECT count(*) FROM users u WHERE u.tenant_id = t.id) AS users,
    (SELECT count(*) FROM projects p WHERE p.tenant_id = t.id) AS projects,
    (SELECT count(*) FROM tasks tk WHERE tk.tenant_id = t.id) AS tasks
FROM tenants t ORDER BY tasks DESC;

-- ============================================================
-- 7. PARTITIONING FOR SCALE
-- ============================================================

-- For 1000+ tenants, partition large tables by tenant_id:
-- CREATE TABLE tasks_partitioned (
--     id SERIAL,
--     tenant_id INT NOT NULL,
--     project_id INT NOT NULL,
--     title VARCHAR(300) NOT NULL,
--     status VARCHAR(20) DEFAULT 'todo'
-- ) PARTITION BY HASH (tenant_id);
--
-- CREATE TABLE tasks_p0 PARTITION OF tasks_partitioned
--     FOR VALUES WITH (modulus 4, remainder 0);
-- CREATE TABLE tasks_p1 PARTITION OF tasks_partitioned
--     FOR VALUES WITH (modulus 4, remainder 1);
-- CREATE TABLE tasks_p2 PARTITION OF tasks_partitioned
--     FOR VALUES WITH (modulus 4, remainder 2);
-- CREATE TABLE tasks_p3 PARTITION OF tasks_partitioned
--     FOR VALUES WITH (modulus 4, remainder 3);

-- ============================================================
-- PROJECT 2: FULL HA CLUSTER
-- ============================================================

-- ============================================================
-- 1. ETCD SETUP (3 nodes)
-- ============================================================

-- Install on all 3 etcd nodes:
-- sudo apt install etcd

-- /etc/default/etcd on node1 (10.0.1.30):
-- ETCD_NAME="etcd1"
-- ETCD_DATA_DIR="/var/lib/etcd"
-- ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
-- ETCD_ADVERTISE_CLIENT_URLS="http://10.0.1.30:2379"
-- ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
-- ETCD_INITIAL_ADVERTISE_PEER_URLS="http://10.0.1.30:2380"
-- ETCD_INITIAL_CLUSTER="etcd1=http://10.0.1.30:2380,etcd2=http://10.0.1.31:2380,etcd3=http://10.0.1.32:2380"
-- ETCD_INITIAL_CLUSTER_STATE="new"
-- ETCD_INITIAL_CLUSTER_TOKEN="pg-etcd-cluster"

-- Repeat for etcd2 (10.0.1.31) and etcd3 (10.0.1.32)
-- changing ETCD_NAME and advertise URLs

-- Start and verify:
-- sudo systemctl start etcd
-- etcdctl endpoint health
-- etcdctl member list

-- ============================================================
-- 2. PATRONI CONFIGURATION
-- ============================================================

-- /etc/patroni/patroni.yml on node1 (10.0.1.10):

-- scope: pg-cluster
-- name: node1
--
-- restapi:
--   listen: 0.0.0.0:8008
--   connect_address: 10.0.1.10:8008
--
-- etcd3:
--   hosts: 10.0.1.30:2379,10.0.1.31:2379,10.0.1.32:2379
--
-- bootstrap:
--   dcs:
--     ttl: 30
--     loop_wait: 10
--     retry_timeout: 10
--     maximum_lag_on_failover: 1048576
--     postgresql:
--       use_pg_rewind: true
--       parameters:
--         max_connections: 200
--         shared_buffers: 2GB
--         wal_level: replica
--         max_wal_senders: 10
--         max_replication_slots: 10
--         hot_standby: on
--   initdb:
--     - encoding: UTF8
--     - data-checksums
--
-- postgresql:
--   listen: 0.0.0.0:5432
--   connect_address: 10.0.1.10:5432
--   data_dir: /var/lib/postgresql/16/main
--   authentication:
--     replication:
--       username: repl_user
--       password: repl_password
--     superuser:
--       username: postgres
--       password: pg_password

-- For node2: change name to "node2", connect_address to 10.0.1.20
-- For node3: change name to "node3", connect_address to 10.0.1.25

-- Install and start Patroni:
-- sudo apt install patroni
-- sudo systemctl start patroni
-- sudo systemctl enable patroni

-- ============================================================
-- 3. HAPROXY CONFIGURATION
-- ============================================================

-- /etc/haproxy/haproxy.cfg:

-- global
--     maxconn 1000
--
-- defaults
--     mode tcp
--     timeout connect 10s
--     timeout client 30m
--     timeout server 30m
--
-- listen stats
--     bind *:7000
--     mode http
--     stats enable
--     stats uri /
--
-- listen pg_primary
--     bind *:5000
--     option httpchk GET /primary
--     http-check expect status 200
--     default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
--     server node1 10.0.1.10:5432 maxconn 100 check port 8008
--     server node2 10.0.1.20:5432 maxconn 100 check port 8008
--     server node3 10.0.1.25:5432 maxconn 100 check port 8008
--
-- listen pg_replicas
--     bind *:5001
--     balance roundrobin
--     option httpchk GET /replica
--     http-check expect status 200
--     default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
--     server node1 10.0.1.10:5432 maxconn 100 check port 8008
--     server node2 10.0.1.20:5432 maxconn 100 check port 8008
--     server node3 10.0.1.25:5432 maxconn 100 check port 8008

-- Start HAProxy:
-- sudo systemctl start haproxy
-- sudo systemctl enable haproxy

-- Application connection strings:
-- Writes: psql -h haproxy-host -p 5000 -U app_user myapp
-- Reads:  psql -h haproxy-host -p 5001 -U app_user myapp
-- Stats:  http://haproxy-host:7000/

-- ============================================================
-- 4. CLUSTER OPERATIONS
-- ============================================================

-- Check cluster status:
-- patronictl -c /etc/patroni/patroni.yml list

-- Planned switchover (zero downtime):
-- patronictl -c /etc/patroni/patroni.yml switchover

-- Reinitialize a failed node:
-- patronictl -c /etc/patroni/patroni.yml reinit pg-cluster node1

-- Restart PostgreSQL on a node (through Patroni):
-- patronictl -c /etc/patroni/patroni.yml restart pg-cluster node1

-- Edit cluster configuration:
-- patronictl -c /etc/patroni/patroni.yml edit-config

-- ============================================================
-- 5. MONITORING QUERIES
-- ============================================================

-- Check replication status (on primary):
SELECT client_addr, state, sent_lsn, replay_lsn,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes,
    pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag_pretty
FROM pg_stat_replication;

-- Check if this node is primary or standby:
SELECT pg_is_in_recovery();  -- FALSE = primary, TRUE = standby

-- Patroni REST API health checks:
-- curl http://10.0.1.10:8008/primary    → 200 if leader
-- curl http://10.0.1.10:8008/replica    → 200 if standby
-- curl http://10.0.1.10:8008/health     → 200 if healthy
-- curl http://10.0.1.10:8008/cluster    → JSON cluster info

-- etcd health check:
-- etcdctl endpoint health --cluster
-- etcdctl endpoint status --cluster --write-out=table

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Build multi-tenant schema. Insert 3 tenants with users and tasks.
--    Test RLS: SET app.current_tenant = '1'; SELECT * FROM tasks;
--    Verify tenant 2's data is invisible.

-- 2. Try inserting a row for the wrong tenant (should fail with RLS).

-- 3. Set up Patroni on 3 nodes (or 3 ports on one machine for testing):
--    Node1: port 5433, Node2: port 5434, Node3: port 5435
--    etcd: port 2379

-- 4. Configure HAProxy with primary (port 5000) and replica (port 5001).
--    Test: psql -p 5000 (writes), psql -p 5001 (reads).

-- 5. Kill the primary Patroni process. Measure time until new leader.
--    Target: under 30 seconds.
--    Restart killed node. Verify it rejoins as replica.

-- ============================================================
-- CLEANUP
-- ============================================================

-- DROP TABLE IF EXISTS tasks, projects, users, tenants CASCADE;
-- DROP ROLE IF EXISTS app_user;
