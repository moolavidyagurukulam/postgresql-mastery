# Prometheus & Grafana Monitoring — Real-Time Dashboards for PostgreSQL
**Series:** PostgreSQL Mastery | **Phase:** Phase 23: Monitoring & Troubleshooting | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! Log files tell you what happened in the past. pg_stat_activity tells you what is happening right now. But for continuous, real-time monitoring with alerts, you need a dedicated monitoring stack. The most popular open-source combination is Prometheus for collecting metrics and Grafana for visualizing them. Let us set this up for PostgreSQL.


---

## 2. Core Technical Concepts & Mechanisms

### Monitoring Stack Architecture
The monitoring architecture has four components. postgres_exporter connects to PostgreSQL and exposes metrics on an HTTP endpoint. Prometheus scrapes those metrics at regular intervals and stores them as time-series data. Grafana queries Prometheus and renders dashboards. Alertmanager sends notifications when metrics cross thresholds.

```
[PostgreSQL
Server]
[postgres_exporter
:9187]
[Prometheus
:9090]
[Grafana
:3000]
[Alertmanager
:9093]
```

### Key postgres_exporter Metrics
Here are the key metrics that postgres_exporter provides out of the box. These map directly to the pg_stat views we learned earlier, but now they are collected as time-series so you can see trends over hours, days, and weeks.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here are the key metrics that postgres_exporter provides out of the box |
| **Point 2** | These map directly to the pg_stat views we learned earlier, but now they are collected as time-series so you can see trends over hours, days, and weeks |

### Setting Up Grafana for PostgreSQL
Grafana connects to Prometheus as a data source and lets you build beautiful dashboards. The fastest way to get started is to import a pre-built PostgreSQL dashboard. Dashboard ID 9628 is the most popular community dashboard for postgres_exporter.

- Step 1: Install Grafana -- sudo apt install grafana; sudo systemctl start grafana-server → http://localhost:3000 (admin/admin)
- Step 2: Add Prometheus data source -- Configuration → Data Sources → Add → Prometheus → URL: http://localhost:9090 → Save & Test
- Step 3: Import PostgreSQL dashboard -- Dashboards → Import → Dashboard ID: 9628 → Load → Select Prometheus data source → Import
- Step 4: Verify metrics are flowing -- Dashboard should show TPS, connections, cache ratio, database size
- Step 5: Customize panels -- Add custom PromQL queries for your specific metrics

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Essential PostgreSQL Alert Rules
Here is the complete set of alert rules you should have for a production PostgreSQL server. These cover the most critical failure modes.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is the complete set of alert rules you should have for a production PostgreSQL server |
| **Point 2** | These cover the most critical failure modes |

### Essential Grafana Dashboard Panels
A key Grafana dashboard should show these panels. Here is the layout of a production PostgreSQL dashboard — the panels you need and the PromQL queries behind them.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | A key Grafana dashboard should show these panels |
| **Point 2** | Here is the layout of a production PostgreSQL dashboard — the panels you need and the PromQL queries behind them |

### Monitoring Tool Alternatives
There are alternatives to Prometheus and Grafana. pgwatch2 is a PostgreSQL-specific monitoring tool that is simpler to set up. Datadog has a PostgreSQL integration. AWS RDS has built-in Performance Insights. But Prometheus plus Grafana is the most flexible and widely used open-source option.

| Open Source | Commercial / Cloud |
| :--- | :--- |
| Prometheus + Grafana: most popular, flexible | Datadog: SaaS, PG integration |
| pgwatch2: PG-specific, simpler setup | AWS RDS Performance Insights: built into RDS |
| Zabbix: enterprise monitoring, PG plugins | pganalyze: PG-specific SaaS monitoring |
| Netdata: real-time, auto-discovery | New Relic: APM with PG integration |
| Nagios/Icinga: classic, check-based | Percona Monitoring (PMM): free, PG-focused |

### Start with Five Essential Metrics
A beginner trap: monitoring too many metrics. Start with the essential five: transactions per second, cache hit ratio, connection count, replication lag, and dead rows. Once you understand these, add more. Monitoring everything at once leads to alert fatigue — you ignore all alerts because there are too many.

- 1. Transactions Per Second (TPS) -- Shows throughput. Sudden drops = problem. Gradual increase = growing traffic.
- 2. Cache Hit Ratio -- Should be > 99%. Drop below 95% = shared_buffers too small or data doesn't fit.
- 3. Active Connection Count -- Approaching max_connections = connection leak or missing pgBouncer.
- 4. Replication Lag -- Growing lag = standby falling behind. Zero = healthy replication.
- 5. Dead Row Count (Top Table) -- Growing dead rows = autovacuum not keeping up. Causes bloat and slow queries.

### Prometheus Best Practices
A beginner trap with Prometheus: not setting proper retention. By default, Prometheus keeps 15 days of data. For a PostgreSQL monitoring setup, 30 to 90 days is more useful — it lets you compare this month to last month. Also, make sure your scrape interval is not too aggressive. Ten to fifteen seconds is fine for postgres_exporter. One second intervals create excessive load on both PostgreSQL and Prometheus.

| Term | Meaning / Explanation |
| :--- | :--- |
| **A beginner trap with Prometheus** | not setting proper retention |
| **By default** | Prometheus keeps 15 days of data |
| **For a PostgreSQL monitoring setup** | 30 to 90 days is more useful — it lets you compare this month to last month |
| **Point 4** | Also, make sure your scrape interval is not too aggressive |
| **Point 5** | Ten to fifteen seconds is fine for postgres_exporter |
| **Point 6** | One second intervals create excessive load on both PostgreSQL and Prometheus |

### Complete Monitoring Setup Checklist
Here is your complete monitoring setup checklist — everything you need from install to alerting.

- 1. Create monitoring role in PostgreSQL -- CREATE ROLE monitoring LOGIN; GRANT pg_monitor TO monitoring;
- 2. Install and configure postgres_exporter -- Set DATA_SOURCE_NAME, add custom queries, run as systemd service
- 3. Install Prometheus, add postgres_exporter target -- scrape_configs → job_name: postgresql → targets: localhost:9187
- 4. Add alert rules for critical metrics -- pg_up, connections, cache ratio, bloat, replication lag
- 5. Install Grafana, import dashboard 9628 -- Add Prometheus data source, import PostgreSQL dashboard
- 6. Configure Alertmanager for notifications -- Email for warnings, Slack/PagerDuty for critical


---

## 3. Hands-On Commands & psql Output

### Installing postgres_exporter
**Explanation:** postgres_exporter is the bridge between PostgreSQL and Prometheus. It connects to your database, runs diagnostic queries, and exposes the results as Prometheus metrics. You can use the built-in metrics or add custom queries.

```sql
# Download postgres_exporter:
wget https://github.com/prometheus-community/\
  postgres_exporter/releases/download/v0.15.0/\
  postgres_exporter-0.15.0.linux-amd64.tar.gz
tar xzf postgres_exporter-0.15.0.linux-amd64.tar.gz
cd postgres_exporter-0.15.0.linux-amd64
# Create a monitoring role in PostgreSQL:
psql -U postgres -c "
postgres=# CREATE ROLE monitoring WITH LOGIN PASSWORD 'monitor123';
postgres=# GRANT pg_monitor TO monitoring;"
# Set connection string:
export DATA_SOURCE_NAME=\
  'postgresql://monitoring:monitor123@localhost:5432/mydb?sslmode=disable'
# Start the exporter:
./postgres_exporter --web.listen-address=:9187
# Verify metrics are exposed:
curl http://localhost:9187/metrics | head -20
# pg_up 1
# pg_stat_database_xact_commit{datname="mydb"} 2845630
# pg_stat_database_blks_hit{datname="mydb"} 890234
```

### Prometheus Configuration
**Explanation:** Now let us configure Prometheus to scrape metrics from postgres_exporter. Prometheus uses a YAML configuration file that defines scrape targets and intervals.

```sql
# /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s        # Collect metrics every 15 seconds
  evaluation_interval: 15s    # Evaluate alert rules every 15s
scrape_configs:
  # Prometheus monitors itself:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  # PostgreSQL via postgres_exporter:
  - job_name: 'postgresql'
    static_configs:
      - targets: ['localhost:9187']
    scrape_interval: 10s       # More frequent for DB metrics
  # Multiple servers:
  # - job_name: 'postgresql-prod'
  #   static_configs:
  #     - targets:
  #       - 'db-primary:9187'
  #       - 'db-replica1:9187'
  #       - 'db-replica2:9187'
# Start Prometheus:
# prometheus --config.file=/etc/prometheus/prometheus.yml
# Web UI: http://localhost:9090
```

### Essential PromQL Queries for PostgreSQL
**Explanation:** You can query Prometheus directly with PromQL — its query language. Here are the essential PromQL queries for PostgreSQL monitoring. These are the same queries you will use in Grafana dashboards.

```sql
# Transactions per second (TPS):
rate(pg_stat_database_xact_commit{datname="mydb"}[5m])

# Cache hit ratio (%):
100 * pg_stat_database_blks_hit{datname="mydb"}
    / (pg_stat_database_blks_hit{datname="mydb"}
     + pg_stat_database_blks_read{datname="mydb"})

# Active connections:
pg_stat_activity_count{state="active"}

# Total connections:
sum(pg_stat_activity_count)

# Dead rows (top bloated table):
topk(5, pg_stat_user_tables_n_dead_tup)

# Temp files per second (work_mem spills):
rate(pg_stat_database_temp_files{datname="mydb"}[5m])

# Replication lag in bytes:
pg_replication_lag

# Database size in bytes:
pg_database_size_bytes{datname="mydb"}
```

### Custom Metrics for postgres_exporter
**Explanation:** Custom metrics let you monitor application-specific things that postgres_exporter does not cover by default. You write SQL queries in a YAML file and postgres_exporter runs them and exposes the results as metrics.

```sql
# /etc/postgres_exporter/queries.yaml
# Orders per status:
pg_orders_by_status:
  query: |
postgres=# SELECT status, count(*) AS count
postgres-# FROM orders GROUP BY status
  metrics:
    - status:
        usage: "LABEL"
    - count:
        usage: "GAUGE"
        description: "Number of orders by status"
# Oldest running transaction:
pg_oldest_transaction:
  query: |
postgres=# SELECT EXTRACT(EPOCH FROM (now() - xact_start))::int
postgres-# AS age_seconds
postgres-# FROM pg_stat_activity
postgres-# WHERE xact_start IS NOT NULL
postgres-# ORDER BY xact_start LIMIT 1
  metrics:
    - age_seconds:
        usage: "GAUGE"
        description: "Age of oldest transaction in seconds"
# Start with custom queries:
# postgres_exporter --extend.query-path=/etc/postgres_exporter/queries.yaml
```

### Prometheus Alert Rules for PostgreSQL
**Explanation:** Alerting is what makes monitoring proactive instead of reactive. You define alert rules in Prometheus — when a metric crosses a threshold, Prometheus sends the alert to Alertmanager, which sends you a notification via email, Slack, PagerDuty, or other channels.

```sql
# /etc/prometheus/pg_alerts.yml
groups:
  - name: postgresql
    rules:
      - alert: PostgreSQLDown
        expr: pg_up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "PostgreSQL is DOWN"
      - alert: HighConnectionUsage
        expr: >
          sum(pg_stat_activity_count)
          / pg_settings_max_connections > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Connection usage above 80%"
      - alert: LowCacheHitRatio
        expr: >
          pg_stat_database_blks_hit
          / (pg_stat_database_blks_hit
           + pg_stat_database_blks_read) < 0.95
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Cache hit ratio below 95%"
      - alert: HighTableBloat
        expr: pg_stat_user_tables_n_dead_tup > 100000
        for: 30m
        labels:
          severity: warning
        annotations:
          summary: "Table has > 100K dead rows"
```

### Alertmanager Configuration
**Explanation:** Alertmanager handles routing alerts to the right people via the right channels. Here is a basic configuration for email and Slack notifications.

```sql
# /etc/alertmanager/alertmanager.yml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@example.com'
route:
  receiver: 'default'
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  routes:
    - match:
        severity: critical
      receiver: 'pagerduty-critical'
    - match:
        severity: warning
      receiver: 'slack-warnings'
receivers:
  - name: 'default'
    email_configs:
      - to: 'dba-team@example.com'
  - name: 'slack-warnings'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/...'
        channel: '#db-alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ .CommonAnnotations.summary }}'
  - name: 'pagerduty-critical'
    pagerduty_configs:
      - service_key: '<your-key>'
```

### postgres_exporter as a systemd Service
**Explanation:** Let us set up a systemd service for postgres_exporter so it starts automatically and restarts on failure. This is the production way to run the exporter.

```sql
# /etc/systemd/system/postgres_exporter.service
[Unit]
Description=PostgreSQL Exporter
After=network.target postgresql.service
[Service]
User=postgres_exporter
Group=postgres_exporter
Type=simple
Environment=DATA_SOURCE_NAME=postgresql://monitoring:monitor123@localhost:5432/mydb?sslmode=disable
ExecStart=/usr/local/bin/postgres_exporter \
postgres=# --web.listen-address=:9187 \
postgres=# --extend.query-path=/etc/postgres_exporter/queries.yaml
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
# Enable and start:
# sudo systemctl daemon-reload
# sudo systemctl enable postgres_exporter
# sudo systemctl start postgres_exporter
# sudo systemctl status postgres_exporter
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. Prometheus plus Grafana is the standard open-source monitoring stack for PostgreSQL. postgres_exporter bridges PostgreSQL statistics to Prometheus metrics. Configure scraping at 10-15 second intervals. Start with five essential metrics: TPS, cache hit ratio, connections, replication lag, and dead rows. Set up alert rules for critical thresholds. Use Alertmanager for email, Slack, or PagerDuty notifications. In the next class, we build a complete health check script and work through common troubleshooting scenarios.

- **Architecture: PostgreSQL → postgres_exporter → Prometheus → Grafana**
- **postgres_exporter: exposes pg_stat views as Prometheus metrics**
- **Custom queries: YAML file with SQL → metric mappings**
- **Prometheus: scrapes metrics, stores time-series, evaluates alerts**
- **Grafana: dashboard visualization (import dashboard 9628)**
- **PromQL: rate(), topk(), gauge queries for PostgreSQL**
- **Alert rules: pg_up, connections, cache, bloat, replication**
- **Alertmanager: routes alerts to email, Slack, PagerDuty**
- **Start small: 5 essential metrics, avoid alert fatigue**
- **Run postgres_exporter as systemd service in production**
- **Next: Health Checks & Troubleshooting Scenarios**


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
