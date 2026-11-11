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

-- =============================================
-- Next Class: PostgreSQL Terminology
-- =============================================
