-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Authentication Methods (Classes 232-233)
-- Phase 27: Security
-- ============================================================

-- ============================================================
-- 1. CHECK CURRENT AUTHENTICATION SETTINGS
-- ============================================================

-- Check password encryption method:
SHOW password_encryption;
-- PostgreSQL 16 default: scram-sha-256

-- View current pg_hba.conf location:
SHOW hba_file;
-- Default: /etc/postgresql/16/main/pg_hba.conf (Debian)
-- Default: /var/lib/pgsql/16/data/pg_hba.conf (RHEL)

-- View pg_ident.conf location:
SHOW ident_file;

-- View current authentication rules (PG 16):
SELECT line_number, type, database, user_name, address, auth_method
FROM pg_hba_file_rules
ORDER BY line_number;

-- ============================================================
-- 2. CREATE ROLES WITH SCRAM-SHA-256 PASSWORDS
-- ============================================================

-- Verify encryption is SCRAM:
SHOW password_encryption;

-- Create an application user:
CREATE ROLE app_user WITH LOGIN PASSWORD 'Str0ng_P@ss_2026!';

-- Create a monitoring user:
CREATE ROLE monitoring WITH LOGIN PASSWORD 'M0n1t0r_S3cure!';

-- Create a replication user:
CREATE ROLE repl_user WITH LOGIN REPLICATION PASSWORD 'R3pl_S3cure!';

-- Create an admin user:
CREATE ROLE admin_user WITH LOGIN SUPERUSER PASSWORD 'Adm1n_Str0ng!';

-- Verify stored hash format (SCRAM-SHA-256):
SELECT rolname, LEFT(rolpassword, 20) AS hash_prefix
FROM pg_authid
WHERE rolname IN ('app_user', 'monitoring', 'repl_user', 'admin_user');

-- ============================================================
-- 3. pg_hba.conf — AUTHENTICATION METHODS REFERENCE
-- ============================================================

-- trust     : No verification at all (DANGEROUS in production)
-- reject    : Always deny connection
-- password  : Cleartext password (NEVER use)
-- md5       : MD5-hashed password (legacy, vulnerable to pass-the-hash)
-- scram-sha-256 : Modern challenge-response (RECOMMENDED)
-- peer      : OS username must match DB role (local only)
-- ident     : OS username via ident server (network, rarely used)
-- cert      : TLS client certificate (strongest)
-- ldap      : LDAP/Active Directory
-- radius    : RADIUS server
-- gss       : Kerberos/GSSAPI (SSO)

-- ============================================================
-- 4. SAMPLE PRODUCTION pg_hba.conf
-- ============================================================

-- Copy this template and adjust IPs for your environment:

-- # TYPE    DATABASE        USER            ADDRESS          METHOD
--
-- # 1. Local DBA access (Unix socket, peer auth)
-- local   all             postgres                         peer
-- local   all             all                              scram-sha-256
--
-- # 2. Replication from standby servers (SSL required)
-- hostssl replication      repl_user       10.0.0.11/32     scram-sha-256
-- hostssl replication      repl_user       10.0.0.12/32     scram-sha-256
--
-- # 3. Application connections from app subnet
-- hostssl app_db          app_user        10.0.1.0/24      scram-sha-256
--
-- # 4. Monitoring from monitoring subnet
-- hostssl all             monitoring      10.0.3.0/24      scram-sha-256
--
-- # 5. Admin access from VPN with client certs
-- hostssl all             admin_user      10.0.2.0/24      cert
--
-- # 6. Reject everything else
-- host    all             all             0.0.0.0/0        reject
-- host    all             all             ::0/0            reject

-- ============================================================
-- 5. pg_ident.conf — USERNAME MAPPING
-- ============================================================

-- File location:
-- SHOW ident_file;

-- Format:
-- # MAPNAME       SYSTEM-USERNAME   PG-USERNAME
-- admin_map       john_smith        admin_user
-- admin_map       jane_doe          admin_user
-- app_map         deploy_bot        app_user
-- app_map         webapp            app_user

-- Reference in pg_hba.conf:
-- local   all   admin_user   peer   map=admin_map
-- local   app_db app_user    peer   map=app_map

-- ============================================================
-- 6. LDAP AUTHENTICATION SETUP
-- ============================================================

-- Simple Bind mode in pg_hba.conf:
-- host all all 10.0.0.0/8 ldap
--   ldapserver=ldap.company.com
--   ldapport=389
--   ldapprefix="uid="
--   ldapsuffix=",ou=people,dc=company,dc=com"

-- Search + Bind mode (more flexible):
-- host all all 10.0.0.0/8 ldap
--   ldapserver=ldap.company.com
--   ldapbasedn="ou=people,dc=company,dc=com"
--   ldapbinddn="cn=pgbind,ou=service,dc=company,dc=com"
--   ldapbindpasswd="service_password"
--   ldapsearchattribute="uid"

-- ============================================================
-- 7. RELOAD AFTER CHANGES
-- ============================================================

-- From SQL:
SELECT pg_reload_conf();

-- From shell:
-- sudo systemctl reload postgresql-16

-- Verify reload worked:
SELECT pg_conf_load_time();

-- View any errors in pg_hba.conf:
SELECT line_number, error
FROM pg_hba_file_rules
WHERE error IS NOT NULL;

-- ============================================================
-- 8. TROUBLESHOOTING
-- ============================================================

-- Check which rule matched a specific connection:
-- Enable log_connections in postgresql.conf:
-- ALTER SYSTEM SET log_connections = on;
-- SELECT pg_reload_conf();

-- Then check the log for:
-- LOG: connection authorized: user=app_user database=app_db
-- LOG: connection received: host=10.0.1.50 port=43210

-- Common errors:
-- FATAL: no pg_hba.conf entry for host "...", user "...", database "..."
--   → No rule matches. Check IP, user, database, and rule order.
--
-- FATAL: password authentication failed for user "..."
--   → Wrong password, or md5/scram mismatch.
--
-- FATAL: Peer authentication failed for user "..."
--   → OS username does not match DB role name. Use pg_ident.conf.

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Run: SELECT * FROM pg_hba_file_rules;
--    Identify each rule's purpose.

-- 2. Create a role with SCRAM password. Add a hostssl rule
--    in pg_hba.conf. Reload and test the connection.

-- 3. Set up peer auth with pg_ident.conf:
--    Map your OS username to a PostgreSQL role.

-- 4. Write a complete production pg_hba.conf for:
--    - App server at 10.0.1.0/24
--    - Standby at 10.0.0.11/32
--    - Admin VPN at 10.0.2.0/24

-- 5. Create the md5/SCRAM mismatch error:
--    SET password_encryption = 'scram-sha-256';
--    CREATE ROLE test_user LOGIN PASSWORD 'test';
--    Then use method 'md5' in pg_hba.conf. Observe the error.

-- ============================================================
-- CLEANUP
-- ============================================================
-- DROP ROLE IF EXISTS app_user;
-- DROP ROLE IF EXISTS monitoring;
-- DROP ROLE IF EXISTS repl_user;
-- DROP ROLE IF EXISTS admin_user;
