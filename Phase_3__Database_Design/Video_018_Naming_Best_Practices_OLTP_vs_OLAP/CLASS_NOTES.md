# Naming Conventions, Best Practices & OLTP vs OLAP
**Series:** PostgreSQL Mastery | **Phase:** General | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Your tables are normalized. Your data types are chosen. But if your names are a mess and your design has anti-patterns, nobody can maintain it — including future you. Today we cover naming conventions, common design mistakes, and the fundamental split between OLTP and OLAP systems.

### The Problem: Inconsistent Names = Confusion
Here's the problem. Without naming rules, every developer picks their own style. One uses PascalCase for tables. Another uses snake case. A third uses all caps. The same concept gets three different column names. Six months later, nobody knows what anything is called. Let's fix this with rules.


---

## 2. Core Technical Concepts & Mechanisms

### The Problem: Inconsistent Names = Confusion
Here's the problem. Without naming rules, every developer picks their own style. One uses PascalCase for tables. Another uses snake case. A third uses all caps. The same concept gets three different column names. Six months later, nobody knows what anything is called. Let's fix this with rules.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Table 1** | UserAccounts (PascalCase) |
| **Table 2** | order_details (snake_case) |
| **Table 3** | PRODUCT_INVENTORY (SCREAMING_CASE) |
| **Column** | userFirstName, user_first_name, firstName — all in the same database! |

**Notes:**
- Without rules, every developer picks their own style
- Six months later, nobody knows what anything is called

### Rule 1: Use snake_case for Everything
Rule number one in PostgreSQL naming: always use lowercase snake_case with underscores—like order_items and created_at. ... Why does this matter so much in PostgreSQL? Because PostgreSQL automatically folds every unquoted name to lowercase! If you write UserAccounts without quotes, PostgreSQL quietly stores useraccounts as one unreadable word. And if you wrap it in double quotes to preserve capitals, every developer must type quotes in every query forever!

| Term | Meaning / Explanation |
| :--- | :--- |
| **Standard** | Use all lowercase_with_underscores for tables, columns & indexes |
| **PG Folding** | Unquoted UserAccounts becomes useraccounts inside PostgreSQL |
| **Quote Trap** | Using "UserAccounts" forces double quotes on every query forever |
| **Benefit** | snake_case stays 100% predictable across SQL tools & ORMs |

### Naming Convention Rules
Here are the full naming conventions. Tables are plural snake case — users, order items, products. Columns are singular — first name, email, created at. Primary keys are just id or table underscore id. Foreign keys reference the other table — customer id, product id. Indexes start with idx, constraints with their type — pk for primary key, uq for unique, ck for check.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Tables** | Plural lowercase snake_case: users, order_items, products |
| **Columns** | Singular lowercase snake_case: first_name, email, created_at |
| **Primary Key** | Just id (or table_id): id INT GENERATED ALWAYS AS IDENTITY |
| **Foreign Key** | Singular referenced table + _id: customer_id, product_id |
| **Constraints** | Prefix clearly: idx_, pk_, fk_, uq_, ck_ for instant debugging |

### Good vs Bad Naming
Good versus bad naming. Bad names include meaningless prefixes like tbl underscore usr, vague names like data or info, single letters, overly long names, and cryptic abbreviations. Also avoid reserved words like type, order, or user as bare column names. Good names are clear, specific nouns with full words. They describe exactly what the table or column contains.

| Bad Names (Avoid) | Good Names (Use These) |
| :--- | :--- |
| tbl_usr → meaningless prefix | users → clear, simple |
| data, info, temp → too vague | accounts, sessions → specific nouns |
| x, n, val → single letters | first_name → descriptive |
| user_data_info_table → too long | order_items → shows relationship |
| acct_dtl → cryptic abbreviation | account_details → full words |
| type, order, user → reserved words | user_type, order_status → prefixed |

### Design Anti-Patterns (Things to Avoid)
Now let's talk about design anti-patterns — things to avoid. The EAV pattern stores everything as key-value pairs and is a nightmare to query. The one big table pattern crams everything into one table with fifty columns, most of them null. Stringly typed means using text for everything — dates, numbers, booleans all as strings. And polymorphic foreign keys point to different tables from one column, breaking referential integrity. If you see these patterns, refactor before they grow.

| Term | Meaning / Explanation |
| :--- | :--- |
| **EAV Pattern** | Entity-Attribute-Value — stores everything as key-value pairs, impossible to query efficiently |
| **One Big Table** | Everything in one table with 50+ columns, most NULL — violates normalization |
| **Stringly Typed** | Using VARCHAR for everything — dates as text, numbers as text, booleans as 'Y'/'N' |
| **Polymorphic FK** | One foreign key column pointing to different tables — no referential integrity |

**Notes:**
- If you see these patterns, refactor before they grow

### OLTP — Online Transaction Processing
OLTP — Online Transaction Processing. This is your everyday application database. It processes many small, fast transactions — inserts, updates, deletes. Think e-commerce checkouts, banking transfers, ticket bookings. The design is highly normalized with foreign keys everywhere. Queries are simple — insert one order, update one balance. The priority is write speed, data integrity, and ACID compliance.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Purpose** | Process many small, fast transactions (inserts, updates, deletes) |
| **Examples** | E-commerce checkout, banking transfers, ticket booking, user signups |
| **Design** | Highly normalized (3NF+), many tables, foreign keys everywhere |
| **Queries** | Simple — affect 1 or few rows: INSERT one order, UPDATE one balance |
| **Priority** | Write speed, data integrity, ACID compliance |

### OLAP — Online Analytical Processing
OLAP — Online Analytical Processing. This is your data warehouse. It analyzes large volumes of historical data for patterns and insights. Think sales reports, revenue trends, user behavior dashboards. The design is denormalized — often a star schema with fact tables and dimension tables. Queries are complex — summing, averaging, grouping across millions of rows. The priority is read speed and aggregation efficiency.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Purpose** | Analyze large volumes of historical data for patterns and insights |
| **Examples** | Sales reports, revenue trends, user behavior dashboards, BI tools |
| **Design** | Denormalized star schema — fact table + dimension tables |
| **Queries** | Complex — scan millions of rows: SUM, AVG, GROUP BY across years |
| **Priority** | Read speed, query performance, aggregation efficiency |

### Star Schema (OLAP Design)
This is the star schema — the standard OLAP design. In the center is the fact table — fact sales — containing the measurements: quantity, revenue, and foreign keys to dimension tables. Around it are the dimension tables — customers, products, dates, and stores — each with descriptive attributes. It's called a star because the dimensions radiate out from the central fact table. This design is intentionally denormalized for fast analytical queries.

```
[fact_sales]
[dim_customers]
[dim_products]
[dim_date]
[dim_stores]
```

### OLTP vs OLAP — Side by Side
Let us compare OLTP and OLAP cleanly side by side so you know where and when each design wins. ... Think of OLTP like the cash register at a busy store—thousands of fast single-customer checkouts per second, strictly normalized in 3NF so money never gets lost. ... Think of OLAP like the annual corporate boardroom report—reading millions of historical sales rows with SUM and GROUP BY from a star schema. ... Most real companies run OLTP PostgreSQL for their live app, then sync nightly data into an OLAP warehouse for dashboards.

| Term | Meaning / Explanation |
| :--- | :--- |
| **OLTP Goal** | Run live business — thousands of tiny fast INSERT/UPDATE/DELETE ops |
| **OLAP Goal** | Analyze history — complex SUM, AVG, GROUP BY reports over years |
| **Schema Shape** | OLTP: normalized 3NF tables | OLAP: denormalized Star Schema |
| **Top Priority** | OLTP: ACID integrity & fast writes | OLAP: fast analytical reads |
| **Real Setup** | Run live app on OLTP; sync copies into OLAP for BI dashboards |


---

## 3. Hands-On Commands & psql Output

### PostgreSQL Lowercases Unquoted Identifiers
**Explanation:** Watch this. We create a table called UserAccounts with a capital U and capital A. PostgreSQL says CREATE TABLE. But when we look for it with the capital letters, it says 'not found'. That's because PostgreSQL lowercased it to useraccounts — one word, all lowercase. This is why snake case is the standard. user underscore accounts works exactly as expected.

```sql
essilor=#CREATE TABLE UserAccounts (id INT);
CREATE TABLE
essilor=#\dt UserAccounts
Did not find any relation named "UserAccounts".
essilor=#\dt useraccounts
             List of relations
 Schema |     Name     | Type  | Owner
--------+--------------+-------+-------
 public | useraccounts | table | postgres

-- PG stored it as 'useraccounts' (all lowercase!)
-- Use snake_case to avoid this confusion
```

### Anti-Pattern: EAV vs Proper Table
**Explanation:** Here's the EAV pattern in action. The user attributes table stores name, email, and age all as key-value rows with every value as text. Age thirty is stored as the string thirty. Want to find users older than twenty-five? You'd need to cast the string to an integer, hope nobody typed 'thirty' instead of thirty, and the query optimizer can't help you. The proper way is a table with typed columns. Name is varchar, email is varchar, age is integer. Clean, fast, type-safe.

```sql
-- BAD: Entity-Attribute-Value
CREATE TABLE user_attributes (
    user_id    INT,
    attr_name  VARCHAR(50),
    attr_value VARCHAR(255)
);
INSERT INTO user_attributes VALUES
(1, 'name', 'Ravi'),
(1, 'email', 'ravi@ex.com'),
(1, 'age', '30');  -- age stored as text!

-- GOOD: Proper columns
CREATE TABLE users (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(100),
    email VARCHAR(150),
    age   INT  -- correct type!
);
INSERT INTO users (name, email, age)
VALUES ('Ravi', 'ravi@ex.com', 30);
```

### Documenting Your Schema with COMMENT
**Explanation:** Document your schema with COMMENT. You can add a comment on the table itself explaining what it stores. And you can comment on individual columns — for example, listing the valid status values or clarifying what total means. When anyone runs backslash d plus on the table, they see the comments. This is self-documenting schema — much better than hoping someone reads a wiki.

```sql
CREATE TABLE orders (
    id          SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id),
    total       NUMERIC(10,2) NOT NULL,
    status      VARCHAR(20) DEFAULT 'pending',
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Document the table
COMMENT ON TABLE orders IS
  'Customer purchase orders';

-- Document columns
COMMENT ON COLUMN orders.status IS
  'pending, confirmed, shipped, delivered, cancelled';

COMMENT ON COLUMN orders.total IS
  'Order total after discounts, before tax';

-- View comments:
\d+ orders
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

Here are the best practices. Always define a primary key. Use appropriate data types — never store dates or numbers as text. Add NOT NULL to required columns. Use foreign keys to enforce relationships. Add CHECK constraints for business rules. Create indexes on columns you search or join on. Add unique constraints for natural keys like email. Include created at and updated at timestamps on every table. And document your schema with comments.

1. Always define a PRIMARY KEY (prefer SERIAL or IDENTITY for surrogate keys)
2. Use appropriate data types — never store dates or numbers as text
3. Add NOT NULL to columns that must have values
4. Use FOREIGN KEYS to enforce relationships between tables
5. Add CHECK constraints for business rules (price > 0, qty >= 1)
6. Create indexes on columns used in WHERE and JOIN clauses
7. Use UNIQUE constraints for natural keys (email, username)
8. Add created_at and updated_at TIMESTAMPTZ columns to every table
9. Document your schema — add COMMENT ON TABLE and COMMENT ON COLUMN


---


### Answer Key — Database Design Best Practices

```sql
-- 1. Production table with identity PK and timestamps
-- Note: Always use snake_case, plural table names, and TIMESTAMPTZ.
CREATE TABLE customers (id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, email TEXT NOT NULL UNIQUE, created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW());

-- 2. Foreign key reference with clean naming
-- Note: FK column named singular referenced_table_id.
CREATE TABLE orders (id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, customer_id BIGINT NOT NULL REFERENCES customers(id), order_total NUMERIC(10,2) NOT NULL, created_at TIMESTAMPTZ DEFAULT NOW());

-- 3. Document schema with comments
-- Note: Comments persist inside PostgreSQL catalogs for team visibility.
COMMENT ON TABLE customers IS 'Master record for registered store customers';
COMMENT ON COLUMN customers.email IS 'User primary login and verified email';

-- 4. OLAP Star Schema aggregate query
-- Note: Star schemas optimize read queries over millions of rows.
SELECT d.year, p.category, SUM(f.revenue) AS total_revenue
FROM fact_sales f
JOIN dim_date d ON f.date_key = d.date_key
JOIN dim_products p ON f.product_key = p.product_key
GROUP BY d.year, p.category ORDER BY total_revenue DESC;

-- 5. Fixing the EAV Anti-Pattern
-- Note: Typed columns outperform Entity-Attribute-Value anti-patterns.
CREATE TABLE user_settings (user_id BIGINT PRIMARY KEY REFERENCES users(id), theme TEXT DEFAULT 'dark', email_notifications BOOLEAN DEFAULT true, timezone TEXT DEFAULT 'UTC');

```

---

## 7. Key Takeaways & Cheat Sheet

Let's recap everything. Use snake case for all identifiers because PostgreSQL lowercases unquoted names. Tables are plural, columns are singular, foreign keys reference the other table. Avoid anti-patterns like EAV and one big table. Always define primary keys, NOT NULL, foreign keys, check constraints, and indexes. Add timestamps and schema comments. OLTP is normalized and write-optimized for running the business. OLAP is denormalized and read-optimized for analyzing the business.

- **Use snake_case for all identifiers — PostgreSQL lowercases unquoted names**
- **Tables: plural (users), columns: singular (first_name), FK: referenced_table_id**
- **Avoid anti-patterns: EAV, one big table, stringly typed, polymorphic FK**
- **Always: PRIMARY KEY, NOT NULL, FOREIGN KEY, CHECK constraints, indexes**
- **Add created_at/updated_at and COMMENT ON TABLE/COLUMN**
- **OLTP = normalized, write-optimized, runs the business**
- **OLAP = denormalized star schema, read-optimized, analyzes the business**


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
