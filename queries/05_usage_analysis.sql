--==============================================================================
-- Section 5 — Usage Analysis
-- Author: Ahmet Yıldırım
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
