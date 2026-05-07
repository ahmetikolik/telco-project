--------------------------------------------------------------------------------
-- Telco Project - SQL Solutions (Oracle XE)
-- Author: Ahmet Yıldırım
--
-- Each query is preceded by a comment block of at least 3 sentences explaining
-- the approach, the joins/filters used, and any edge cases I considered.
--------------------------------------------------------------------------------


--==============================================================================
-- 1. Tariff-Based Customer Queries
--==============================================================================

--------------------------------------------------------------------------------
-- 1.1 - List the customers subscribed to the 'Kobiye Destek' tariff.
--
-- I join CUSTOMERS to TARIFFS so I can filter by tariff NAME instead of
-- hard-coding the TARIFF_ID — that way the query keeps working even if the
-- tariff IDs are reassigned in the future. I select the columns a non-technical
-- requester would actually want to see (id, name, city, signup date) and order
-- alphabetically by name to make the output easy to scan.
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
-- 1.2 - Find the newest customer who subscribed to the 'Kobiye Destek' tariff.
--
-- "Newest" here means the most recent SIGNUP_DATE, not the highest CUSTOMER_ID,
-- because IDs and signup order are not guaranteed to match (see the hint in 3.1).
-- I order DESC by SIGNUP_DATE and use FETCH FIRST 1 ROW WITH TIES so that if
-- two customers signed up on the exact same most-recent day, both are returned.
--------------------------------------------------------------------------------
SELECT  c.CUSTOMER_ID,
        c.NAME,
        c.CITY,
        c.SIGNUP_DATE
FROM    CUSTOMERS c
JOIN    TARIFFS   t ON c.TARIFF_ID = t.TARIFF_ID
WHERE   t.NAME = 'Kobiye Destek'
ORDER BY c.SIGNUP_DATE DESC
FETCH FIRST 1 ROW WITH TIES;


--==============================================================================
-- 2. Tariff Distribution
--==============================================================================

--------------------------------------------------------------------------------
-- 2.1 - Distribution of tariffs among the customers.
--
-- I group by tariff name to count how many customers each tariff has, and I
-- LEFT JOIN from TARIFFS so that a tariff with zero customers still appears
-- in the output as 0 (an INNER JOIN would silently hide it). I also include
-- a percentage column to make the distribution easier to read at a glance.
--------------------------------------------------------------------------------
SELECT  t.TARIFF_ID,
        t.NAME                                AS TARIFF_NAME,
        COUNT(c.CUSTOMER_ID)                  AS CUSTOMER_COUNT,
        ROUND(
            COUNT(c.CUSTOMER_ID) * 100.0
            / NULLIF((SELECT COUNT(*) FROM CUSTOMERS), 0),
            2
        )                                     AS PERCENTAGE
FROM    TARIFFS    t
LEFT JOIN CUSTOMERS c ON c.TARIFF_ID = t.TARIFF_ID
GROUP BY t.TARIFF_ID, t.NAME
ORDER BY CUSTOMER_COUNT DESC;


--==============================================================================
-- 3. Customer Signup Analysis
--==============================================================================

--------------------------------------------------------------------------------
-- 3.1 - Identify the earliest customers to sign up.
--
-- The hint says CUSTOMER_ID is not necessarily aligned with signup order, so
-- I look at the actual SIGNUP_DATE column. I find the minimum date in a
-- subquery and return everyone who signed up on that exact date — there can
-- be more than one, so this handles ties without losing any of them.
--------------------------------------------------------------------------------
SELECT  c.CUSTOMER_ID,
        c.NAME,
        c.CITY,
        c.SIGNUP_DATE
FROM    CUSTOMERS c
WHERE   c.SIGNUP_DATE = (SELECT MIN(SIGNUP_DATE) FROM CUSTOMERS)
ORDER BY c.CUSTOMER_ID;


--------------------------------------------------------------------------------
-- 3.2 - Distribution of these earliest customers across cities.
--
-- I reuse the same "earliest signup date" filter and group by city to get
-- counts per city. The HAVING clause is not needed here because every grouped
-- city has at least one row by definition. I order by count descending so the
-- most populated city for the earliest cohort comes first.
--------------------------------------------------------------------------------
SELECT  c.CITY,
        COUNT(*) AS CUSTOMER_COUNT
FROM    CUSTOMERS c
WHERE   c.SIGNUP_DATE = (SELECT MIN(SIGNUP_DATE) FROM CUSTOMERS)
GROUP BY c.CITY
ORDER BY CUSTOMER_COUNT DESC, c.CITY;


--==============================================================================
-- 4. Missing Monthly Records
--==============================================================================

--------------------------------------------------------------------------------
-- 4.1 - Customers whose monthly record is missing.
--
-- An "anti-join" pattern fits this perfectly: LEFT JOIN MONTHLY_STATS to
-- CUSTOMERS, then keep only rows where the right side is NULL — those are the
-- customers without a matching monthly stats row. I picked LEFT JOIN over
-- NOT EXISTS because both perform similarly here and LEFT JOIN reads more
-- naturally next to the other queries in this file.
--------------------------------------------------------------------------------
SELECT  c.CUSTOMER_ID,
        c.NAME,
        c.CITY,
        c.SIGNUP_DATE
FROM    CUSTOMERS     c
LEFT JOIN MONTHLY_STATS m ON c.CUSTOMER_ID = m.CUSTOMER_ID
WHERE   m.CUSTOMER_ID IS NULL
ORDER BY c.CUSTOMER_ID;


--------------------------------------------------------------------------------
-- 4.2 - Distribution of the missing customers across cities.
--
-- Same anti-join as 4.1, this time grouped by city to count how many missing
-- customers each city has. I order by count desc to bring the most affected
-- cities to the top, which is what an ops team would want to see first.
-- Cities with no missing customers do not appear because they contribute 0
-- rows to the join — that is the correct behavior for "missing-only" stats.
--------------------------------------------------------------------------------
SELECT  c.CITY,
        COUNT(*) AS MISSING_COUNT
FROM    CUSTOMERS     c
LEFT JOIN MONTHLY_STATS m ON c.CUSTOMER_ID = m.CUSTOMER_ID
WHERE   m.CUSTOMER_ID IS NULL
GROUP BY c.CITY
ORDER BY MISSING_COUNT DESC, c.CITY;


--==============================================================================
-- 5. Usage Analysis
--==============================================================================

--------------------------------------------------------------------------------
-- 5.1 - Customers who used >= 75% of their data limit.
--
-- I join MONTHLY_STATS to CUSTOMERS to TARIFFS, because the data limit lives
-- on the tariff, not on the customer. I exclude rows where DATA_LIMIT = 0,
-- because dividing by zero is undefined and a tariff with no data allowance
-- (e.g. "Kurumsal SMS") cannot mathematically reach 75%. The threshold is
-- expressed as DATA_USAGE >= 0.75 * DATA_LIMIT to avoid the explicit division.
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
-- 5.2 - Customers who exhausted ALL their package limits (data, minutes, SMS).
--
-- "Exhausted" means usage has reached or exceeded the limit on every dimension.
-- I include a "limit > 0" guard for each dimension so a tariff that includes
-- 0 of something (like Kurumsal SMS with 0 data) doesn't count as "exhausted"
-- the moment it hits 0. A customer must be capped on data AND minutes AND sms
-- against the actual non-zero limits in their tariff for the row to qualify.
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
-- 6. Payment Analysis
--==============================================================================

--------------------------------------------------------------------------------
-- 6.1 - Customers with unpaid fees.
--
-- I join CUSTOMERS to MONTHLY_STATS and filter where the payment status is
-- not "PAID". I used "<> 'PAID'" rather than "= 'UNPAID'" so the query also
-- catches any other non-paid statuses that might exist (e.g. PENDING, OVERDUE).
-- Including the tariff name makes the result more useful for follow-up actions.
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
-- 6.2 - Distribution of all payment statuses across the different tariffs.
--
-- I join the three tables and group by tariff name and payment status to get
-- a 2-D distribution: how many monthly records exist for each (tariff, status)
-- combination. I include a percentage of the tariff total via a window function
-- so it's easy to see, for example, "what % of Kobiye Destek records are UNPAID".
--------------------------------------------------------------------------------
SELECT  t.NAME                                       AS TARIFF_NAME,
        m.PAYMENT_STATUS,
        COUNT(*)                                     AS RECORD_COUNT,
        ROUND(
            COUNT(*) * 100.0
            / SUM(COUNT(*)) OVER (PARTITION BY t.NAME),
            2
        )                                            AS PERCENT_OF_TARIFF
FROM    MONTHLY_STATS m
JOIN    CUSTOMERS     c ON m.CUSTOMER_ID = c.CUSTOMER_ID
JOIN    TARIFFS       t ON c.TARIFF_ID   = t.TARIFF_ID
GROUP BY t.NAME, m.PAYMENT_STATUS
ORDER BY t.NAME, RECORD_COUNT DESC;
