--==============================================================================
-- Section 1 — Tariff-Based Customer Queries
-- Author: Ahmet Yıldırım
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
-- needs to change. ROW_NUMBER also makes the intent explicit (we are looking
-- at chronological order, not row order), which I prefer for readability.
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
