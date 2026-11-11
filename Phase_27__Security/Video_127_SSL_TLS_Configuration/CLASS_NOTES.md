# SSL/TLS Configuration
**Series:** PostgreSQL Mastery | **Phase:** Phase 27: Security | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In the previous class, we covered authentication methods — how PostgreSQL decides who gets in. But even with strong authentication, there is a problem. If the connection between client and server is not encrypted, anyone on the network can read your data, your queries, and even your passwords as they travel across the wire. Today we set up SSL/TLS encryption for PostgreSQL from scratch — from generating certificates to configuring the server and client, all the way to mutual TLS where both sides verify each other. Let us begin.

### The Problem — Unencrypted Database Traffic
Picture this. Your application server connects to your database server over the company network. The app sends a query: SELECT credit_card_number, ssn FROM customers. The response with all that sensitive data travels back across the network in plain text. Anyone with a packet sniffer on that network — a compromised switch, a rogue employee, a misconfigured VLAN — can read every byte. Even your SCRAM password exchange, while the password itself is protected, the subsequent queries and results are not encrypted. SSL/TLS wraps the entire connection in encryption so no one can read it, even if they capture every packet.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should understand authentication methods and pg_hba.conf from the previous class. You should also know basic Linux commands for file permissions and the openssl tool. Recap from the last class — we learned all authentication methods and built a production pg_hba.conf. Several of those rules used hostssl, which requires SSL. Today we make hostssl work by setting up the certificate infrastructure.

- Prerequisite: Authentication methods & pg_hba.conf
- Prerequisite: Basic Linux file permissions (chmod, chown)
- Prerequisite: openssl command line basics
- Recap: Built production pg_hba.conf with hostssl rules
- Now: Making SSL work — certificates, server config, client config

### SSL/TLS Certificate Files
SSL/TLS uses certificates to establish encrypted connections. A certificate is like a digital ID card — it contains a name, a public key, and a signature from a Certificate Authority who vouches for the identity. The server always has a certificate. The client optionally has one too — that is mutual TLS. Here are the files involved. The server needs three files: a certificate, a private key, and optionally a CA certificate to verify client certs. The client needs the CA certificate to verify the server, and optionally its own certificate and key for mutual TLS.

| Term | Meaning / Explanation |
| :--- | :--- |
| **server.crt** | Server certificate — contains server identity + public key |
| **server.key** | Server private key — MUST be readable only by postgres user (chmod 600) |
| **root.crt (server)** | CA certificate — used to verify client certificates (mutual TLS) |
| **root.crt (client)** | CA certificate — used to verify the server certificate |
| **client.crt** | Client certificate — for cert-based authentication (mutual TLS) |
| **client.key** | Client private key — MUST be protected (chmod 600) |

**Notes:**
- Minimum for server-only SSL: server.crt + server.key
- Mutual TLS adds: root.crt on both sides + client.crt + client.key

### Client sslmode Options
On the client side, there are five SSL modes that control how the client handles encryption. disable means no SSL at all. allow means try without SSL first, fall back to SSL if rejected. prefer means try SSL first, fall back to plain if SSL fails — this is the default. require means SSL is mandatory but the server certificate is NOT verified. verify-ca means SSL is mandatory AND the server certificate must be signed by a trusted CA. verify-full means SSL mandatory, CA verified, AND the server hostname must match the certificate CN. For production, always use verify-full.

| Term | Meaning / Explanation |
| :--- | :--- |
| **On the client side** | there are five SSL modes that control how the client handles encryption |
| **Point 2** | disable means no SSL at all |
| **allow means try without SSL first** | fall back to SSL if rejected |
| **prefer means try SSL first** | fall back to plain if SSL fails — this is the default |
| **Point 5** | require means SSL is mandatory but the server certificate is NOT verified |
| **Point 6** | verify-ca means SSL is mandatory AND the server certificate must be signed by a trusted CA |
| **verify-full means SSL mandatory** | CA verified, AND the server hostname must match the certificate CN |
| **For production** | always use verify-full |

### Support This Free Course
If you are learning from this course, here is how you can support the work. Like this video. Share it with someone learning PostgreSQL. Subscribe and hit the bell icon. Download today's class materials from the link in the description. And if this free course is helping you, consider supporting through the donation link. Now let us continue with client configuration and mutual TLS.

- Like this video — helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + bell icon for new classes
- Download class materials (link in description)
- Support this free course: donation link in description

### Certificate Rotation — Zero Downtime
Certificate rotation is something you will do regularly — server certificates typically expire yearly, and you need to replace them without downtime. The good news is that PostgreSQL can reload certificates without a restart. Just replace the certificate files on disk and reload the configuration. Active connections keep using the old certificate until they reconnect. New connections use the new certificate.

- 1. Generate new server certificate signed by same CA
- 2. Replace server.crt and server.key on disk
- 3. Set correct permissions: chmod 600 server.key
- 4. Reload PostgreSQL: SELECT pg_reload_conf()
- 5. Existing connections keep old cert (until reconnect)
- 6. New connections use the new certificate
- 7. Verify: SELECT * FROM pg_stat_ssl;
- No restart needed! No downtime!

### Complete SSL/TLS Architecture
Here is the complete SSL setup workflow as an architecture view. The CA signs both server and client certificates. The server presents its cert to prove identity. The client optionally presents its cert for mutual TLS. The pg_hba.conf hostssl rules enforce encrypted connections. And pg_stat_ssl lets you monitor everything.

```
[Certificate
Authority (CA)]
[Server
server.crt + server.key]
[Client
client.crt + client.key]
[pg_hba.conf
hostssl rules]
[pg_stat_ssl
Monitoring]
```

### Practice Exercises
Here are your practice exercises. One — generate a self-signed CA and server certificate. Configure PostgreSQL SSL and verify it works. Two — connect from psql with sslmode=verify-full and confirm the TLS version and cipher. Three — generate a client certificate and set up mutual TLS with cert authentication. Four — try connecting with wrong permissions on server.key and see the exact error. Five — rotate the server certificate without restarting PostgreSQL.

- 1. Generate CA + server cert, enable SSL, verify with SHOW ssl
- 2. Connect with sslmode=verify-full, check pg_stat_ssl
- 3. Generate client cert, configure mutual TLS + cert auth
- 4. Intentionally set bad permissions on server.key — observe error
- 5. Rotate server certificate with pg_reload_conf() — zero downtime


---

## 3. Hands-On Commands & psql Output

### Step 1 — Create Certificate Authority
**Explanation:** Let us generate all certificates from scratch. We will create our own Certificate Authority, then use it to sign both server and client certificates. In production, you would use a real CA like Let's Encrypt or your company's internal CA. But the process is identical — the only difference is who signs the certificate. Step one — create the CA private key and self-signed CA certificate.

```sql
$ mkdir -p /etc/postgresql/16/main/certs
$ cd /etc/postgresql/16/main/certs

# Generate CA private key (4096-bit RSA)
$ openssl genrsa -out ca.key 4096
Generating RSA private key, 4096 bit long modulus
..........++
e is 65537 (0x10001)

# Create self-signed CA certificate (valid 10 years)
$ openssl req -new -x509 -days 3650 -key ca.key -out ca.crt \
>   -subj "/CN=PostgreSQL Internal CA/O=MyCompany"

# Verify the CA certificate
$ openssl x509 -in ca.crt -noout -subject -dates
subject=CN = PostgreSQL Internal CA, O = MyCompany
notBefore=Nov  4 10:00:00 2026 GMT
notAfter=Nov  2 10:00:00 2036 GMT
```

### Step 2 — Generate Server Certificate
**Explanation:** Step two — generate the server certificate. We create a private key for the server, then a Certificate Signing Request, and then sign it with our CA. The Common Name in the server certificate should match the hostname that clients use to connect. This is how the client verifies it is talking to the right server.

```sql
# Generate server private key
$ openssl genrsa -out server.key 2048
Generating RSA private key, 2048 bit long modulus

# Create CSR (Certificate Signing Request)
$ openssl req -new -key server.key -out server.csr \
>   -subj "/CN=db-primary.mycompany.com"

# Sign with our CA (valid 1 year)
$ openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
>   -CAcreateserial -out server.crt -days 365
Signature ok
subject=CN = db-primary.mycompany.com
Getting CA Private Key

# CRITICAL: Restrict key permissions
$ chmod 600 server.key
$ chown postgres:postgres server.key server.crt
```

### Step 3 — Generate Client Certificate
**Explanation:** Step three — generate a client certificate for mutual TLS. The Common Name must match the PostgreSQL role name that the client will use to connect. This is how PostgreSQL maps the certificate to a database user when using cert authentication.

```sql
# Generate client private key
$ openssl genrsa -out client.key 2048

# Create CSR — CN must match PostgreSQL role name!
$ openssl req -new -key client.key -out client.csr \
>   -subj "/CN=admin_user"

# Sign with the same CA
$ openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key \
>   -CAcreateserial -out client.crt -days 365
Signature ok
subject=CN = admin_user

# Protect client key
$ chmod 600 client.key

# Copy ca.crt and client files to client machine:
# ~/.postgresql/root.crt    (CA cert)
# ~/.postgresql/postgresql.crt  (client cert)
# ~/.postgresql/postgresql.key  (client key)
```

### Restart and Verify SSL
**Explanation:** After editing postgresql.conf, restart PostgreSQL. A reload is not enough for SSL changes — you need a full restart. Then verify SSL is active.

```sql
# Restart required for SSL changes (reload is NOT enough)
$ sudo systemctl restart postgresql-16

# Verify SSL is enabled
postgres=# SHOW ssl;
 ssl
-----
 on

# Check SSL details on current connection
postgres=# SELECT * FROM pg_stat_ssl WHERE pid = pg_backend_pid();
  pid  | ssl | version |         cipher         | bits | client_dn | client_serial | issuer_dn
-------+-----+---------+------------------------+------+-----------+---------------+----------
 12345 | t   | TLSv1.3 | TLS_AES_256_GCM_SHA384 |  256 |           |               |

# View all SSL connections
postgres=# SELECT pid, ssl, version, cipher, bits FROM pg_stat_ssl;
```

### Client Connection with SSL Verification
**Explanation:** Let us connect from the client with SSL verification. The client needs the CA certificate to verify the server. By default, psql looks for it at ~/.postgresql/root.crt. You can also specify it with the sslrootcert parameter. Let us connect with verify-full to ensure both encryption and server identity verification.

```sql
# Copy CA cert to client machine's default location
$ mkdir -p ~/.postgresql
$ cp ca.crt ~/.postgresql/root.crt
$ chmod 600 ~/.postgresql/root.crt

# Connect with full verification
$ psql "host=db-primary.mycompany.com dbname=app_db user=app_user sslmode=verify-full"
Password for user app_user:
psql (16.4)
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off)
Type "help" for help.

app_db=> SELECT ssl, version, cipher FROM pg_stat_ssl WHERE pid = pg_backend_pid();
 ssl | version |         cipher
-----+---------+------------------------
 t   | TLSv1.3 | TLS_AES_256_GCM_SHA384
```

### Mutual TLS — Client Certificate Authentication
**Explanation:** Now the strongest setup — mutual TLS. Both the server and client present certificates. The server verifies the client certificate against the CA, and PostgreSQL uses the certificate CN as the username — no password needed. This is the cert authentication method we discussed in the previous class. Let us connect using client certificate authentication.

```sql
# Client needs these files in ~/.postgresql/
#   root.crt         → CA certificate (verify server)
#   postgresql.crt    → Client certificate (CN = role name)
#   postgresql.key    → Client private key (chmod 600)

$ cp client.crt ~/.postgresql/postgresql.crt
$ cp client.key ~/.postgresql/postgresql.key
$ chmod 600 ~/.postgresql/postgresql.key

# pg_hba.conf rule for cert auth:
# hostssl all admin_user 10.0.2.0/24 cert

# Connect — no password prompt!
$ psql "host=db-primary.mycompany.com dbname=postgres user=admin_user sslmode=verify-full"
psql (16.4)
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off)

postgres=# -- No password was asked! Certificate CN matched role name.
```

### Certificate Revocation List (CRL)
**Explanation:** Certificate revocation is how you invalidate a compromised certificate before it expires. If a client machine is stolen or a private key is leaked, you need to revoke that certificate immediately. PostgreSQL supports Certificate Revocation Lists. You generate a CRL from the CA, reference it in postgresql.conf, and any certificate on that list is rejected even if it is otherwise valid.

```sql
# Revoke a compromised client certificate
$ openssl ca -revoke client.crt -keyfile ca.key -cert ca.crt
Revoking Certificate 01.

# Generate the CRL file
$ openssl ca -gencrl -keyfile ca.key -cert ca.crt -out root.crl

# Add to postgresql.conf:
# ssl_crl_file = '/etc/postgresql/16/main/certs/root.crl'

# Reload (CRL changes don't need restart)
postgres=# SELECT pg_reload_conf();

-- Now the revoked certificate is rejected even though it hasn't expired
```

### Beginner Traps — Real Error Messages
**Explanation:** A common beginner trap: the server key file has wrong permissions. PostgreSQL refuses to start if server.key is readable by anyone other than the postgres user. You will see the error could not load server private key file — permission denied, or private key file has group or world access. The fix is always chmod 600 and chown postgres. Another trap: using sslmode=require and thinking you are safe. Require only ensures encryption — it does NOT verify who the server is. An attacker could present a fake certificate and you would connect to them instead. Use verify-full for real security.

```sql
-- Trap 1: Wrong key permissions
FATAL: could not load private key file "/etc/postgresql/16/main/certs/server.key":
  Permission denied
-- OR:
FATAL: private key file "/etc/postgresql/16/main/certs/server.key"
  has group or world access

-- Fix:
$ chmod 600 /etc/postgresql/16/main/certs/server.key
$ chown postgres:postgres /etc/postgresql/16/main/certs/server.key

-- Trap 2: sslmode=require does NOT verify server identity!
-- An attacker can present a FAKE certificate
-- Use sslmode=verify-full for real security
-- Trap 3: CN mismatch
psql: error: server certificate for "db-primary.mycompany.com" does not
  match host name "10.0.0.10"
-- Fix: Connect using hostname, not IP, or add SAN to cert
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf` — postgresql.conf — SSL Configuration
Now let us configure PostgreSQL to use SSL. We edit postgresql.conf to enable SSL and point to the certificate files. The ssl setting turns SSL on. ssl_cert_file and ssl_key_file point to the server certificate and key. ssl_ca_file points to the CA certificate — this is needed to verify client certificates in mutual TLS. ssl_min_protocol_version should be set to TLSv1.2 or TLSv1.3 — older versions have known vulnerabilities. You can apply these parameters without downtime by executing SELECT pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `ssl` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | Enable SSL connections (Default: off) |
| `ssl_cert_file` | `/etc/postgresql/16/main/certs/server.crt` | `[RELOAD]` (Live Reload `SIGHUP`) | Server certificate (Default: 'server.crt') |
| `ssl_key_file` | `/etc/postgresql/16/main/certs/server.key` | `[RELOAD]` (Live Reload `SIGHUP`) | Server private key (Default: 'server.key') |
| `ssl_ca_file` | `/etc/postgresql/16/main/certs/ca.crt` | `[RELOAD]` (Live Reload `SIGHUP`) | CA cert (for client verification) (Default: '') |
| `ssl_min_protocol_version` | `TLSv1.2` | `[SETTING]` | Minimum TLS version (reject TLSv1.0/1.1) |
| `ssl_ciphers` | `HIGH:!aNULL:!MD5` | `[SETTING]` | Strong ciphers only |
| `ssl_prefer_server_ciphers` | `on` | `[SETTING]` | Server chooses cipher, not client |


### File: `pg_hba.conf` — pg_hba.conf — Enforce SSL Connections
Now let us update pg_hba.conf to enforce SSL. Remember, host allows both SSL and non-SSL connections. hostssl allows ONLY SSL connections. hostnossl allows ONLY non-SSL connections. For security, use hostssl for all network connections and reject unencrypted traffic.

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `local     all       postgres                   peer` | `` | `[SETTING]` |  |
| `local     all       all                        scram-sha-256` | `` | `[SETTING]` |  |
| `hostssl   all       all         10.0.0.0/8     scram-sha-256` | `` | `[SETTING]` |  |
| `hostnossl all       all         0.0.0.0/0      reject` | `` | `[SETTING]` |  |
| `hostnossl all       all         ::0/0          reject` | `` | `[SETTING]` |  |
| `host      all       all         0.0.0.0/0      reject` | `` | `[SETTING]` |  |
| `host      all       all         ::0/0          reject` | `` | `[SETTING]` |  |



---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps — Real Error Messages
A common beginner trap: the server key file has wrong permissions. PostgreSQL refuses to start if server.key is readable by anyone other than the postgres user. You will see the error could not load server private key file — permission denied, or private key file has group or world access. The fix is always chmod 600 and chown postgres. Another trap: using sslmode=require and thinking you are safe. Require only ensures encryption — it does NOT verify who the server is. An attacker could present a fake certificate and you would connect to them instead. Use verify-full for real security.

```sql
-- Trap 1: Wrong key permissions
FATAL: could not load private key file "/etc/postgresql/16/main/certs/server.key":
  Permission denied
-- OR:
FATAL: private key file "/etc/postgresql/16/main/certs/server.key"
  has group or world access

-- Fix:
chmod 600 /etc/postgresql/16/main/certs/server.key
chown postgres:postgres /etc/postgresql/16/main/certs/server.key

-- Trap 2: sslmode=require does NOT verify server identity!
-- An attacker can present a FAKE certificate
-- Use sslmode=verify-full for real security
-- Trap 3: CN mismatch
psql: error: server certificate for "db-primary.mycompany.com" does not
  match host name "10.0.0.10"
-- Fix: Connect using hostname, not IP, or add SAN to cert
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. SSL/TLS encrypts all traffic between client and server — queries, results, everything. The server needs ssl=on, a certificate, and a private key with strict permissions. Use hostssl in pg_hba.conf to enforce encrypted connections. Clients should use sslmode=verify-full — not just require. Mutual TLS adds client certificates for the strongest authentication. Certificate rotation works with just a reload — no restart needed. And always set ssl_min_protocol_version to TLSv1.2 or higher.

- **ssl = on + server.crt + server.key (chmod 600)**
- **hostssl in pg_hba.conf enforces encrypted connections**
- **Client: sslmode=verify-full (NOT just require)**
- **Mutual TLS: client cert CN must match PostgreSQL role name**
- **ssl_min_protocol_version = TLSv1.2 (reject old versions)**
- **Certificate rotation: replace files + pg_reload_conf()**
- **CRL: revoke compromised certificates immediately**
- **Restart required for initial SSL enable; reload for cert changes**


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
