# PostgreSQL 16 Mastery — Master Quality Gaps & Rebuild Checklist
> **Date Documented:** 2026-11-12 | **Target Scope:** All 161 Videos | **Course:** MoolaVidya Gurukulam (PostgreSQL 16 Admin & DBA)

---

## 1. Why We Are Rebuilding Videos — The Core Visual & Pedagogy Reasons

Yesterday, user feedback and our quality audit identified several critical gaps in the original video builds:

### A. Screen Real Estate & Small Font Bug
- **The Issue:** Early video versions only used **30% to 50% of the 1920x1080 canvas**. The font sizes were too small to read on mobile screens and tablets, leaving large empty dark margins.
- **The Subtitle Problem:** If we expand text to 100% of the canvas, YouTube closed captions and mobile controls overlap and block the SQL code / explanations at the bottom!
- **The Verified Fix (Applied to V001–V017):**
  - Text and cards use **75% to 80% screen width** (margins ~70px left/right).
  - High-contrast typography: Title (44px bold), Subtitle (24px), Section/H3 (23px bold), Code (20–23px monospace), Body/Notes (19–20px).
  - **Strict Subtitle Safe Zone:** All content strictly stays above **y ≤ 864 px** so subtitles never collide with text!

### B. Redesigned "Support Us" CTA Slide with Voice
- **The Issue:** Old CTA slides were plain, rushed, or lacked clear community purpose.
- **The Verified Fix:** Replaced with the standard MoolaVidya Gurukulam mission card:
  - Explains the 100% free digital Gurukulam vision (School Class 1–12, Software, Farming, Financial Literacy).
  - Clear, clean Buy Me a Coffee + UPI payment links.
  - Slow, warm voiceover (`en-US-AndrewNeural @ -18%`, ~40–45s).

### C. Voice Speed & Pacing
- **The Issue:** Several videos originally ran at natural or accelerated speed (up to **272 wpm** in V015 and ~209 wpm in V013), sounding like a fast auctioneer rather than a friendly Gurukulam teacher.
- **The Verified Fix:** Strictly enforce `en-US-AndrewNeural` at **`-18%` rate** with **`0.45s` frame-aligned pauses** between sentences. This creates a calm, deliberate **115–135 wpm** pace that is easy for non-native English speakers to follow.

### D. Audio/Video Desync (The 0.000s Rule)
- **The Issue:** When videos are concatenated without exact frame alignment, drift accumulates between the video stream and the audio stream.
- **The Verified Fix:** Every scene audio PCM is padded to exact 25 fps frame boundaries (`960` samples/frame at 24000 Hz mono `s16le`). Video duration and audio duration match down to **`diff = 0.000s`**.

---

## 2. Topic & Content Gaps Documented Across Videos 034–161

Our comprehensive audit of the 128 videos from Video 034 to 161 uncovered three specific content gaps:

### A. 37 "Thin" Videos (< 850 words / < 9 mins)
These videos touch the surface but do not provide the complete "Mastery" depth (missing WHY, real-world scenario, or production gotchas):
- **Index Types (`V045`–`V048`):** Hash, GIN, GiST, BRIN, Partial, Expression, and Covering indexes are explained too briefly. Need real-world query speedup benchmarks (e.g. 10M rows).
- **Concurrency & Locks (`V050`–`V052`):** Isolation levels (Dirty Read, Non-Repeatable Read, Phantom Read, Serialization Anomaly) and Advisory Locks need deeper multi-session demonstrations.
- **Backup & Archiving (`V069`, `V071`, `V073`):** pg_basebackup and pgBackRest need clear real-world disaster recovery walkthroughs.
- **Extensions Ecosystem (`V111`–`V125`):** FDWs (postgres_fdw), pg_cron, pgcrypto, PostGIS, pg_trgm, hstore, TimescaleDB, Citus, pgAudit need production use-case scenarios.
- **Enterprise Distributions (`V139`–`V143`):** Open Source vs EDB EPAS, Crunchy, Percona comparisons are too brief.

### B. 49 Videos Missing Hands-On Practice Challenges
A core teaching rule of MoolaVidya Gurukulam is: **"Every topic must end with 5 concrete hands-on exercises so students can practice typing inside psql."**
The following modules currently lack practice scenes in the script:
- **Vacuum & Bloat (`V076`–`V079`)**
- **Query Tuning & Execution Plans (`V080`–`V088`)**
- **Table Partitioning (`V089`–`V092`)**
- **Replication & High Availability (`V098`–`V106`)**
- **Extensions (`V107`–`V125`)**

### C. 9 Videos with Severe A/V Desync (> 0.5s)
These videos have an audible drift between audio and video slides (up to 23 seconds!) and **must be re-rendered**:
1. `Video_040_String_Date_Math_Functions` (`+20.83s`)
2. `Video_042_Views_Updatable_Views` (`+20.91s`)
3. `Video_059_Practical_PLPGSQL` (`+18.93s`)
4. `Video_069_RTO_RPO_Backup_Overview` (`+14.34s`)
5. `Video_085_Memory_Tuning` (`+22.71s`)
6. `Video_093_System_Catalogs_Stats` (`+22.73s`)
7. `Video_094_pg_stat_activity_Locks` (`+20.82s`)
8. `Video_106_HA_Tools_Architecture` (`+23.04s`)
9. `Video_146_Go_Kafka_CDC_PostgreSQL` (`+18.98s`)

---

## 3. Current Video Status Summary (As of 2026-11-12)

| Range | Videos | Status | What Was Done |
|---|---|---|---|
| **001 – 017** | 17 | **REBUILT & PUSHED** | Re-rendered with 75–80% text scale, subtitle safe zone, redesigned CTA, `-18%` Andrew voice, Answer Key, pushed to GitHub. |
| **018 – 025** | 8 | **CONTENT UPGRADED** | Scripts already have full WHY/WHAT/WHERE/terminal frames. Answer Keys added to `materials.sql` and `CLASS_NOTES.md` and pushed to GitHub. |
| **026 – 036** | 11 | **PENDING REVIEW** | Scripts have numeric IDs (`1`, `2`, `3`). Deep topics, zero desync. Need check if text scale is 75–80% or old 30–50%. |
| **037 – 161** | 125 | **AUDITED & LOGGED** | 62 videos complete; 37 thin videos need expansion; 49 need practice challenges; 9 desynced videos must be re-rendered. |

---

## 4. Rebuild & Quality Upgrade Protocol (Videos 018 – 161)

Whenever we upgrade or rebuild a video in this course, we strictly verify:
1. **Visuals:** 75%–80% screen width, high contrast, clean font hierarchy, content strictly in `y ≤ 864 px` (subtitle safe zone).
2. **Pedagogy:** Real-World Scenario → WHY → WHAT → WHERE/WHEN → HOW (live terminal) → Common Traps → Support CTA → 5 Hands-on Practice Puzzles → Summary.
3. **Audio:** `en-US-AndrewNeural @ -18%`, `0.45s` pause between sentences, 25 fps frame alignment (`960` samples/frame), `diff = 0.000s`.
4. **Docs & Sync:** Update `youtube_seo.txt` chapters, pure narration in `transcript.txt` (zero timestamps), full Answer Key in `CLASS_NOTES.md` and `materials.sql`, and `git push` to GitHub.
