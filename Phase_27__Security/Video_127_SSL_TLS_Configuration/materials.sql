-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- SSL/TLS Configuration (Classes 234-235)
-- Phase 27: Security
-- ============================================================

-- ============================================================
-- 1. GENERATE CERTIFICATE AUTHORITY (CA)
-- ============================================================

-- Create directory for certs:
-- mkdir -p /etc/postgresql/16/main/certs
-- cd /etc/postgresql/16/main/certs

-- Generate CA private key (4096-bit RSA):
-- openssl genrsa -out ca.key 4096

-- Create self-signed CA certificate (valid 10 years):
-- openssl req -new -x509 -days 3650 -key ca.key -out ca.crt \
--   -subj "/CN=PostgreSQL Internal CA/O=MyCompany"

-- Verify CA certificate:
-- openssl x509 -in ca.crt -noout -subject -dates

-- ============================================================
-- 2. GENERATE SERVER CERTIFICATE
-- ============================================================

-- Generate server private key:
-- openssl genrsa -out server.key 2048

-- Create CSR (CN = server hostname):
-- openssl req -new -key server.key -out server.csr \
--   -subj "/CN=db-primary.mycompany.com"

-- Sign with CA (valid 1 year):
-- openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
--   -CAcreateserial -out server.crt -days 365

-- CRITICAL: Set permissions
-- chmod 600 server.key
-- chown postgres:postgres server.key server.crt

-- ============================================================
-- 3. GENERATE CLIENT CERTIFICATE (for Mutual TLS)
-- ============================================================

-- Generate client key:
-- openssl genrsa -out client.key 2048

-- Create CSR (CN = PostgreSQL role name):
-- openssl req -new -key client.key -out client.csr \
--   -subj "/CN=admin_user"

-- Sign with CA:
-- openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key \
--   -CAcreateserial -out client.crt -days 365

-- Protect client key:
-- chmod 600 client.key

-- Client file locations (default):
-- ~/.postgresql/root.crt         (CA certificate)
-- ~/.postgresql/postgresql.crt   (client certificate)
-- ~/.postgresql/postgresql.key   (client private key)

-- ============================================================
-- 4. SERVER CONFIGURATION — postgresql.conf
-- ============================================================

-- Enable SSL:
ALTER SYSTEM SET ssl = on;
-- ssl_cert_file = '/etc/postgresql/16/main/certs/server.crt'
-- ssl_key_file  = '/etc/postgresql/16/main/certs/server.key'
-- ssl_ca_file   = '/etc/postgresql/16/main/certs/ca.crt'

-- Security settings:
-- ssl_min_protocol_version = 'TLSv1.2'
-- ssl_ciphers = 'HIGH:!aNULL:!MD5'
-- ssl_prefer_server_ciphers = on

-- Restart required (not reload!) for initial SSL enable:
-- sudo systemctl restart postgresql-16

-- ============================================================
-- 5. VERIFY SSL IS ACTIVE
-- ============================================================

SHOW ssl;
-- Should return: on

-- Check SSL on current connection:
SELECT ssl, version, cipher, bits
FROM pg_stat_ssl
WHERE pid = pg_backend_pid();

-- View ALL SSL connections:
SELECT pid, datname, usename, ssl, version, cipher, bits, client_dn
FROM pg_stat_ssl
JOIN pg_stat_activity USING (pid);

-- ============================================================
-- 6. pg_hba.conf — ENFORCE SSL
-- ============================================================

-- Use hostssl for encrypted connections:
-- hostssl  all  all  10.0.0.0/8  scram-sha-256

-- Reject non-SSL connections:
-- hostnossl all  all  0.0.0.0/0  reject
-- hostnossl all  all  ::0/0      reject

-- Mutual TLS with cert auth:
-- hostssl  all  admin_user  10.0.2.0/24  cert

-- Reload after pg_hba.conf changes:
SELECT pg_reload_conf();

-- ============================================================
-- 7. CLIENT CONNECTION
-- ============================================================

-- Copy CA cert to client:
-- mkdir -p ~/.postgresql
-- cp ca.crt ~/.postgresql/root.crt
-- chmod 600 ~/.postgresql/root.crt

-- Connect with full verification:
-- psql "host=db-primary.mycompany.com dbname=app_db
--       user=app_user sslmode=verify-full"

-- Connection string with explicit cert paths:
-- psql "host=db-primary.mycompany.com dbname=app_db
--       user=admin_user sslmode=verify-full
--       sslcert=~/.postgresql/postgresql.crt
--       sslkey=~/.postgresql/postgresql.key
--       sslrootcert=~/.postgresql/root.crt"

-- ============================================================
-- 8. SSL MODES REFERENCE
-- ============================================================

-- disable       : No SSL
-- allow         : Try plain first, SSL if rejected
-- prefer        : Try SSL first, plain if fails (DEFAULT)
-- require       : SSL required, server NOT verified
-- verify-ca     : SSL + CA verified
-- verify-full   : SSL + CA + hostname verified (RECOMMENDED)

-- ============================================================
-- 9. CERTIFICATE REVOCATION
-- ============================================================

-- Revoke a certificate:
-- openssl ca -revoke client.crt -keyfile ca.key -cert ca.crt

-- Generate CRL:
-- openssl ca -gencrl -keyfile ca.key -cert ca.crt -out root.crl

-- Add to postgresql.conf:
-- ssl_crl_file = '/etc/postgresql/16/main/certs/root.crl'

-- Reload (no restart needed for CRL):
SELECT pg_reload_conf();

-- ============================================================
-- 10. CERTIFICATE ROTATION (Zero Downtime)
-- ============================================================

-- 1. Generate new server certificate (signed by same CA)
-- 2. Replace server.crt and server.key on disk
-- 3. chmod 600 server.key && chown postgres:postgres server.key
-- 4. Reload:
SELECT pg_reload_conf();
-- 5. New connections use new cert; existing connections keep old
-- 6. Verify:
SELECT * FROM pg_stat_ssl;

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Generate a CA and server certificate. Enable SSL and verify.

-- 2. Connect with sslmode=verify-full. Check pg_stat_ssl for
--    TLS version and cipher.

-- 3. Generate a client certificate. Set up mutual TLS with
--    cert authentication in pg_hba.conf.

-- 4. Intentionally set server.key to chmod 644. Try to start
--    PostgreSQL. Observe and fix the error.

-- 5. Rotate the server certificate using pg_reload_conf()
--    and verify new connections use the new certificate.

-- ============================================================
-- CLEANUP
-- ============================================================
-- To revert to non-SSL:
-- ALTER SYSTEM SET ssl = off;
-- sudo systemctl restart postgresql-16
-- Remove cert files from /etc/postgresql/16/main/certs/
