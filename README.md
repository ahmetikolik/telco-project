# Telco Project

> **Submission by Ahmet Yıldırım** — Yıldız Technical University, Computer Engineering
> i2i Systems Summer Internship 2026 application.

This repo contains my answers to the i2i Systems Telco SQL project: schema design,
data import, and 12 SQL queries against an Oracle XE database running in Docker.

## 📁 What's in this repo

| File | What it is |
| --- | --- |
| `TABLE_CREATION_SCRIPTS.sql` | Schema: 3 tables, primary keys, foreign keys, check constraints, indexes |
| `SOLUTIONS.sql` | All 12 SQL query answers, each with an explanatory comment block |
| `docker-compose.yml` | Spins up Oracle XE locally and auto-runs the table creation script |
| `TARIFFS.csv`, `CUSTOMERS.csv`, `MONTHLY_STATS.csv` | The provided source data |

## 🛠️ How to reproduce my setup

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [DBeaver](https://dbeaver.io/) (or any Oracle-compatible SQL client)

### 1. Start the database

```bash
docker compose up -d
```

The first start takes ~2 minutes while the Oracle image initialises and runs my
table creation script automatically.

You can watch the progress with:

```bash
docker compose logs -f oracle-xe
```

When you see `DATABASE IS READY TO USE!`, the DB is up.

### 2. Connect with DBeaver

In DBeaver: **Database → New Database Connection → Oracle**, then:

| Field | Value |
| --- | --- |
| Host | `localhost` |
| Port | `1521` |
| Database / Service | `XEPDB1` |
| Username | `TELCO` |
| Password | `telco_pass` |

Hit **Test Connection** — you should be in.

### 3. Import the CSVs

The tables are already created (the Docker image ran `TABLE_CREATION_SCRIPTS.sql`
on startup). Now load the data via DBeaver:

For each CSV (`TARIFFS.csv`, `CUSTOMERS.csv`, `MONTHLY_STATS.csv`):

1. Right-click the matching table → **Import Data**.
2. Source: **CSV** → pick the file.
3. Map the columns (defaults usually match).
4. **For `CUSTOMERS.csv`**, set the date format to **`DD/MM/YYYY`** so `SIGNUP_DATE` parses correctly.
5. Run the import.

> **Order matters**: import `TARIFFS` first, then `CUSTOMERS`, then `MONTHLY_STATS` — the foreign keys require the parent rows to exist.

### 4. Run the queries

Open `SOLUTIONS.sql` in DBeaver and execute each block. Each query has a comment
block above it explaining what it does and why.

## 🧠 Schema decisions

- **DATE for SIGNUP_DATE** instead of VARCHAR — lets the database sort and filter
  chronologically without string parsing each time, and the "earliest customer"
  query (3.1) needs real date semantics.
- **Foreign keys** between CUSTOMERS → TARIFFS and MONTHLY_STATS → CUSTOMERS so
  the database itself enforces referential integrity. If a CSV row references
  a non-existent tariff or customer, the import fails loudly instead of leaving
  dangling rows behind.
- **CHECK constraints** on all numeric columns (`>= 0`) because negative usage,
  fee or limit values would be data corruption.
- **Indexes** on the columns I actually filter / join on:
  `CUSTOMERS.TARIFF_ID`, `CUSTOMERS.CITY`, `CUSTOMERS.SIGNUP_DATE`,
  `MONTHLY_STATS.CUSTOMER_ID`, `MONTHLY_STATS.PAYMENT_STATUS`.
  No indexes on columns that are never filtered (avoids write overhead).

## 🧠 Query notes

A few highlights — full reasoning is in the comment block above each query:

- **3.1** — "earliest customer" uses `MIN(SIGNUP_DATE)` in a subquery, since the
  hint warns IDs and signup order are not aligned.
- **4.1** — "missing monthly records" uses an anti-join (`LEFT JOIN ... WHERE
  right side IS NULL`) — clean and reads naturally.
- **5.1** — guards against divide-by-zero by excluding tariffs where
  `DATA_LIMIT = 0`.
- **5.2** — only counts a dimension as "exhausted" when the limit is greater
  than zero, so a tariff with 0 SMS doesn't trivially mark every customer
  as having "exhausted" SMS.
- **6.1** — uses `<> 'PAID'` rather than `= 'UNPAID'` so the query catches any
  other non-paid statuses if they exist (PENDING, OVERDUE, etc.).

## 🧹 Stopping the database

```bash
docker compose down          # stop and remove the container
docker compose down -v       # also wipe the data volume
```

---

## Original Project Brief (from i2i Systems)

In this project, you take on the role of a developer at **i2i Systems**, fulfilling
team requests through database operations against telecom data delivered as CSVs.

### Operational Requirements

1. **Oracle XE Setup** — Run Oracle XE in a Docker container, accessible from your local machine.
2. **DBeaver Installation** — Connect to the Oracle XE instance.
3. **Data Import** — Design the necessary tables and import the provided `.csv` data.
4. **Bonus Tasks** — Provide a `docker-compose.yml` and configure automated DB seeding.

### Functional Requirements

Write SQL queries (with comments of at least 3 sentences each) for:

#### 1. Tariff-Based Customer Queries
- **1.1** List customers subscribed to the `Kobiye Destek` tariff.
- **1.2** Newest customer of that tariff.

#### 2. Tariff Distribution
- **2.1** Distribution of tariffs across customers.

#### 3. Customer Signup Analysis
- **3.1** Earliest customers to sign up *(IDs may not match signup order)*.
- **3.2** Distribution of those earliest customers across cities.

#### 4. Missing Monthly Records
- **4.1** Customers with missing monthly stats.
- **4.2** Distribution of those missing customers across cities.

#### 5. Usage Analysis
- **5.1** Customers using ≥ 75% of their data limit.
- **5.2** Customers who have exhausted ALL package limits (data, minutes, SMS).

#### 6. Payment Analysis
- **6.1** Customers with unpaid fees.
- **6.2** Distribution of payment statuses across tariffs.
