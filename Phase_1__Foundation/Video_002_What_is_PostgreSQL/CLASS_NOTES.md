# What is PostgreSQL? History & Why It Was Created
**Series:** PostgreSQL Mastery | **Phase:** Phase 1: Foundation | **Classes:** Class 02
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In our previous class, we learned what a database is and why we need one. Today, we answer the next big question ... What is PostgreSQL? Where did it come from? And why should you learn it over any other database? ... Let us find out!

### The Problem: Which Database Should You Choose?
Imagine you are starting a new project. Maybe an e-commerce website, or a hospital management system, or a banking application. You know you need a database. But there are so many options! ... MySQL, Oracle, SQL Server, MongoDB, PostgreSQL ... which one do you choose? ... Some cost lakhs of rupees per year in licensing fees. Some are free but have limitations. Some are fast but lack features. Some have features but are hard to learn. ... This is a real problem that developers and companies face every day. Today, we will learn about PostgreSQL, and by the end, you will understand why many of the world's best companies chose it.

- You're starting a new project — you need a database
- So many options: MySQL, Oracle, SQL Server, MongoDB ...
- Some cost LAKHS in licensing fees
- Some are free but have limitations
- Some are fast but lack features
- Which one do you choose? And WHY?


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites
Before we start, you should know what a database is and why we need one. We covered that in the previous class on What is a Database. If you have not watched it yet, go back and watch it first. ... Now, let us continue.

- You should know: What is a database and why we need it
- Covered in: What is a Database? class
- If you haven't watched it, go back and watch it first

### The Problem: Which Database Should You Choose?
Imagine you are starting a new project. Maybe an e-commerce website, or a hospital management system, or a banking application. You know you need a database. But there are so many options! ... MySQL, Oracle, SQL Server, MongoDB, PostgreSQL ... which one do you choose? ... Some cost lakhs of rupees per year in licensing fees. Some are free but have limitations. Some are fast but lack features. Some have features but are hard to learn. ... This is a real problem that developers and companies face every day. Today, we will learn about PostgreSQL, and by the end, you will understand why many of the world's best companies chose it.

- You're starting a new project — you need a database
- So many options: MySQL, Oracle, SQL Server, MongoDB ...
- Some cost LAKHS in licensing fees
- Some are free but have limitations
- Some are fast but lack features
- Which one do you choose? And WHY?

### What is PostgreSQL?
So what IS PostgreSQL? ... PostgreSQL is a free, open-source, relational database management system. Let us break that down. ... Free means you do not pay anything to download, install, or use it. Even for commercial projects. ... Open source means anyone can see, modify, and contribute to its code. Thousands of developers around the world improve it every day. ... Relational means it stores data in tables with rows and columns, and tables can be linked together through relationships. ... Database management system, or D B M S, means it is the software that manages your data ... storing it, protecting it, and giving it back when you ask. ... People often pronounce it as post gres or post gres Q L. Both are correct. It is NOT post gray S Q L. The official pronunciation is post gres Q L.

> **Definition:** A free, open-source, relational database management system.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Free** | No cost to download, install, or use — even commercially |
| **Open Source** | Anyone can see, modify, and contribute to the code |
| **Relational** | Data in tables (rows/columns) linked by relationships |
| **DBMS** | Software that stores, protects, and serves your data |

**Notes:**
- Pronounced: post-GRES-Q-L or post-GRES (NOT post-gray-SQL)

### The History of PostgreSQL
PostgreSQL has a fascinating history. It started in 1986 at the University of California, Berkeley. A professor named Michael Stonebraker started a project called POSTGRES ... which stood for Post Ingres, because it was meant to be the successor to an earlier database called Ingres. ... The goal was to create a database that could handle complex data types and relationships ... things that other databases at the time could not do. ... In 1996, the project was renamed to PostgreSQL because it added support for the SQL language. The community took over development, and it became a fully open-source project. ... Since then, PostgreSQL has released a new major version every year. We are now on PostgreSQL 16, which we will use throughout this course. ... That is over 35 years of continuous development. Very few software projects survive that long. PostgreSQL not only survived, it became one of the most popular databases in the world.

- 1986 — Started at UC Berkeley by Professor Michael Stonebraker
- Named POSTGRES (Post-Ingres — successor to Ingres database)
- Goal: Handle complex data types other databases couldn't
- 1996 — Renamed to PostgreSQL (added SQL support)
- Community took over — became fully open-source
- New major version released EVERY year since
- Now on PostgreSQL 16 — over 35 years of development!

### Why PostgreSQL Was Created
Why was PostgreSQL created in the first place? ... In the 1980s, existing databases had serious limitations. They could only store simple data types like numbers and text. They could not enforce complex business rules. They did not support extensibility ... meaning you could not add your own data types or functions. ... Stonebraker wanted a database that was extensible ... where you could define your own data types, create your own operators, and build custom functions. He wanted a database that followed standards ... specifically the SQL standard, so your knowledge would be portable. And he wanted it to be reliable ... so your data would never be lost, even during hardware failures. ... That vision from 1986 is exactly what PostgreSQL is today. It is the most standards-compliant, most extensible, and one of the most reliable databases in existence.

| 1980s Database Problems | PostgreSQL's Solutions |
| :--- | :--- |
| Only simple data types (numbers, text) | JSON, arrays, ranges, geo, custom types |
| No complex business rules | CHECK, triggers, RLS, custom functions |
| Not extensible — can't add custom types | Fully extensible — add types, operators, functions |
| Poor standards compliance | Most SQL-standard-compliant database |
| Expensive commercial licenses | 100% free and open source forever |
| Limited reliability | Rock-solid — ACID compliant, crash-safe |

### Who Uses PostgreSQL?
You might wonder ... is PostgreSQL actually used by real companies? Or is it just a university project? ... The answer will surprise you. ... Apple uses PostgreSQL. Instagram stores billions of user interactions in PostgreSQL. Spotify manages their music catalog with PostgreSQL. Netflix uses it for their internal tools. Reddit ... one of the biggest websites in the world ... runs on PostgreSQL. The International Space Station uses PostgreSQL for data management. ... Even governments and banks use PostgreSQL for critical systems. ... These are not small companies experimenting. These are the biggest technology companies in the world, trusting PostgreSQL with their most important data. If it is good enough for them, it is definitely good enough for us to learn.

- Apple — internal infrastructure
- Instagram — billions of user interactions
- Spotify — music catalog management
- Netflix — internal tooling and analytics
- Reddit — one of the biggest websites in the world
- International Space Station — data management
- Banks & Governments — critical financial systems
- If it's good enough for THEM — it's good enough for US!

### PostgreSQL's Key Strengths
What makes PostgreSQL special compared to other databases? There are several key strengths. ... First, standards compliance. PostgreSQL follows the SQL standard more closely than any other database. This means once you learn SQL in PostgreSQL, you can use that knowledge almost anywhere. ... Second, extensibility. You can create your own data types, operators, and functions. You can add extensions like PostGIS for geographic data, or TimescaleDB for time-series data. ... Third, data integrity. PostgreSQL takes your data very seriously. It supports full ACID transactions ... meaning your data is always consistent, even if the power goes off in the middle of an operation. ... Fourth, advanced features. JSON support, full-text search, table partitioning, parallel queries, logical replication ... PostgreSQL has features that even expensive commercial databases do not have. ... Fifth, community. Thousands of developers contribute to PostgreSQL. It has excellent documentation, active mailing lists, and a helpful community.

- Standards Compliance — most SQL-standard-compliant database
- Extensibility — add custom types, operators, extensions
- Data Integrity — full ACID transactions, crash-safe
- Advanced Features — JSON, full-text search, partitioning, parallel queries
- Community — thousands of contributors, excellent documentation
- Cost — 100% FREE, even for commercial use
- Reliability — runs critical systems at Apple, Instagram, banks

### PostgreSQL Version Highlights
PostgreSQL releases a new major version every year, usually in September or October. Each version adds new features and improvements. ... The current version is PostgreSQL 16, which is what we will use in this entire course. ... Some important version highlights ... PostgreSQL 12 added generated columns and improved partitioning. PostgreSQL 13 added incremental sorting and better vacuum. PostgreSQL 14 added multi-range types and connection pooling improvements. PostgreSQL 15 added SQL standard MERGE command and better security. PostgreSQL 16 ... our version ... added logical replication from standby, parallel full vacuum, and many performance improvements. ... The key point is ... PostgreSQL gets better every single year. And upgrading between versions is straightforward.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Yearly Release** | New major PostgreSQL release every autumn (Sept/Oct) |
| **PG 12 – 13** | Generated columns, incremental sort, improved VACUUM |
| **PG 14 – 15** | Multirange types, SQL-standard MERGE, stricter public schema |
| **PostgreSQL 16** | Current course version: logical standby repl, parallel full vacuum |
| **Upgrades** | Smooth major version upgrades with pg_upgrade |

### Why Open Source Matters for Databases
Let me explain why open source matters so much for a database. ... With a commercial database like Oracle, you pay licensing fees. These can be lakhs or even crores of rupees per year. If the company changes their pricing, you are stuck. If they stop supporting your version, you must upgrade on their timeline. You cannot see the source code, so you cannot fix bugs yourself. ... With PostgreSQL, there are no licensing fees ... ever. You can run it on one server or a thousand servers, and it costs the same ... zero. You can see the source code. If there is a bug, you or the community can fix it. No vendor can hold your data hostage. ... This is why PostgreSQL is called the world's most advanced open source database. It is not just free as in cost ... it is free as in freedom.

| Commercial (Oracle, SQL Server) | Open Source (PostgreSQL) |
| :--- | :--- |
| Pay LAKHS/CRORES per year | 100% FREE — forever |
| Vendor controls pricing | No vendor controls you |
| Forced upgrade timelines | Upgrade when YOU are ready |
| Cannot see source code | Full source code available |
| Cannot fix bugs yourself | Community fixes bugs quickly |
| Vendor lock-in risk | YOUR data, YOUR control |

### When to Use PostgreSQL
When should you choose PostgreSQL? ... Use PostgreSQL when you need strong data integrity ... banking, healthcare, e-commerce. Use it when you need complex queries and advanced SQL features. Use it when your data has complex relationships between tables. Use it when you need JSON support alongside relational data. Use it when you want a free database that can scale from a small project to millions of users. ... When might PostgreSQL NOT be the best choice? ... If you need a simple key-value cache, Redis is better. If you need a document store with no schema, MongoDB might be simpler. If you need a graph database for social networks, Neo4j is purpose-built. ... But for general-purpose applications ... which covers more than 80 percent of all projects ... PostgreSQL is an excellent choice.

| PostgreSQL is GREAT For | Consider Alternatives When |
| :--- | :--- |
| Strong data integrity (banking, healthcare) | Simple caching → Redis |
| Complex queries and advanced SQL | Schema-less documents → MongoDB |
| Relational data with relationships | Graph data (social networks) → Neo4j |
| JSON + relational data together | Simple embedded DB → SQLite |
| Free database that scales to millions | Time-series only → InfluxDB |
| 80%+ of all general-purpose projects | But: PG handles most of these too! |


---

## 3. Hands-On Commands & psql Output

*(Refer to the attached `materials.sql` script for full runnable queries and setups for this topic.)*


---

## 5. Common Beginner Traps & How to Fix Them

### Common Mistakes About PostgreSQL
Let me share some common mistakes about PostgreSQL. ... Mistake number one ... thinking PostgreSQL is just for small projects. Wrong! Instagram handles billions of records with PostgreSQL. It scales massively. ... Mistake number two ... thinking open source means lower quality. PostgreSQL has been developed for over 35 years by some of the best database engineers in the world. Its code quality is extremely high. ... Mistake number three ... confusing PostgreSQL with MySQL. They are very different. PostgreSQL is more standards-compliant, has more features, and handles complex queries better. We will compare them in detail in the next class. ... Mistake number four ... thinking you need to pay for enterprise features. PostgreSQL includes features like partitioning, replication, full-text search, and JSONB for free. In Oracle, many of these are paid add-ons.

- Mistake 1: 'PostgreSQL is only for small projects'
-    → Instagram handles BILLIONS of records with it!
- Mistake 2: 'Open source = lower quality'
-    → 35+ years of development by world-class engineers
- Mistake 3: 'PostgreSQL and MySQL are the same thing'
-    → Very different! PG is more compliant and feature-rich
- Mistake 4: 'Enterprise features require paid versions'
-    → Partitioning, replication, full-text search — all FREE in PG


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

Now it is your turn! Here are five exercises. ... Exercise 1 ... Visit postgresql.org and find the download page. What is the latest stable version available? ... Exercise 2 ... Name three companies that use PostgreSQL and think about what kind of data they might store. ... Exercise 3 ... What does open source mean? Why is it important for a database? Write your answer in your own words. ... Exercise 4 ... PostgreSQL was created in 1986. Calculate how many years it has been in development. Name three other software products that have survived this long. ... Exercise 5 ... A startup is building a food delivery app. They need to store restaurants, menus, orders, delivery addresses, and payment info. Would you recommend PostgreSQL? Why or why not? ... Pause the video and try these!

1. Exercise 1: Visit postgresql.org — what is the latest stable version?
2. Exercise 2: Name 3 companies using PostgreSQL — what data do they store?
3. Exercise 3: What does 'open source' mean? Why is it important for databases?
4. Exercise 4: PG started in 1986 — how many years of development? Name 3 other software that old.
5. Exercise 5: Food delivery app needs: restaurants, menus, orders, payments — recommend PG? Why?


---

## 7. Key Takeaways & Cheat Sheet

Let us wrap up. ... PostgreSQL is a free, open-source, relational database management system. It was created in 1986 at UC Berkeley and has over 35 years of development. It is the most SQL-standard-compliant database available. Companies like Apple, Instagram, Spotify, and Netflix use it. Key strengths are extensibility, data integrity, advanced features, and zero cost. It is the best choice for 80 percent or more of general-purpose applications. We will use PostgreSQL 16 throughout this entire course. ... In our next class, we will compare PostgreSQL with other databases like MySQL, Oracle, and MongoDB ... so you can see exactly how it stacks up.

- **Free, open-source relational DBMS**
- **Created 1986 at UC Berkeley — 35+ years of development**
- **Most SQL-standard-compliant database**
- **Used by Apple, Instagram, Spotify, Netflix, Reddit**
- **Key: extensibility, data integrity, advanced features, zero cost**
- **Best choice for 80%+ of general-purpose applications**
- **We use PostgreSQL 16 throughout this course**


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


## Answer Key ? Practice Exercises
1. **Latest Stable Version:** Visit `postgresql.org` ? PostgreSQL 16 is our course baseline, alongside the latest stable release listed on the download page.
2. **3 Companies & Their Data:** **Instagram** (user posts, comments & likes), **Spotify** (music catalog & playlists), and **Netflix** (internal studio tools & analytics).
3. **Why Open Source Matters:** Source code is publicly visible and free ? zero licensing fees, no vendor lock-in, and faster community security audits.
4. **35+ Years Since 1986 & Peer Software:** Over 38+ years of evolution since 1986; other long-lived software includes **Oracle** (1979), **GCC** (1987), **Linux** (1991), and **Python** (1991).
5. **Food Delivery App:** **YES** ? relational tables link restaurants, menus, orders, and delivery addresses cleanly, while ACID transactions protect every payment.
