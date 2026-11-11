# PostgreSQL 16 Complete Mastery — Free Class Materials (161 Classes)

Welcome to the official companion repository for the **PostgreSQL 16 Complete Mastery** course by **[MoolaVidya Gurukulam (Real Knowledge)](https://www.youtube.com/@MoolavidyaGurukulam)**.

> *"Moola Vidya" means Root Knowledge — understanding everything from its first principles rather than surface-level memorization. Everything in this repository is 100% free and open for every learner worldwide.*

---

## What Is Inside This Repository?

For **all 161 classes (across 33 Phases)**, each folder includes:
1. **`CLASS_NOTES.md`** — Complete step-by-step study guide (Real-world problem, analogies, architecture breakdowns, configuration parameter tables with `[RESTART]` vs `[RELOAD]` badges, common beginner traps, and practice exercises).
2. **`materials.sql`** — Ready-to-run SQL scripts, table setups, sample datasets, and practice queries tested for **PostgreSQL 16**.

### Key Course Guides
* **[Complete Class Index (All 161 Classes)](MASTER_DOWNLOAD_INDEX.md)** — Browse and jump directly to any class study guide or SQL script.
* **[Full Course Roadmap](00_ROADMAP.md)** — Complete curriculum map from Foundation to High Availability & Production DBA Scenarios.
* **[Technical Terms Glossary](Glossary_Technical_Terms.md)** — Plain-English glossary of PostgreSQL internals and terminology.

---

## How to Download & Run `materials.sql`

### Option A: Download Individual Class Files (No Git Needed)
1. Open **[MASTER_DOWNLOAD_INDEX.md](MASTER_DOWNLOAD_INDEX.md)** and click any class's **`CLASS_NOTES.md`** or **`materials.sql`** link.
2. Click the **Download raw file** icon (`⬇`) at the top-right of the file on GitHub.

### Option B: Download Everything at Once
1. Click the green **`<> Code`** button at the top of this repository → **`Download ZIP`**.
2. Or clone via terminal:
   ```bash
   git clone https://github.com/moolavidyagurukulam/postgresql-mastery.git
   ```

### Running a Class SQL Script in `psql`
```bash
# From your terminal:
psql -U postgres -d postgres -f materials.sql

# Or from inside the psql prompt:
postgres=# \i materials.sql
```

---

## Watch the Free Video Classes & Support Our Mission

* **YouTube Channel**: [@MoolavidyaGurukulam](https://www.youtube.com/@MoolavidyaGurukulam) *(100% Free Education: School Classes 1–12, Software Engineering, Farming & Financial Literacy)*
* **Contact**: `contact.moolavidyagurukulam@gmail.com`

*If these free classes and materials help you in your learning or career, please star ⭐ this repository and subscribe on YouTube!*
