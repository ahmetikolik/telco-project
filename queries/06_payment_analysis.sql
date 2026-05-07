--==============================================================================
-- Section 6 — Payment Analysis
-- Author: Ahmet Yıldırım
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
