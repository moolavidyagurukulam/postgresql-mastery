# PostgreSQL Terminology
**Series:** PostgreSQL Mastery | **Phase:** Phase 1: Foundation | **Classes:** Class 05
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In our previous class, we learned about PostgreSQL distributions. Before we install PostgreSQL, we need to learn the terminology ... the words and concepts that PostgreSQL uses. If you skip this class, you will be confused when we start the hands-on work. Every term explained here will come up again and again throughout this course. ... Let us build your vocabulary!

### The Problem: Confusing Terminology
Here is a common beginner problem. You read a PostgreSQL tutorial and it says ... create a table in the public schema of your database cluster. ... And you think ... what? What is a cluster? What is a schema? I thought a cluster means multiple servers! ... PostgreSQL uses some words differently from how you might expect. A cluster does not mean multiple servers. A schema does not mean a diagram. If you do not learn these terms now, every future class will be confusing. ... So let us clear this up once and for all.

- Tutorial says: 'Create a table in the public schema of your cluster'
- Beginner thinks: Cluster = multiple servers? Schema = diagram?
- PostgreSQL uses words DIFFERENTLY than you expect!
- Cluster ≠ multiple servers (in PG context)
- Schema ≠ a diagram
- Learn these terms NOW — or every future class is confusing


---

## 2. Core Technical Concepts & Mechanisms

### The Problem: Confusing Terminology
Here is a common beginner problem. You read a PostgreSQL tutorial and it says ... create a table in the public schema of your database cluster. ... And you think ... what? What is a cluster? What is a schema? I thought a cluster means multiple servers! ... PostgreSQL uses some words differently from how you might expect. A cluster does not mean multiple servers. A schema does not mean a diagram. If you do not learn these terms now, every future class will be confusing. ... So let us clear this up once and for all.

- Tutorial says: 'Create a table in the public schema of your cluster'
- Beginner thinks: Cluster = multiple servers? Schema = diagram?
- PostgreSQL uses words DIFFERENTLY than you expect!
- Cluster ≠ multiple servers (in PG context)
- Schema ≠ a diagram
- Learn these terms NOW — or every future class is confusing

### Cluster (Instance)
Let us start with the most important term ... cluster. ... In general IT, a cluster usually means a group of servers working together. But in PostgreSQL, a cluster means something completely different. ... A PostgreSQL cluster is a single running instance of the PostgreSQL server. It is ONE server process managing ONE data directory. Inside that data directory, you can have multiple databases. ... Think of it like a building. The cluster is the entire building. Inside the building, there are multiple rooms. Each room is a database. All rooms share the same building infrastructure ... same walls, same electricity, same security guard. Similarly, all databases in a cluster share the same server process, same port, same configuration files, and same set of users. ... When you install PostgreSQL, you automatically get one cluster. Most people only ever need one cluster on a machine.

> **Definition:** A single running PostgreSQL server process managing one data directory with multiple databases.

| Term | Meaning / Explanation |
| :--- | :--- |
| **NOT** | Multiple servers! In PG, cluster = single instance |
| **Contains** | Multiple databases inside one data directory |
| **Shares** | Same port, config files, users across all DBs |
| **Analogy** | Building = cluster, Rooms = databases |

**Notes:**
- Installing PostgreSQL gives you one cluster automatically

### Database
Next ... database. ... A database in PostgreSQL is a logical container for your data. Each database is completely isolated from other databases in the same cluster. ... When you connect to PostgreSQL, you always connect to a specific database. You cannot query tables in another database directly. ... Think of each database as a separate room in our building. Each room has its own furniture, its own documents, its own purpose. People in Room A cannot see what is in Room B. ... When PostgreSQL is installed, it creates three default databases. postgres ... which is the default administration database. template0 ... a clean, unmodified template. template1 ... a template used when you create new databases. ... You will create your own databases for your applications. For our course, we will create a practice database for all hands-on work.

> **Definition:** A logical container inside a cluster. Isolated — you connect to one database at a time.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Contains** | Schemas, tables, views, functions — all your objects |
| **Isolated** | Cannot directly query tables in another database |
| **Default DBs** | postgres (admin), template0 (clean), template1 (template) |
| **Analogy** | Room in the building — each room is separate |

**Notes:**
- We will create a 'practice' database for all our hands-on work

### Schema
Now ... schema. This confuses many beginners. ... In the general database world, schema can mean the structure of your tables ... like a blueprint. But in PostgreSQL, a schema is a namespace inside a database. ... Think of it like this. A database is a room. A schema is a section of that room ... like a filing cabinet. You can have multiple filing cabinets in one room. Each cabinet organizes a different set of documents. ... Every database has a default schema called public. When you create a table without specifying a schema, it goes into the public schema. ... Schemas are useful for organizing. You might have a sales schema for sales tables, an hr schema for HR tables, and a reports schema for reporting views. They help keep things tidy, especially in large applications.

> **Definition:** A namespace inside a database that organizes tables, views, and other objects.

| Term | Meaning / Explanation |
| :--- | :--- |
| **NOT** | A blueprint or diagram! In PG, schema = namespace |
| **Default** | Every database has a 'public' schema automatically |
| **Purpose** | Organize objects: sales.orders, hr.employees |
| **Analogy** | Filing cabinet inside a room (database) |

**Notes:**
- search_path controls which schemas PG looks in when you query

### PostgreSQL Hierarchy: Cluster → Database → Schema → Table
Let me show you the complete hierarchy. ... At the top is the Cluster ... the entire PostgreSQL server. Inside the cluster, you have multiple Databases. Inside each database, you have multiple Schemas. Inside each schema, you have Tables, Views, Functions, and other objects. ... This is the most important diagram in this entire course. Understand this hierarchy and everything else falls into place. ... Cluster contains Databases. Database contains Schemas. Schema contains Tables.

```
[CLUSTER (Instance)]
[postgres]
[practice]
[myapp]
[public]
[sales]
[users]
[products]
[orders]
[invoices]
```

### Table, Row, Column — The Core Terms
Now the terms you will use most often ... table, row, and column. ... A table is a structured collection of data organized in rows and columns. It is like one sheet in a spreadsheet. ... A row is one complete record. For example, one row in a customers table represents one customer with all their details. In PostgreSQL, a row is also called a tuple. ... A column is one piece of information. For example, the name column stores every customer's name. In PostgreSQL, a column is also called an attribute. ... You might hear these synonyms in documentation. Table is also called a relation. Row is also called a tuple or record. Column is also called an attribute or field. These terms come from relational algebra, the mathematical foundation of relational databases.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Table** | Structured rows & columns (math term: Relation) |
| **Row** | One complete record, e.g. one customer (math term: Tuple) |
| **Column** | One data attribute like name or price (math term: Attribute) |

### Other Database Objects
Inside a schema, you can have more than just tables. Let me introduce the other important objects. ... An index is a structure that makes searching faster. Like the index at the back of a book ... instead of reading every page, you jump directly to the right one. ... A view is a saved query. You write a complex query once, save it as a view, and then query the view like a table. The data is not duplicated ... it runs the query every time you use the view. ... A function is reusable code that runs inside the database. You can write functions in SQL or PL/pgSQL ... PostgreSQL's procedural language. ... A trigger is code that runs automatically when something happens to a table ... like after an INSERT or before a DELETE. Useful for audit logs and business rules. ... A sequence is a number generator that produces unique values. It is used behind SERIAL and IDENTITY columns to auto-generate IDs.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Index** | Fast lookup structure (like the index at the back of a book) |
| **View** | Saved SQL query queried like a table without duplicating data |
| **Function** | Reusable SQL or PL/pgSQL code executed inside the DB |
| **Trigger** | Runs automatically on INSERT/UPDATE/DELETE for audits & rules |
| **Sequence** | Auto-number generator backing SERIAL and IDENTITY columns |

### Connection & Security Terms
A few more terms about connecting to PostgreSQL. ... A role is a user or group in PostgreSQL. PostgreSQL does not have separate concepts for users and groups ... it uses roles for both. A role with the LOGIN privilege is essentially a user. A role without LOGIN is a group. ... A session is one connection to the database. When you open psql or your application connects, that is one session. ... A transaction is a set of operations that must all succeed or all fail together. We will learn much more about transactions later. ... The port is the network address where PostgreSQL listens. The default is 5432. ... The superuser is the admin role with all privileges. By default, it is called postgres.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Role** | Users & groups combined (LOGIN = user; no LOGIN = group) |
| **Session** | One active client connection from psql or your application |
| **Transaction** | All-or-nothing unit of work protecting consistency |
| **Port & Admin** | Default TCP port is 5432; default superuser role is postgres |

### Important Files & Directories
Finally, some file and directory terms you will encounter. ... The data directory is where PostgreSQL stores all its data. On Debian and Ubuntu, it is at var lib postgresql 16 main. On Red Hat, it is at var lib pgsql 16 data. This is the most important directory ... if you lose it and have no backup, you lose all your data. ... postgresql.conf is the main configuration file. It controls memory, connections, logging, and hundreds of other settings. ... pg_hba.conf is the authentication configuration file. It controls who can connect and how they authenticate. ... pg_wal is the directory that stores Write Ahead Log files. These are critical for crash recovery and replication. ... We will work with all of these files in detail throughout this course.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Data Directory** | Stores all cluster files (/var/lib/postgresql/16/main on Debian) |
| **postgresql.conf** | Main config file for memory, connections, logging & WAL |
| **pg_hba.conf** | Client access rules: who can connect and how they log in |
| **pg_wal/** | Write-Ahead Log files powering crash recovery & replication |


---

## 3. Hands-On Commands & psql Output

### Seeing Cluster, Database & Schema Live in psql
**Explanation:** Let us see how Cluster, Database, and Schema actually look inside PostgreSQL when you connect! ... When you type backslash l, PostgreSQL lists every isolated database inside the single running cluster — here postgres and practice. ... Next, you switch into the practice database using backslash c practice, and type backslash d n to list all schemas inside it — showing the default public schema owned by pg_database_owner in PostgreSQL 16. ... Finally, running SELECT current_database, current_schema, and inet_server_port confirms practice, public, and port 5432. One cluster port serving isolated databases, each containing organized schemas!

```sql
-- 1. View all Databases inside this PostgreSQL Cluster
postgres=# \l
   Name    |  Owner   | Encoding | Locale Provider
-----------+----------+----------+-----------------
 postgres  | postgres | UTF8     | libc
 practice  | postgres | UTF8     | libc

-- 2. Connect into one Database, then list its Schemas
postgres=# \c practice
You are now connected to database "practice" as user "postgres".
practice=# \dn
  Name  |       Owner
--------+-------------------
 public | pg_database_owner

-- 3. Confirm current database, schema & cluster port
practice=# SELECT current_database(), current_schema(), inet_server_port();
 practice | public | 5432
```


---

## 5. Common Beginner Traps & How to Fix Them

### Common Terminology Mistakes
Common terminology mistakes. ... Mistake 1 ... Thinking a PostgreSQL cluster means multiple servers. In PostgreSQL, cluster means one running instance. If you want multiple servers, that is called replication. ... Mistake 2 ... Confusing schema with table structure. In PostgreSQL, schema is a namespace, not a blueprint. When someone says the schema of a table, they usually mean the table structure. When they say a PostgreSQL schema, they mean the namespace. ... Mistake 3 ... Thinking databases in the same cluster can see each other's tables. They cannot. Databases are isolated. To access another database, you need to use Foreign Data Wrappers or dblink. ... Mistake 4 ... Confusing roles with users. In PostgreSQL, they are the same thing. A role with LOGIN is a user. A role without LOGIN is a group.

- Mistake 1: 'Cluster means multiple servers'
-    → In PG, cluster = one running instance
- Mistake 2: 'Schema = table structure'
-    → In PG, schema = namespace (like a folder)
- Mistake 3: 'Databases can see each other's tables'
-    → NO! Databases are isolated. Use FDW/dblink to cross.
- Mistake 4: 'Roles and users are different things'
-    → Same thing! Role + LOGIN = user. Role without LOGIN = group.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

Practice time! ... Exercise 1 ... Draw the PostgreSQL hierarchy from memory. Cluster at the top, then databases, then schemas, then tables. ... Exercise 2 ... What are the three default databases created when PostgreSQL is installed? What is each one used for? ... Exercise 3 ... What is the difference between a row and a column? Give an example using a students table. ... Exercise 4 ... Name five objects you can create inside a schema, besides tables. ... Exercise 5 ... A friend says they want to create a cluster of PostgreSQL servers for high availability. Explain why the word cluster has a different meaning in PostgreSQL.

1. Exercise 1: Draw the PG hierarchy from memory (cluster → DB → schema → table)
2. Exercise 2: What are the 3 default databases? What is each used for?
3. Exercise 3: Row vs Column — give an example using a students table
4. Exercise 4: Name 5 objects you can create inside a schema (besides tables)
5. Exercise 5: Friend says 'cluster of PG servers for HA' — explain the PG meaning


---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. ... A cluster is a single running PostgreSQL instance ... not multiple servers. ... A database is a logical container inside a cluster ... isolated from other databases. ... A schema is a namespace inside a database ... like a folder for organizing objects. ... Tables store data in rows and columns. ... Other objects include indexes, views, functions, triggers, and sequences. ... Roles handle both users and groups. ... Key files are postgresql.conf, pg_hba.conf, and the data directory. ... In our next class, we will install PostgreSQL 16 on your machine and get it running!

- **Cluster = one running PG instance (NOT multiple servers)**
- **Database = logical container, isolated from other DBs**
- **Schema = namespace inside a database (NOT a diagram)**
- **Table = rows (records) + columns (fields)**
- **Objects: indexes, views, functions, triggers, sequences**
- **Role = user OR group (PG uses one concept for both)**
- **Key files: postgresql.conf, pg_hba.conf, data directory**


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
