-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- HA Tools & Architecture (Classes 207-212)
-- Phase 24: Replication & High Availability
-- ============================================================

-- ============================================================
-- 1. PATRONI — KEY CONCEPTS
-- ============================================================

-- Patroni is a Python daemon that manages PostgreSQL HA.
-- It runs alongside each PostgreSQL instance and handles:
-- - Cluster bootstrapping
-- - Replication management
-- - Automatic failover
-- - Configuration management

-- Install Patroni:
-- pip install patroni[etcd]

-- Start Patroni:
-- patroni /etc/patroni.yml

-- ============================================================
-- 2. PATRONI CONFIGURATION (patroni.yml)
-- ============================================================

-- scope: pg-cluster
-- name: node1
--
-- etcd:
--   hosts: etcd1:2379,etcd2:2379,etcd3:2379
--
-- restapi:
--   listen: 0.0.0.0:8008
--   connect_address: 10.0.1.1:8008
--
-- postgresql:
--   listen: 0.0.0.0:5432
--   connect_address: 10.0.1.1:5432
--   data_dir: /var/lib/postgresql/16/main
--   authentication:
--     superuser:
--       username: postgres
--       password: SuperSecretPass
--     replication:
--       username: replicator
--       password: ReplPass123
--   parameters:
--     wal_level: replica
--     max_wal_senders: 10
--     max_replication_slots: 10
--     wal_keep_size: 1GB
--     hot_standby: 'on'
--
-- bootstrap:
--   dcs:
--     ttl: 30
--     loop_wait: 10
--     retry_timeout: 10
--     maximum_lag_on_failover: 1048576
--   initdb:
--     - encoding: UTF8
--     - data-checksums

-- ============================================================
-- 3. PATRONICTL — CLUSTER MANAGEMENT
-- ============================================================

-- Show cluster status:
-- patronictl -c /etc/patroni.yml list

-- Planned switchover:
-- patronictl -c /etc/patroni.yml switchover

-- Failover (when primary is gone):
-- patronictl -c /etc/patroni.yml failover

-- Restart a node's PostgreSQL:
-- patronictl -c /etc/patroni.yml restart pg-cluster node1

-- Edit cluster configuration:
-- patronictl -c /etc/patroni.yml edit-config

-- ============================================================
-- 4. PATRONI REST API
-- ============================================================

-- Check if primary:
-- curl -s http://10.0.1.1:8008/primary
-- HTTP 200 = yes, HTTP 503 = no

-- Check if replica:
-- curl -s http://10.0.1.10:8008/replica
-- HTTP 200 = yes

-- Cluster info:
-- curl -s http://10.0.1.1:8008/cluster

-- Trigger switchover via API:
-- curl -s -X POST http://10.0.1.1:8008/switchover \
--   -H "Content-Type: application/json" \
--   -d '{"leader":"node1","candidate":"node2"}'

-- ============================================================
-- 5. PGBOUNCER CONFIGURATION
-- ============================================================

-- /etc/pgbouncer/pgbouncer.ini:
-- [databases]
-- mydb = host=127.0.0.1 port=5432 dbname=mydb
--
-- [pgbouncer]
-- listen_addr = 0.0.0.0
-- listen_port = 6432
-- pool_mode = transaction
-- max_client_conn = 1000
-- default_pool_size = 50
-- min_pool_size = 10
-- reserve_pool_size = 10
-- auth_type = scram-sha-256
-- auth_file = /etc/pgbouncer/userlist.txt
-- log_connections = 0
-- log_disconnections = 0

-- userlist.txt format:
-- "myuser" "scram-sha-256$..."

-- Start PgBouncer:
-- pgbouncer -d /etc/pgbouncer/pgbouncer.ini

-- Connect through PgBouncer:
-- psql -h localhost -p 6432 -U myuser -d mydb

-- Monitor PgBouncer (admin console):
-- psql -h localhost -p 6432 -U pgbouncer -d pgbouncer
-- SHOW POOLS;
-- SHOW STATS;
-- SHOW CLIENTS;
-- SHOW SERVERS;

-- ============================================================
-- 6. HAPROXY CONFIGURATION
-- ============================================================

-- /etc/haproxy/haproxy.cfg:
--
-- frontend pg_write
--     bind *:5432
--     default_backend pg_primary
--
-- frontend pg_read
--     bind *:5433
--     default_backend pg_replicas
--
-- backend pg_primary
--     option httpchk GET /primary
--     http-check expect status 200
--     default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
--     server node1 10.0.1.1:6432 check port 8008
--     server node2 10.0.1.10:6432 check port 8008
--     server node3 10.0.1.11:6432 check port 8008
--
-- backend pg_replicas
--     option httpchk GET /replica
--     http-check expect status 200
--     balance roundrobin
--     default-server inter 3s fall 3 rise 2
--     server node1 10.0.1.1:6432 check port 8008
--     server node2 10.0.1.10:6432 check port 8008
--     server node3 10.0.1.11:6432 check port 8008

-- ============================================================
-- 7. APPLICATION CONNECTION STRINGS
-- ============================================================

-- Write connection (via HAProxy):
-- postgresql://myuser:pass@haproxy:5432/mydb

-- Read connection (via HAProxy):
-- postgresql://myuser:pass@haproxy:5433/mydb

-- Multi-host without HAProxy (libpq feature):
-- postgresql://myuser:pass@node1:5432,node2:5432,node3:5432/mydb
--   ?target_session_attrs=read-write

-- PG 16: target_session_attrs=primary (more explicit)

-- ============================================================
-- 8. REPMGR QUICK REFERENCE
-- ============================================================

-- Install: sudo apt install postgresql-16-repmgr
-- Config: /etc/repmgr.conf
-- Register primary: repmgr primary register
-- Clone standby:    repmgr standby clone -h primary_ip
-- Register standby: repmgr standby register
-- Show cluster:     repmgr cluster show
-- Switchover:       repmgr standby switchover

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Read through the Patroni documentation:
--    https://patroni.readthedocs.io

-- 2. If you have Docker, try the Patroni Docker example:
--    docker-compose up for a 3-node PG cluster with Patroni

-- 3. Install PgBouncer on your local machine.
--    Configure transaction pooling mode.
--    Connect your app through PgBouncer (port 6432).
--    Run SHOW POOLS; in the admin console.

-- 4. Test libpq multi-host connection:
--    psql "host=node1,node2 port=5432 dbname=mydb
--      target_session_attrs=read-write user=myuser"

-- 5. Design an HA architecture for your application.
--    How many PG nodes? How many etcd nodes?
--    Do you need read/write splitting?
--    Draw the architecture diagram.
