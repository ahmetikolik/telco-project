--==============================================================================
-- Section 2 — Tariff Distribution
-- Author: Ahmet Yıldırım
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
