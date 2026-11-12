# PostgreSQL vs Other Databases
**Series:** PostgreSQL Mastery | **Phase:** Phase 1: Foundation | **Classes:** Class 03
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In our previous class, we learned what PostgreSQL is and its history. Today, we compare PostgreSQL with other popular databases ... MySQL, Oracle, SQL Server, and MongoDB. By the end of this class, you will know exactly how PostgreSQL stacks up and when to choose it. ... Let us begin!

### The Problem: Which Database?
Here is a real scenario. Your company is starting a new project. The team lead asks ... which database should we use? ... One developer says MySQL because it is simple and popular. Another says Oracle because it is enterprise-grade. The DBA suggests PostgreSQL because it is free and powerful. The front-end developer wants MongoDB because it stores JSON. ... Everyone has a different opinion. How do you make the right choice? ... The answer is ... it depends on your specific needs. And to make the right decision, you need to understand what each database is good at and where it falls short. That is exactly what we will learn today.

- Developer A: 'Use MySQL — it's simple and popular'
- Developer B: 'Use Oracle — it's enterprise-grade'
- The DBA: 'Use PostgreSQL — it's free and powerful'
- Front-end dev: 'Use MongoDB — it stores JSON'
- Everyone has a different opinion!
- The answer: IT DEPENDS on your specific needs
- Today: Understand each database's strengths & weaknesses


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites
Before this class, you should know what a database is and what PostgreSQL is. We covered those in our classes on What is a Database and What is PostgreSQL.

- You should know: What is a database and what is PostgreSQL
- Covered in: What is a Database + What is PostgreSQL classes

### The Problem: Which Database?
Here is a real scenario. Your company is starting a new project. The team lead asks ... which database should we use? ... One developer says MySQL because it is simple and popular. Another says Oracle because it is enterprise-grade. The DBA suggests PostgreSQL because it is free and powerful. The front-end developer wants MongoDB because it stores JSON. ... Everyone has a different opinion. How do you make the right choice? ... The answer is ... it depends on your specific needs. And to make the right decision, you need to understand what each database is good at and where it falls short. That is exactly what we will learn today.

- Developer A: 'Use MySQL — it's simple and popular'
- Developer B: 'Use Oracle — it's enterprise-grade'
- The DBA: 'Use PostgreSQL — it's free and powerful'
- Front-end dev: 'Use MongoDB — it stores JSON'
- Everyone has a different opinion!
- The answer: IT DEPENDS on your specific needs
- Today: Understand each database's strengths & weaknesses

### PostgreSQL vs MySQL
Let us start with the most common comparison ... PostgreSQL vs MySQL. ... MySQL was created in 1995 and is now owned by Oracle Corporation. It is the most popular open-source database by number of installations. ... But popularity does not mean better. Let me show you the key differences. ... Licensing ... MySQL has a dual license. The community edition is free, but the enterprise edition costs money. PostgreSQL is completely free with no paid version needed. ... SQL compliance ... PostgreSQL follows the SQL standard much more closely. For example, PostgreSQL supports full outer joins, window functions, CTEs, and MERGE ... all standard SQL. MySQL has added many of these over time but still has gaps. ... Data types ... PostgreSQL supports arrays, JSON B, ranges, network addresses, geometric types, and custom types. MySQL has a more limited set. ... Concurrency ... PostgreSQL uses M V C C ... multi version concurrency control ... which means readers never block writers. MySQL's InnoDB also uses M V C C, but PostgreSQL's implementation is more mature. ... The bottom line ... MySQL is easier to get started with. PostgreSQL is more powerful for complex applications.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Licensing** | MySQL: Oracle dual-license | PG: 100% free, zero paid editions |
| **SQL Standard** | PG leads on window functions, CTEs, FULL OUTER JOIN, MERGE |
| **Data Types** | PG adds Arrays, JSONB, Ranges, INET/CIDR, custom types |
| **Concurrency** | PG mature MVCC keeps readers & writers from blocking |
| **Bottom Line** | MySQL is easy to start; PG excels at complex enterprise workloads |

### PostgreSQL vs Oracle
Now let us compare PostgreSQL with Oracle Database. ... Oracle is the king of enterprise databases. It has been around since 1979 and dominates banks, governments, and large corporations. ... But Oracle comes with a massive price tag. Oracle Standard Edition costs around 17000 dollars per processor. Enterprise Edition costs around 47000 dollars per processor. And that is just the base license ... many features like partitioning, compression, and advanced security are additional paid options. ... PostgreSQL gives you most of these features for free. Partitioning ... free. Full-text search ... free. Replication ... free. JSON support ... free. ... The gap between Oracle and PostgreSQL has been shrinking every year. Many organizations are migrating from Oracle to PostgreSQL specifically to save on licensing costs. ... Oracle is still stronger in some areas like Real Application Clusters for horizontal scaling, and its optimizer is more mature for extremely complex queries. But for the vast majority of workloads, PostgreSQL matches Oracle's capabilities at zero cost.

| Term | Meaning / Explanation |
| :--- | :--- |
| **License Cost** | Oracle: ~$17K–$47K/CPU + paid add-ons | PG: $0 forever |
| **Free Features** | Partitioning, replication, full-text & JSON included free in PG |
| **Oracle Strength** | Real Application Clusters (RAC) for extreme multi-node write scale |
| **Migration Trend** | Banks & enterprises actively migrate Oracle workloads to PG |

### PostgreSQL vs SQL Server
Next, PostgreSQL vs Microsoft SQL Server. ... SQL Server is Microsoft's database, popular in organizations that use the Microsoft ecosystem ... Windows Server, dot NET, Azure. ... SQL Server has a free Express edition, but it is limited to 10 gigabytes of data and 1 gigabyte of RAM. The Standard edition starts at around 3900 dollars per core. Enterprise is even more expensive. ... PostgreSQL has no such limits. You can use all your RAM, all your disk, and all your cores ... for free. ... SQL Server is tightly integrated with Windows and the Microsoft ecosystem. If your company is all-in on Microsoft, SQL Server makes sense. ... But PostgreSQL runs on Linux, Windows, and Mac. It works with any programming language and any framework. It is not locked to any vendor's ecosystem. ... Feature-wise, they are very close. Both have strong SQL support, both handle complex queries well, both have good replication. The main difference is cost and vendor independence.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Limits & Cost** | MSSQL Express caps 10GB/1GB RAM; Standard ~$3.9K/core | PG: no caps |
| **Ecosystem** | SQL Server shines inside Windows, .NET & Microsoft shops |
| **OS Portability** | PostgreSQL runs natively on Linux, Windows, macOS & cloud |
| **Key Difference** | Matched features — main separator is cost & vendor freedom |

### PostgreSQL vs MongoDB
Finally, PostgreSQL vs MongoDB. This is a different kind of comparison because MongoDB is NOT a relational database. It is a document database. ... MongoDB stores data as JSON-like documents in collections. There are no tables, no rows, no columns. Each document can have a different structure. This is called schema-less or schema-flexible. ... PostgreSQL, on the other hand, stores data in structured tables with defined columns. BUT ... and this is important ... PostgreSQL also supports JSONB. This means you can store JSON documents inside PostgreSQL, with full indexing and querying support. ... So when do you choose MongoDB? When your data truly has no fixed structure and changes frequently. When you need to store deeply nested documents. When you want the simplest possible setup for a prototype. ... When do you choose PostgreSQL? When your data has relationships. When you need transactions across multiple tables. When you want BOTH structured and unstructured data in one database. ... In practice, PostgreSQL with JSONB covers most use cases where people think they need MongoDB.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Data Model** | MongoDB: schema-less JSON collections | PG: tables + JSONB |
| **Use MongoDB** | Truly unfixed nested schemas with zero relational JOINs |
| **Use PostgreSQL** | Relationships, multi-table ACID transactions, or relational + JSONB |
| **Real Practice** | PG's indexed JSONB covers most use cases cleanly in one DB |

### PostgreSQL vs MySQL vs Oracle vs SQL Server vs MongoDB
Let me give you one big comparison table so you can see all four databases side by side. This is the kind of table you should save for future reference. ... The key takeaway is this ... PostgreSQL gives you the best balance of features, cost, and standards compliance. It is free like MySQL, powerful like Oracle, modern like SQL Server, and flexible like MongoDB. That is why it is called the world's most advanced open source database.

| Feature | PostgreSQL | MySQL | Oracle | SQL Server | MongoDB |
| :--- | :--- | :--- | :--- | :--- | :--- |
| License Cost | $0 Forever | Dual / Paid Ent. | $17K-$47K/CPU | ~$3.9K+/core | Free / Atlas Paid |
| Data Model | Relational + JSONB | Relational | Relational | Relational | JSON Documents |
| SQL Standard | Highest | Good (Gaps) | High | High (T-SQL) | No SQL (MQL) |
| Partitioning | 100% Free | Free / Paid Ent. | Extra Paid Addon | Ent. Edition | Built-in Replica |
| Best Fit | 80%+ Apps/Ent. | Simple Web/LAMP | Legacy Banks/RAC | .NET/Windows | Unstructured Docs |

### Decision Framework: Choosing a Database
Let me give you a simple decision framework. When someone asks you which database to use, ask these questions. ... Question 1 ... Is budget a concern? If yes, eliminate Oracle and SQL Server Enterprise. PostgreSQL and MySQL are both free. ... Question 2 ... Do you need advanced SQL features like window functions, CTEs, and full outer joins? If yes, PostgreSQL is the better choice over MySQL. ... Question 3 ... Is your team already in the Microsoft ecosystem? If yes, SQL Server integrates well. If not, PostgreSQL is more flexible. ... Question 4 ... Is your data truly schema-less with no relationships? If yes, consider MongoDB. If you have ANY relationships between data, use PostgreSQL. ... Question 5 ... Do you need enterprise features like partitioning and replication without paying? PostgreSQL gives these for free. Oracle charges extra. ... For most new projects in 2026, PostgreSQL is the safest and most capable choice.

- Q1: Budget concern? → Eliminate Oracle, SQL Server Enterprise
- Q2: Need advanced SQL? → PostgreSQL over MySQL
- Q3: Microsoft ecosystem? → SQL Server fits; otherwise PostgreSQL
- Q4: Truly schema-less, no relationships? → MongoDB; otherwise PostgreSQL
- Q5: Need enterprise features for free? → PostgreSQL wins
- For most new projects: PostgreSQL is the safest choice

### Real-World Database Choice & Migration Cases
Before we summarize, let us look at three real-world decisions engineers face. ... First, an online store needs rock-solid ACID transactions for customer payments, PLUS flexible JSONB columns for product specs that differ between phones and shoes ... PostgreSQL handles both natively. ... Second, many banks and SaaS companies migrate away from expensive Oracle servers to PostgreSQL because partitioning, replication, and roles come included for zero licensing cost. ... Third, many startups begin with MongoDB only to hit pain later when finance asks for complex multi-table joins. Starting on PostgreSQL prevents costly rewrites down the road.

> **Definition:** Why modern engineering teams migrate TO PostgreSQL in production.

| Term | Meaning / Explanation |
| :--- | :--- |
| **E-Commerce** | Chose PostgreSQL for strict ACID orders + JSONB product specs |
| **Banking Move** | Replaced costly Oracle licenses using PG partitioning + logical replication |
| **Startup Trap** | Started on MongoDB for speed, struggled later with billing JOIN reports |
| **Lesson** | Start relational + JSONB in PostgreSQL unless data has zero relationships |


---

## 3. Hands-On Commands & psql Output

### What PostgreSQL Lets You Write (Built-In & Free)
**Explanation:** To make these differences real, look at what PostgreSQL lets you write cleanly in a single database. ... In one query, you can combine a Common Table Expression with a window function like RANK OVER to analyze departmental revenue, and atomically save the result with INSERT ON CONFLICT DO UPDATE. ... Even better, right below that, you can query strict relational tables alongside semi-structured JSONB preferences using the containment operator. Features like window functions, atomic upsert, and fast indexed JSONB explain why teams consolidate onto PostgreSQL instead of juggling multiple databases.

```sql
-- CTEs, Window Functions, UPSERT & Indexed JSONB all in ONE engine:
WITH monthly AS (
  SELECT dept, SUM(revenue) AS rev,
         RANK() OVER (ORDER BY SUM(revenue) DESC) AS rnk
  FROM orders GROUP BY dept
)
INSERT INTO dept_summary (dept, total_rev, top_rank)
SELECT dept, rev, rnk FROM monthly
ON CONFLICT (dept) DO UPDATE SET total_rev = EXCLUDED.total_rev;

-- Query relational columns + JSONB attributes together:
SELECT id, prefs->>'theme' FROM users WHERE prefs @> '{"pro": true}';
```


---

## 5. Common Beginner Traps & How to Fix Them

### Common Mistakes When Choosing a Database
Common mistakes when choosing a database. ... Mistake 1 ... Choosing based on popularity alone. MySQL has more installations, but that does not mean it is better for your project. Choose based on features and requirements. ... Mistake 2 ... Choosing Oracle just because it is expensive. Expensive does not mean better. Many companies waste lakhs on Oracle licenses when PostgreSQL would work perfectly. ... Mistake 3 ... Choosing MongoDB because JSON is cool. If your data has relationships like customers, orders, and products, you will struggle without joins and foreign keys. PostgreSQL handles JSON too. ... Mistake 4 ... Thinking you cannot switch later. Migration tools exist. Many companies have successfully migrated from Oracle to PostgreSQL, or from MySQL to PostgreSQL. It is work, but it is possible.

- Mistake 1: Choosing based on popularity alone
-    → MySQL has more installs, but PG has more features
- Mistake 2: Choosing Oracle because it's expensive
-    → Expensive ≠ better. PG matches most Oracle features for FREE
- Mistake 3: Choosing MongoDB because 'JSON is cool'
-    → If data has relationships, you NEED joins. PG has JSONB too!
- Mistake 4: Thinking you can't switch later
-    → Migration tools exist. Oracle → PG migrations are common


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

Practice time! ... Exercise 1 ... A startup is building a social media app. They need user profiles, posts, comments, likes, and followers. Which database would you recommend and why? ... Exercise 2 ... A bank currently uses Oracle and pays 50 lakh rupees per year in licenses. Their workload is mostly OLTP. Can they switch to PostgreSQL? What would they gain and lose? ... Exercise 3 ... A developer wants to build a simple blog. They are choosing between MySQL and PostgreSQL. What three questions would you ask to help them decide? ... Exercise 4 ... Name one thing that Oracle can do that PostgreSQL cannot. And name one thing PostgreSQL can do that Oracle charges extra for. ... Exercise 5 ... Your team has a project that stores both relational data in tables and JSON documents from an API. Should you use PostgreSQL, MongoDB, or both? Explain your reasoning.

1. Exercise 1: Social media app (profiles, posts, likes) — which DB? Why?
2. Exercise 2: Bank pays Rs 50L/year for Oracle. Can they switch to PG?
3. Exercise 3: Simple blog — MySQL or PG? What 3 questions to ask?
4. Exercise 4: One thing Oracle does that PG can't + one PG does free that Oracle charges for
5. Exercise 5: Project has relational data + JSON from API — PG, MongoDB, or both?


---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. ... PostgreSQL vs MySQL ... PostgreSQL is more feature-rich and SQL-compliant. MySQL is simpler to start with. ... PostgreSQL vs Oracle ... PostgreSQL matches most Oracle features for free. Oracle is stronger for extreme scale and complex optimizer scenarios. ... PostgreSQL vs SQL Server ... PostgreSQL is vendor-neutral and free. SQL Server is best in the Microsoft ecosystem. ... PostgreSQL vs MongoDB ... PostgreSQL handles both relational and JSON data. MongoDB is only for truly schema-less data. ... For most projects, PostgreSQL gives you the best balance of power, features, standards compliance, and cost. ... In our next class, we will learn about PostgreSQL distributions ... open source vs EDB vs cloud-managed options.

- **vs MySQL: PG is more feature-rich; MySQL is simpler to start**
- **vs Oracle: PG matches most features FREE; Oracle stronger for extreme scale**
- **vs SQL Server: PG is vendor-neutral & free; MSSQL best for Microsoft stack**
- **vs MongoDB: PG handles relational + JSON; Mongo for schema-less only**
- **PostgreSQL = best balance of power, features, cost**
- **Used by Apple, Instagram, Spotify — proven at scale**
- **Our choice for this course: PostgreSQL 16**


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
