--==============================================================================
-- Section 4 — Missing Monthly Records
-- Author: Ahmet Yıldırım
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
