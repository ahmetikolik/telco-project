# 📊 Telco Project — Oracle XE + SQL



This repo contains my answers to the i2i Systems Telco SQL project: a normalized
schema for the provided telecom data, an Oracle XE container that bootstraps
itself via Docker Compose, and 12 SQL queries (each documented in detail).

## 📁 Repo layout

```
telco-project/
├── docker-compose.yml          # Oracle XE container + auto-init
├── TABLE_CREATION_SCRIPTS.sql  # Schema: tables, FKs, checks, indexes
├── SOLUTIONS.sql               # All 12 answers in one file (i2i requirement)
├── queries/                    # Same 12 answers, split per section for review
│   ├── 01_tariff_customers.sql
│   ├── 02_tariff_distribution.sql
│   ├── 03_signup_analysis.sql
│   ├── 04_missing_records.sql
│   ├── 05_usage_analysis.sql
│   └── 06_payment_analysis.sql
├── TARIFFS.csv                 # Provided source data
├── CUSTOMERS.csv
├── MONTHLY_STATS.csv
└── README.md
```

I keep both `SOLUTIONS.sql` (combined, as the brief asks) and `queries/` (split
per section). The combined file is the canonical deliverable; the split files
made it easier for me to run / debug one section at a time during development.

## 🛠️ How to reproduce

### Prerequisites
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [DBeaver Community](https://dbeaver.io/) (or any Oracle-compatible client)

### 1 · Start the database

```bash
docker compose up -d
```

The first start takes ~2 minutes — the image initialises Oracle XE *and* runs
my table creation script automatically (mounted into
`/container-entrypoint-initdb.d/`). Watch progress with:

```bash
docker compose logs -f oracle-xe
```

When the log shows `DATABASE IS READY TO USE!`, the schema is already in place.

### 2 · Connect from DBeaver

| Field | Value |
| --- | --- |
| Host | `localhost` |
| Port | `1521` |
| Database / Service | `XEPDB1` |
| Username | `TELCO` |
| Password | `telco_pass` |

Click **Test Connection** — you should be in.

### 3 · Import the CSVs

The tables already exist. Now load the data via DBeaver — for each CSV:

1. Right-click the matching table → **Import Data**
2. Source: **CSV** → pick the file
3. Map the columns (defaults usually match the headers)
4. **For `CUSTOMERS.csv`** set the date format to `DD/MM/YYYY` so `SIGNUP_DATE` parses
5. Run the import

> **Order matters** because of the foreign keys: import `TARIFFS` first, then
> `CUSTOMERS`, then `MONTHLY_STATS`.

### 4 · Run the queries

Open `SOLUTIONS.sql` (or any single file from `queries/`) in DBeaver and run
each statement. Every query has a comment block above it explaining what it
does, the joins involved, and any edge case I considered.

## 🧠 Schema decisions

- **`SIGNUP_DATE` is a real `DATE`** — lets the database sort and filter
  chronologically without parsing strings each time. Section 3 ("earliest
  customers") needs real date semantics; the hint warns IDs do not match
  signup order.
- **Foreign keys** between `CUSTOMERS → TARIFFS` and `MONTHLY_STATS → CUSTOMERS`
  so the database itself enforces referential integrity. A bad CSV row fails
  loudly on import instead of leaving dangling references.
- **`CHECK (>= 0)` constraints** on every numeric column — negative usage,
  fees or limits would be data corruption, so I'd rather catch it at insert.
- **Indexes** on the columns I actually filter or join on:
  `CUSTOMERS.TARIFF_ID`, `CUSTOMERS.CITY`, `CUSTOMERS.SIGNUP_DATE`,
  `MONTHLY_STATS.CUSTOMER_ID`, `MONTHLY_STATS.PAYMENT_STATUS`.
  No indexes on columns no query touches, to keep insert overhead low.
- **Idempotent DDL** — `TABLE_CREATION_SCRIPTS.sql` drops the tables in reverse
  FK order before creating them, so it can be re-run safely.

## 🧠 Query decisions worth flagging

A few highlights — full reasoning is in the comment block above each query:

- **1.2** — uses `ROW_NUMBER() OVER` in a CTE rather than `FETCH FIRST WITH TIES`,
  because the CTE pattern is easier to extend if the team later asks for
  "newest 5" or "newest per city".
- **3.1 / 3.2** — minimum signup date is computed once in a CTE (`first_day`)
  and reused, instead of re-running `MIN(SIGNUP_DATE)` per query.
- **4.1 / 4.2** — uses `NOT EXISTS` (correlated subquery) for the anti-join.
  Reads more naturally than `LEFT JOIN ... IS NULL`; Oracle optimises both
  the same way.
- **5.1** — guards against divide-by-zero by excluding tariffs where
  `DATA_LIMIT = 0` and by comparing `DATA_USAGE >= 0.75 * DATA_LIMIT` (no
  literal division involved).
- **5.2** — only counts a dimension as "exhausted" when its limit is `> 0`,
  so a 0-allowance plan doesn't trivially mark every customer as exhausted.
- **6.1** — `<> 'PAID'` instead of `= 'UNPAID'`, so any other non-paid status
  is included automatically.
- **6.2** — uses `SUM(COUNT(*)) OVER (PARTITION BY tariff)` to compute per-tariff
  percentages in a single pass without a self-join.

## 🧹 Stop / reset

```bash
docker compose down            # stop and remove the container
docker compose down -v         # also wipe the data volume (start fresh next run)
```

---

## Original brief (from i2i Systems)

You take on the role of a developer at **i2i Systems**, fulfilling team requests
through database operations against telecom CSV data.

**Operational requirements**

1. **Oracle XE Setup** — Run Oracle XE in Docker, accessible from local.
2. **DBeaver Installation** — Connect to the local Oracle XE.
3. **Data Import** — Design tables and import the provided `.csv` data.
4. **Bonus** — Provide `docker-compose.yml` and configure automated DB seeding.

**Functional requirements** (each query needs ≥ 3 sentences of explanation):

1. Tariff-based queries — *Kobiye Destek* customers; newest customer.
2. Tariff distribution across customers.
3. Signup analysis — earliest customers (IDs may not match order); city distribution.
4. Missing monthly records — find them; city distribution.
5. Usage — ≥ 75% data usage; full exhaustion (data + minutes + SMS).
6. Payment — unpaid fees; status distribution per tariff.
