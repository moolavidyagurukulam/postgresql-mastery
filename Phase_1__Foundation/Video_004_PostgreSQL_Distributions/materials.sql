-- =============================================
-- PostgreSQL Mastery: PostgreSQL Distributions
-- Phase 1: Foundation | Class 04
-- =============================================
-- Open Source vs EDB vs Cloud-Managed options.
-- No SQL commands — decision/comparison class.
-- =============================================

-- === KEY CONCEPTS ===

-- 1. Community PostgreSQL (postgresql.org)
--    - 100% free, ALL features included
--    - No paid version, no feature limits
--    - YOU manage: install, config, backup, upgrades, patches
--    - Support: community forums, mailing lists, docs
--    - Best for: skilled teams, full control, zero cost

-- 2. EDB (EnterpriseDB)
--    - Paid annual subscription per server
--    - Oracle compatibility (run PL/SQL without rewriting)
--    - Enterprise tools: PEM, EFM, Barman, pgd
--    - 24/7 enterprise support
--    - Best for: Oracle migrations, enterprises needing support

-- 3. Other Distributions
--    - Crunchy Data: Security, Kubernetes, government/defense
--    - Percona: Performance, bundled extensions, open source
--    - Both keep full compatibility with community PG

-- 4. Cloud-Managed
--    - AWS RDS / Aurora PostgreSQL
--    - Azure Database for PostgreSQL
--    - GCP Cloud SQL for PostgreSQL
--    - Supabase, Neon (newer options)
--    - Provider manages: install, patches, backups, failover
--    - You lose: full control, pay more, vendor lock-in

-- === DECISION FRAMEWORK ===

-- Have a DBA + want full control + zero cost?
--    → Community PostgreSQL
-- Migrating from Oracle + need 24/7 support?
--    → EDB or Crunchy Data
-- Small team + want to focus on app + no DBA?
--    → Cloud-managed (RDS, Aurora, Azure)
-- For LEARNING?
--    → Always Community PostgreSQL

-- === PRACTICE EXERCISES ===

-- Exercise 1:
-- Visit postgresql.org download page.
-- What versions and platforms are available?

-- Exercise 2:
-- Company with 10 PG servers, no Oracle legacy, 2 DBAs.
-- Should they use Community, EDB, or cloud-managed? Why?

-- Exercise 3:
-- Startup with 3 devs, no DBA, launching next month, 10K users.
-- Which option? Why?

-- Exercise 4:
-- Research the monthly cost of AWS RDS PostgreSQL:
-- 4 CPUs, 16 GB RAM, in your nearest region.
-- Compare with renting a similar Linux VM.

-- Exercise 5:
-- What does "vendor lock-in" mean?
-- How could it hurt a company using cloud-managed PostgreSQL?

-- === ANSWER KEY ===

-- Answer 1:
-- postgresql.org/download lists Linux (Ubuntu/Debian/RHEL), Windows, macOS,
-- BSD, and source code across PostgreSQL 16 (course baseline) and newer releases.

-- Answer 2:
-- Community PostgreSQL ? with 2 skilled DBAs and no Oracle legacy, you get
-- 100% full features for zero license cost and complete control.

-- Answer 3:
-- Cloud-managed (AWS RDS / Azure / Cloud SQL) ? with 3 devs and no DBA,
-- managed backups, patching, and high availability let them launch fast.

-- Answer 4:
-- A 4 vCPU / 16 GB managed RDS instance typically costs ~2?3x a raw Linux VM
-- of similar specs because managed backups, HA, and patching are bundled in.

-- Answer 5:
-- Vendor lock-in means relying on proprietary cloud features (like Aurora-only
-- APIs) that make migrating away later expensive and time-consuming.

-- =============================================
-- Next Class: PostgreSQL Terminology
-- =============================================
