--==============================================================================
-- Section 3 — Customer Signup Analysis
-- Author: Ahmet Yıldırım
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
