# Authentication Methods
**Series:** PostgreSQL Mastery | **Phase:** Phase 27: Security | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! We are now entering Phase 27 — Security. This is where we lock down your PostgreSQL database so only the right people can access it, and only in the right way. In this first class, we tackle authentication — the process of proving who you are before PostgreSQL lets you in. By the end, you will know every authentication method PostgreSQL supports, how pg_hba.conf works rule by rule, and how to choose the right method for every situation. Let us begin.

### The Problem — Real Attack Log
Imagine you are a database administrator. It is Monday morning. You check the PostgreSQL logs and see thousands of failed login attempts from IP addresses in countries where your company has no employees. Some attempts are trying common usernames like admin, root, and postgres. A few attempts even succeeded — because the default pg_hba.conf on some installations allows local connections without any password at all. This is not a hypothetical scenario. This happens to real databases every day. The fix starts with understanding authentication.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should know how to create roles and users from our Administration Basics phase. You should also understand pg_hba.conf basics from our configuration class. Quick recap — in Phase 26 we covered extensions including pgAudit for audit logging. Now we step back and secure the front door: who gets in, and how do they prove their identity? Authentication is the first layer of security. If this layer is weak, everything else — encryption, auditing, hardening — does not matter. An attacker who walks through the front door owns everything.

- Prerequisite: Creating roles and users (Phase 16)
- Prerequisite: pg_hba.conf basics (Phase 16)
- Recap: Phase 26 covered extensions (pgAudit, pg_cron, etc.)
- Now: Securing the front door — WHO gets in and HOW they prove it
- If authentication is weak, nothing else matters

### pg_hba.conf — The Five Fields
pg_hba.conf is the Host-Based Authentication file. HBA stands for Host-Based Authentication. Every line is a rule with five fields. TYPE is how the client connects — local for Unix sockets, host for TCP/IP, hostssl for encrypted TCP only, hostnossl for unencrypted TCP only, and hostgssenc for GSSAPI encrypted connections. DATABASE is which database — a specific name, all, sameuser, samerole, or replication. USER is which role — a specific name, all, or a group prefixed with plus. ADDRESS is the client IP range in CIDR notation — only for host-type rules, not for local. METHOD is the authentication method. Let us look at each field.

| Term | Meaning / Explanation |
| :--- | :--- |
| **TYPE** | Connection type: local, host, hostssl, hostnossl, hostgssenc |
| **DATABASE** | Target database: name, all, sameuser, samerole, replication |
| **USER** | Role name: specific name, all, or +group_name |
| **ADDRESS** | Client IP in CIDR: 192.168.1.0/24, 0.0.0.0/0, ::0/0 |
| **METHOD** | How to verify: trust, reject, scram-sha-256, md5, peer, cert, ldap... |

**Notes:**
- local rules have no ADDRESS field (Unix socket = same machine)
- Rules are checked TOP to BOTTOM — first match wins, no fallback

### Simple Methods: trust, reject, password
Let us look at the simplest methods first. Trust means no authentication at all — PostgreSQL believes whoever connects. This is extremely dangerous for production but useful for local development on your own machine. Reject means deny the connection immediately, no questions asked. This is useful for blocking specific users or IP ranges before a more permissive rule matches. Password sends the password in cleartext over the network — never use this, even on a local network. Anyone sniffing traffic can see the password.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Trust** | no authentication at all — PostgreSQL believes whoever connects |
| **This** | extremely dangerous for production but useful for local development on your own machine |
| **Reject** | deny the connection immediately, no questions asked |

### md5 vs scram-sha-256
Now the password-based methods that you should actually use. MD5 hashes the password before sending it over the network. The server stores an MD5 hash and the client sends an MD5 hash, so the cleartext password never travels on the wire. However, MD5 has known weaknesses — if someone steals the hash from pg_authid, they can use it to authenticate without knowing the actual password. SCRAM-SHA-256 is the modern standard, available since PostgreSQL 10. It uses a challenge-response protocol where the password never leaves the client, even as a hash. The server proves it knows the password too, preventing man-in-the-middle attacks. Always use scram-sha-256 for password authentication.

| md5 (Legacy) | scram-sha-256 (Recommended) |
| :--- | :--- |
| MD5 hash sent over network | Challenge-response protocol |
| Server stores MD5 hash in pg_authid | Password NEVER leaves the client |
| Stolen hash = instant authentication | Stolen hash cannot authenticate |
| No mutual authentication | Mutual authentication (server proves itself too) |
| Vulnerable to replay attacks | Resistant to replay and MITM attacks |
| Default before PostgreSQL 10 | Default since PostgreSQL 14 |

### ident Authentication — Network Peer
Ident authentication is similar to peer, but for TCP/IP connections. When a client connects over the network, PostgreSQL contacts an ident server running on the client machine to ask what OS user initiated the connection. The ident server must be running on the client at port 113. This method is rarely used today because ident servers are uncommon, the client machine must be trusted, and anyone with root on the client can fake the ident response. Prefer SCRAM or certificate authentication for network connections.

| Term | Meaning / Explanation |
| :--- | :--- |
| **How It Works** | PostgreSQL contacts an ident server (port 113) on the CLIENT machine |
| **Requirement** | Client must run an ident daemon (oidentd, pidentd) |
| **Trust Issue** | Root on client machine can fake the ident response |
| **Modern Status** | Rarely used — most systems do not run ident servers anymore |
| **Alternative** | Use scram-sha-256 or cert authentication for network connections |

### Support This Free Course
If you are learning from this course, here is how you can support the work. Like this video — it helps more people find this PostgreSQL course. Share it with someone learning databases. Subscribe and hit the bell icon so you do not miss any class. Download today's class materials from the link in the description. And if this free course is helping you, consider supporting through the donation link in the description. Every bit helps keep this course free and growing. Now let us continue with LDAP and enterprise authentication methods.

- Like this video — helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + bell icon for new classes
- Download class materials (link in description)
- Support this free course: donation link in description

### Enterprise Authentication Methods
RADIUS authentication sends the username and password to a RADIUS server. This is common in network environments where RADIUS is already deployed for WiFi and VPN authentication. GSSAPI uses Kerberos tickets for single sign-on in enterprise environments — users authenticate once with the domain controller and can then connect to PostgreSQL without entering a password again. Both methods require infrastructure that is already in place at your organization.

| Term | Meaning / Explanation |
| :--- | :--- |
| **This** | common in network environments where RADIUS is already deployed for WiFi and VPN authentication |
| **GSSAPI** | Kerberos tickets for single sign-on in enterprise environments — users authenticate once with the domain controller a... |
| **Both methods** | infrastructure that is already in place at your organization |

### Decision Framework — Choosing Auth Methods
Here is a decision framework for choosing the right authentication method. For local connections on the server itself, use peer — no passwords, just OS identity. For application connections over the network, use scram-sha-256 over SSL. For high-security admin connections, use certificate authentication. For enterprise environments with Active Directory, use LDAP or GSSAPI. Never use trust in production. Never use password. And prefer scram-sha-256 over md5.

| Scenario | Recommended Method |
| :--- | :--- |
| DBA on the server itself | peer (Unix socket) |
| Application → Database over LAN | scram-sha-256 + hostssl |
| Admin access from office VPN | cert (client certificates) |
| Enterprise with Active Directory | ldap or gss (Kerberos SSO) |
| Automated scripts on same server | peer with pg_ident.conf mapping |
| Replication connections | scram-sha-256 + hostssl + specific IPs |
| Public internet access | NEVER allow — use VPN + cert |

### Practice Exercises
Here are your practice exercises. One — check your current pg_hba.conf and identify every rule. What method does each use? Two — create a new role with a SCRAM password and add a pg_hba.conf rule for it. Test the connection. Three — set up peer authentication for a new OS user mapped to a database role using pg_ident.conf. Four — write a complete production pg_hba.conf for a scenario with an app server, a standby server, and an admin VPN. Five — intentionally create the hash mismatch error by using md5 method with a scram-sha-256 password, then fix it.

- 1. Read your pg_hba.conf — identify each rule's method and purpose
- 2. Create a SCRAM-authenticated role, add a pg_hba.conf rule, test it
- 3. Set up peer auth with pg_ident.conf mapping (OS user → DB role)
- 4. Write a full production pg_hba.conf: app + standby + admin VPN
- 5. Create the md5/SCRAM mismatch error intentionally, then fix it


---

## 3. Hands-On Commands & psql Output

### The Problem — Real Attack Log
**Explanation:** Imagine you are a database administrator. It is Monday morning. You check the PostgreSQL logs and see thousands of failed login attempts from IP addresses in countries where your company has no employees. Some attempts are trying common usernames like admin, root, and postgres. A few attempts even succeeded — because the default pg_hba.conf on some installations allows local connections without any password at all. This is not a hypothetical scenario. This happens to real databases every day. The fix starts with understanding authentication.

```sql
2026-11-04 03:14:22 UTC [12845] LOG:  connection received: host=185.220.101.34 port=54321
2026-11-04 03:14:22 UTC [12845] FATAL: password authentication failed for user "admin"
2026-11-04 03:14:23 UTC [12846] LOG:  connection received: host=185.220.101.34 port=54322
2026-11-04 03:14:23 UTC [12846] FATAL: password authentication failed for user "root"
2026-11-04 03:14:24 UTC [12847] LOG:  connection received: host=185.220.101.34 port=54323
2026-11-04 03:14:24 UTC [12847] FATAL: password authentication failed for user "postgres"
...
2026-11-04 03:14:25 UTC [12848] LOG:  connection received: host=192.168.1.50 port=54324
2026-11-04 03:14:25 UTC [12848] LOG:  connection authorized: user=postgres database=production
-- LOCAL connection with 'trust' auth — NO password needed!
```

### Setting Up SCRAM-SHA-256
**Explanation:** Let us set up scram-sha-256 authentication. First, check the password_encryption setting. In PostgreSQL 16, the default is already scram-sha-256. Then set a password for a role — PostgreSQL stores it using the configured encryption. Let us verify the stored hash format.

```sql
postgres=# SHOW password_encryption;
 password_encryption
---------------------
 scram-sha-256
(1 row)
postgres=# 
postgres=# -- Create a user with password (stored as SCRAM hash)
postgres=# CREATE ROLE app_user WITH LOGIN PASSWORD 'Str0ng_P@ss!';
CREATE ROLE
postgres=# 
postgres=# -- Verify stored hash format (starts with SCRAM-SHA-256)
postgres=# SELECT rolname, LEFT(rolpassword, 30) AS hash_prefix
postgres-# FROM pg_authid WHERE rolname = 'app_user';
 rolname  |          hash_prefix
----------+-------------------------------
 app_user | SCRAM-SHA-256$4096:randomSalt
(1 row)
```

### Peer Authentication — OS User = DB Role
**Explanation:** Peer authentication works only for local Unix socket connections. It asks the operating system what OS username is connecting, and if that OS username matches the PostgreSQL role name, the connection is allowed — no password needed. This is how you connect as postgres user on Linux: you switch to the postgres OS user, and peer authentication matches the OS user to the postgres database role. You can also define user name maps in pg_ident.conf to map different OS usernames to database roles.

```sql
# pg_hba.conf rule:
# TYPE  DATABASE  USER      METHOD
local   all       postgres  peer

# On Linux: switch to postgres OS user
$ sudo -u postgres psql
psql (16.4)
Type "help" for help.

postgres=# SELECT current_user, session_user;
 current_user | session_user
--------------+--------------
 postgres     | postgres
(1 row)

-- OS user 'postgres' matched DB role 'postgres'
-- No password was needed!
```

### Rule Ordering — First Match Wins
**Explanation:** Now the critical concept — rule ordering in pg_hba.conf. PostgreSQL reads from top to bottom and uses the FIRST matching rule. It does NOT continue scanning after a match. This means order matters enormously. A common mistake is putting a broad rule like host all all 0.0.0.0/0 trust near the top. This matches everything and all subsequent rules are ignored. The correct pattern is: specific restrictive rules first, then broader rules later. Block rules before allow rules. Reject rules before trust rules.

```sql
# pg_hba.conf — WRONG ORDER (dangerous!)
host  all  all  0.0.0.0/0  trust      ← matches EVERYTHING first!
host  all  all  0.0.0.0/0  scram-sha-256  ← NEVER reached

# pg_hba.conf — CORRECT ORDER
# 1. Reject known bad actors first
host  all  all  185.220.101.0/24  reject
# 2. Local superuser via peer (no password, same machine)
local all  postgres              peer
# 3. App connections from app subnet with SCRAM
host  mydb app_user 10.0.1.0/24  scram-sha-256
# 4. Admin connections from admin subnet with cert
hostssl all admin_user 10.0.2.0/24 cert
# 5. Reject everything else
host  all  all  0.0.0.0/0         reject
```

### Reload and Test Authentication Rules
**Explanation:** After editing pg_hba.conf, you must reload the configuration for changes to take effect. You do not need a full restart — a reload is enough. Let us reload and then test our rules by connecting as different users from different locations.

```sql
postgres=# SELECT pg_reload_conf();
 pg_reload_conf
----------------
 t
(1 row)

-- Or from shell:
$ sudo systemctl reload postgresql-16

-- Test: local peer connection (should work)
$ sudo -u postgres psql -c 'SELECT current_user;'
 current_user
--------------
 postgres

-- Test: remote connection without SSL (should be rejected)
$ psql -h 10.0.0.10 -U app_user -d app_db
psql: error: connection to server at "10.0.0.10", port 5432 failed:
FATAL:  no pg_hba.conf entry for host "10.0.0.10", user "app_user",
database "app_db", no encryption
```

### pg_ident.conf — Username Mapping
**Explanation:** pg_ident.conf lets you map operating system usernames to PostgreSQL role names. This is used with peer, ident, cert, and GSSAPI authentication. For example, the OS user john_smith can be mapped to the database role app_admin. You define a map name, reference it in pg_hba.conf, and PostgreSQL uses it to translate identities.

```sql
# pg_ident.conf
# MAPNAME       SYSTEM-USERNAME   PG-USERNAME
admin_map       john_smith        admin_user
admin_map       jane_doe          admin_user
app_map         deploy_bot        app_user
app_map         webapp            app_user

# pg_hba.conf — reference the map
# TYPE  DATABASE  USER        ADDRESS  METHOD       OPTIONS
local   all       admin_user           peer         map=admin_map
local   app_db    app_user             peer         map=app_map

-- Now john_smith and jane_doe can connect as admin_user
-- deploy_bot and webapp can connect as app_user
-- No passwords needed — OS identity is trusted
```

### Beginner Traps — Real Error Messages
**Explanation:** Beginner trap number one. You edit pg_hba.conf but nothing changes. You forgot to reload. PostgreSQL reads pg_hba.conf only at startup and when you explicitly reload. The fix is SELECT pg_reload_conf or systemctl reload. Trap number two — you get the error no pg_hba.conf entry for host. This means no rule matched your connection. Check: are you connecting from the right IP? Is the database name correct? Is the username correct? Is the rule in the right position? Trap number three — you set method to md5 but the role was created with scram-sha-256 password. The client cannot authenticate because the hash formats are incompatible. Solution: use scram-sha-256 method, or recreate the password after setting password_encryption to md5.

```sql
-- Trap 1: Edited pg_hba.conf but forgot to reload
-- Nothing changes until you run:
postgres=# SELECT pg_reload_conf();

-- Trap 2: No matching rule
FATAL: no pg_hba.conf entry for host "192.168.1.100",
  user "app_user", database "mydb", no encryption
-- Fix: Add a rule or check IP/user/database spelling

-- Trap 3: Hash mismatch (md5 method + SCRAM password)
FATAL: password authentication failed for user "app_user"
DETAIL: User "app_user" has an expired password.
-- Fix: Use scram-sha-256 method in pg_hba.conf
--   OR: ALTER ROLE app_user PASSWORD 'pass'; with md5 encryption
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `pg_hba.conf` — LDAP Authentication — pg_hba.conf
LDAP authentication connects PostgreSQL to your company's directory service — Active Directory, OpenLDAP, or any LDAP-compatible server. When a user connects, PostgreSQL does not check its own password store. Instead, it contacts the LDAP server and tries to bind (authenticate) with the provided username and password. There are two modes: simple bind where PostgreSQL constructs the DN from a prefix, the username, and a suffix, and search-plus-bind where PostgreSQL first searches the LDAP directory for the user, then binds with the found DN.

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `host all all 10.0.0.0/8 ldap` | `` | `[SETTING]` |  |
| `  ldapserver` | `ldap.company.com` | `[SETTING]` | LDAP server hostname |
| `  ldapport` | `389` | `[SETTING]` | Default LDAP port (636 for LDAPS) |
| `  ldapprefix` | `uid=` | `[SETTING]` | Prepended to username |
| `  ldapsuffix` | `,ou=people,dc=company,dc=com` | `[SETTING]` | Appended to username |
| `host all all 10.0.0.0/8 ldap` | `` | `[SETTING]` |  |
| `  ldapserver` | `ldap.company.com` | `[SETTING]` |  |
| `  ldapbasedn` | `ou=people,dc=company,dc=com` | `[SETTING]` | Search base |
| `  ldapbinddn` | `cn=pgbind,ou=service,dc=company,dc=com` | `[SETTING]` | Service account |
| `  ldapbindpasswd` | `service_password` | `[SETTING]` | Service account password |
| `  ldapsearchattribute` | `uid` | `[SETTING]` | Attribute to match username |


### File: `pg_hba.conf` — Production pg_hba.conf — Built From Scratch
Let us build a complete production pg_hba.conf from scratch. We start with the most restrictive rules and work down to a catch-all reject. Line one — local superuser access via peer for the DBA on the server itself. Line two — replication connections from standby servers using SCRAM over SSL. Line three — application connections from the app server subnet. Line four — monitoring connections from the monitoring subnet. Line five — admin access from the office VPN with client certificates. Line six — reject everything else.

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `local   all             postgres                         peer` | `` | `[SETTING]` |  |
| `local   all             all                              scram-sha-256` | `` | `[SETTING]` |  |
| `hostssl replication      repl_user       10.0.0.11/32     scram-sha-256` | `` | `[SETTING]` |  |
| `hostssl replication      repl_user       10.0.0.12/32     scram-sha-256` | `` | `[SETTING]` |  |
| `hostssl app_db          app_user        10.0.1.0/24      scram-sha-256` | `` | `[SETTING]` |  |
| `hostssl all             monitoring      10.0.3.0/24      scram-sha-256` | `` | `[SETTING]` |  |
| `hostssl all             admin_user      10.0.2.0/24      cert` | `` | `[SETTING]` |  |
| `host    all             all             0.0.0.0/0        reject` | `` | `[SETTING]` |  |
| `host    all             all             ::0/0            reject` | `` | `[SETTING]` |  |



---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps — Real Error Messages
Beginner trap number one. You edit pg_hba.conf but nothing changes. You forgot to reload. PostgreSQL reads pg_hba.conf only at startup and when you explicitly reload. The fix is SELECT pg_reload_conf or systemctl reload. Trap number two — you get the error no pg_hba.conf entry for host. This means no rule matched your connection. Check: are you connecting from the right IP? Is the database name correct? Is the username correct? Is the rule in the right position? Trap number three — you set method to md5 but the role was created with scram-sha-256 password. The client cannot authenticate because the hash formats are incompatible. Solution: use scram-sha-256 method, or recreate the password after setting password_encryption to md5.

```sql
-- Trap 1: Edited pg_hba.conf but forgot to reload
-- Nothing changes until you run:
SELECT pg_reload_conf();

-- Trap 2: No matching rule
FATAL: no pg_hba.conf entry for host "192.168.1.100",
  user "app_user", database "mydb", no encryption
-- Fix: Add a rule or check IP/user/database spelling

-- Trap 3: Hash mismatch (md5 method + SCRAM password)
FATAL: password authentication failed for user "app_user"
DETAIL: User "app_user" has an expired password.
-- Fix: Use scram-sha-256 method in pg_hba.conf
--   OR: ALTER ROLE app_user PASSWORD 'pass'; with md5 encryption
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us wrap up with the key points. Authentication is the first line of defense. pg_hba.conf is read top to bottom — first match wins, no fallback. Use scram-sha-256 for all password authentication. Use peer for local DBA access. Use cert for high-security network access. Use LDAP or GSSAPI for enterprise environments. Never use trust or password in production. Always reload after editing pg_hba.conf. And remember — the most secure database is one where you explicitly define who gets in and reject everything else.

- **pg_hba.conf: top-to-bottom, first match wins, no fallback**
- **scram-sha-256: standard for all password authentication**
- **peer: local DBA access via Unix socket (OS user = DB role)**
- **cert: strongest network auth (no passwords at all)**
- **ldap/gss: enterprise SSO (Active Directory integration)**
- **NEVER use trust or password in production**
- **Always reload after editing: SELECT pg_reload_conf()**
- **Pattern: specific rules first → catch-all reject last**


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
