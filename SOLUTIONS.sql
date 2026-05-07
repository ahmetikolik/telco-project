--==============================================================================
-- Telco Project — Combined Solutions File
-- Author: Ahmet Yıldırım
--
-- This file contains the same 12 SQL answers that live in the per-section
-- files inside `queries/`. I keep both because the i2i brief specifically
-- asks for a single SOLUTIONS.sql, while the per-section split makes it
-- easier to run / review individual sections during development.
--
-- Each query has a comment block (>= 3 sentences) explaining the approach.
--==============================================================================


--==============================================================================
-- Section 1 — Tariff-Based Customer Queries
--==============================================================================

--------------------------------------------------------------------------------
-- 1.1  Customers subscribed to the 'Kobiye Destek' tariff.
--
-- I filter by tariff NAME instead of hard-coding TARIFF_ID, which keeps the
-- query stable if the IDs are ever reassigned. The IDX_CUSTOMERS_TARIFF index
-- handles the lookup once Oracle resolves the tariff id from the join. I sort
-- alphabetically by customer name so the output is easy to scan by hand.
--------------------------------------------------------------------------------
SELECT  c.CUSTOMER_ID,
        c.NAME,
        c.CITY,
        c.SIGNUP_DATE
FROM    CUSTOMERS c
JOIN    TARIFFS   t ON c.TARIFF_ID = t.TARIFF_ID
WHERE   t.NAME = 'Kobiye Destek'
ORDER BY c.NAME;


--------------------------------------------------------------------------------
-- 1.2  Newest customer on the 'Kobiye Destek' tariff.
--
-- I use ROW_NUMBER() OVER (ORDER BY signup_date DESC) inside a CTE, then take
-- the row whose number is 1. This pattern is easy to extend later if the team
-- asks for "the newest 5" or "the newest per city" — only the WHERE clause
-- needs to change. ROW_NUMBER also makes the intent explicit (chronological
-- order, not row order), which I prefer for readability.
--------------------------------------------------------------------------------
WITH ranked AS (
    SELECT  c.CUSTOMER_ID,
            c.NAME,
            c.CITY,
            c.SIGNUP_DATE,
            ROW_NUMBER() OVER (ORDER BY c.SIGNUP_DATE DESC) AS rn
    FROM    CUSTOMERS c
    JOIN    TARIFFS   t ON c.TARIFF_ID = t.TARIFF_ID
    WHERE   t.NAME = 'Kobiye Destek'
)
SELECT CUSTOMER_ID, NAME, CITY, SIGNUP_DATE
FROM   ranked
WHERE  rn = 1;


--==============================================================================
-- Section 2 — Tariff Distribution
--==============================================================================

--------------------------------------------------------------------------------
-- 2.1  Distribution of tariffs across the customer base.
--
-- I LEFT JOIN from TARIFFS so that a tariff with zero subscribers still shows
-- up as 0 — an INNER JOIN would silently drop it and a stakeholder reading the
-- output might miss the fact that a tariff is unpopular. The percentage column
-- divides by the total customer count fetched from a scalar subquery, which
-- runs only once thanks to Oracle's caching of constant subqueries.
--------------------------------------------------------------------------------
SELECT  t.TARIFF_ID,
        t.NAME                                              AS TARIFF_NAME,
        COUNT(c.CUSTOMER_ID)                                AS CUSTOMER_COUNT,
        ROUND(
            COUNT(c.CUSTOMER_ID) * 100.0
            / NULLIF((SELECT COUNT(*) FROM CUSTOMERS), 0),
            2
        )                                                   AS PERCENTAGE
FROM    TARIFFS    t
LEFT JOIN CUSTOMERS c ON c.TARIFF_ID = t.TARIFF_ID
GROUP BY t.TARIFF_ID, t.NAME
ORDER BY CUSTOMER_COUNT DESC;


--==============================================================================
-- Section 3 — Customer Signup Analysis
--==============================================================================

--------------------------------------------------------------------------------
-- 3.1  Earliest customers to sign up.
--
-- The brief warns that CUSTOMER_ID order does not match signup order, so I
-- compute MIN(SIGNUP_DATE) inside a CTE and then return everyone matching it.
-- Using a CTE keeps the date computation in one place and reads naturally —
-- "find the min, then keep customers on that day". If two or more customers
-- share the earliest date, all of them are returned (no arbitrary tiebreak).
--------------------------------------------------------------------------------
WITH first_day AS (
    SELECT MIN(SIGNUP_DATE) AS first_signup_date
    FROM   CUSTOMERS
)
SELECT  c.CUSTOMER_ID,
        c.NAME,
        c.CITY,
        c.SIGNUP_DATE
FROM    CUSTOMERS c, first_day fd
WHERE   c.SIGNUP_DATE = fd.first_signup_date
ORDER BY c.CUSTOMER_ID;


--------------------------------------------------------------------------------
-- 3.2  Distribution of those earliest customers across cities.
--
-- I reuse the same "first signup date" filter and group by CITY to get a
-- per-city headcount. I order by count DESC so the most-represented city comes
-- first, then by city name as a tiebreaker for deterministic output.
-- Cities that have no customers in the earliest cohort are not in the result
-- at all — they would be a separate ("empty") report if anyone asked for it.
--------------------------------------------------------------------------------
WITH first_day AS (
    SELECT MIN(SIGNUP_DATE) AS first_signup_date
    FROM   CUSTOMERS
)
SELECT  c.CITY,
        COUNT(*) AS CUSTOMER_COUNT
FROM    CUSTOMERS c, first_day fd
WHERE   c.SIGNUP_DATE = fd.first_signup_date
GROUP BY c.CITY
ORDER BY CUSTOMER_COUNT DESC, c.CITY;


--==============================================================================
-- Section 4 — Missing Monthly Records
--==============================================================================

--------------------------------------------------------------------------------
-- 4.1  Customers whose monthly stats row is missing.
--
-- I use NOT EXISTS with a correlated subquery — this expresses "give me each
-- customer for whom no monthly_stats row exists" almost word-for-word, which
-- I find clearer than the LEFT JOIN-with-null pattern for an anti-join. Oracle
-- internally optimizes both the same way (anti-join), so the choice here is
-- purely about readability rather than performance.
--------------------------------------------------------------------------------
SELECT  c.CUSTOMER_ID,
        c.NAME,
        c.CITY,
        c.SIGNUP_DATE
FROM    CUSTOMERS c
WHERE   NOT EXISTS (
            SELECT 1
            FROM   MONTHLY_STATS m
            WHERE  m.CUSTOMER_ID = c.CUSTOMER_ID
        )
ORDER BY c.CUSTOMER_ID;


--------------------------------------------------------------------------------
-- 4.2  Distribution of the missing customers across cities.
--
-- Same anti-join as 4.1, grouped by CITY. I order by count DESC so the most
-- affected cities surface first — that is what an ops/data team would act on.
-- A city with zero missing customers won't appear (it would not contribute
-- a row), which is the correct behaviour for a "missing-only" breakdown.
--------------------------------------------------------------------------------
SELECT  c.CITY,
        COUNT(*) AS MISSING_COUNT
FROM    CUSTOMERS c
WHERE   NOT EXISTS (
            SELECT 1
            FROM   MONTHLY_STATS m
            WHERE  m.CUSTOMER_ID = c.CUSTOMER_ID
        )
GROUP BY c.CITY
ORDER BY MISSING_COUNT DESC, c.CITY;


--==============================================================================
-- Section 5 — Usage Analysis
--==============================================================================

--------------------------------------------------------------------------------
-- 5.1  Customers who used at least 75% of their data limit.
--
-- The data limit lives on the tariff, so I have to join through CUSTOMERS to
-- TARIFFS. I avoid a literal division (DATA_USAGE / DATA_LIMIT >= 0.75) and
-- instead compare DATA_USAGE >= 0.75 * DATA_LIMIT — that side-steps the
-- division-by-zero problem entirely for tariffs whose DATA_LIMIT = 0
-- (e.g. "Kurumsal SMS" has no data allowance and therefore can't qualify).
--------------------------------------------------------------------------------
SELECT  c.CUSTOMER_ID,
        c.NAME,
        c.CITY,
        t.NAME                                                AS TARIFF_NAME,
        m.DATA_USAGE,
        t.DATA_LIMIT,
        ROUND(m.DATA_USAGE * 100.0 / t.DATA_LIMIT, 2)         AS USAGE_PERCENT
FROM    MONTHLY_STATS m
JOIN    CUSTOMERS     c ON m.CUSTOMER_ID = c.CUSTOMER_ID
JOIN    TARIFFS       t ON c.TARIFF_ID   = t.TARIFF_ID
WHERE   t.DATA_LIMIT > 0
  AND   m.DATA_USAGE >= 0.75 * t.DATA_LIMIT
ORDER BY USAGE_PERCENT DESC;


--------------------------------------------------------------------------------
-- 5.2  Customers who exhausted ALL their package limits (data, minutes, SMS).
--
-- A customer counts as "fully exhausted" only when they reached or exceeded
-- the limit on every dimension. I add a ">0" guard for each limit so a tariff
-- that simply does not include data / minutes / sms (limit = 0) doesn't count
-- as "exhausted" by default. The SUM-of-CASE inside a HAVING was tempting,
-- but a straight WHERE is faster and reads better at this scale.
--------------------------------------------------------------------------------
SELECT  c.CUSTOMER_ID,
        c.NAME,
        c.CITY,
        t.NAME            AS TARIFF_NAME,
        m.DATA_USAGE,
        m.MINUTE_USAGE,
        m.SMS_USAGE
FROM    MONTHLY_STATS m
JOIN    CUSTOMERS     c ON m.CUSTOMER_ID = c.CUSTOMER_ID
JOIN    TARIFFS       t ON c.TARIFF_ID   = t.TARIFF_ID
WHERE   t.DATA_LIMIT   > 0 AND m.DATA_USAGE   >= t.DATA_LIMIT
  AND   t.MINUTE_LIMIT > 0 AND m.MINUTE_USAGE >= t.MINUTE_LIMIT
  AND   t.SMS_LIMIT    > 0 AND m.SMS_USAGE    >= t.SMS_LIMIT
ORDER BY c.CUSTOMER_ID;


--==============================================================================
-- Section 6 — Payment Analysis
--==============================================================================

--------------------------------------------------------------------------------
-- 6.1  Customers with unpaid fees.
--
-- I filter on PAYMENT_STATUS <> 'PAID' rather than = 'UNPAID' so the query
-- catches any other non-paid statuses if they ever appear (PENDING, OVERDUE,
-- FAILED, etc.). This is a small "future-proofing" choice — listing customers
-- who still owe money is the goal, not matching one specific spelling. The
-- IDX_MONTHLY_PAYMENT index handles the filter even on larger datasets.
--------------------------------------------------------------------------------
SELECT  c.CUSTOMER_ID,
        c.NAME,
        c.CITY,
        t.NAME              AS TARIFF_NAME,
        m.PAYMENT_STATUS
FROM    MONTHLY_STATS m
JOIN    CUSTOMERS     c ON m.CUSTOMER_ID = c.CUSTOMER_ID
JOIN    TARIFFS       t ON c.TARIFF_ID   = t.TARIFF_ID
WHERE   m.PAYMENT_STATUS <> 'PAID'
ORDER BY c.CUSTOMER_ID;


--------------------------------------------------------------------------------
-- 6.2  Distribution of payment statuses across tariffs.
--
-- I group by tariff name and payment status to get a 2-D distribution: how
-- many monthly records exist for each (tariff, status) pair. The window
-- function SUM(COUNT(*)) OVER (PARTITION BY t.NAME) gives the total per
-- tariff, which I divide into to produce a per-tariff percentage — that
-- answers questions like "what % of Kobiye Destek records are UNPAID".
--------------------------------------------------------------------------------
SELECT  t.NAME                                          AS TARIFF_NAME,
        m.PAYMENT_STATUS,
        COUNT(*)                                        AS RECORD_COUNT,
        ROUND(
            COUNT(*) * 100.0
            / SUM(COUNT(*)) OVER (PARTITION BY t.NAME),
            2
        )                                               AS PERCENT_OF_TARIFF
FROM    MONTHLY_STATS m
JOIN    CUSTOMERS     c ON m.CUSTOMER_ID = c.CUSTOMER_ID
JOIN    TARIFFS       t ON c.TARIFF_ID   = t.TARIFF_ID
GROUP BY t.NAME, m.PAYMENT_STATUS
ORDER BY t.NAME, RECORD_COUNT DESC;
