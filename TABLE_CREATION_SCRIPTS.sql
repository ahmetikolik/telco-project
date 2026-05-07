--------------------------------------------------------------------------------
-- Telco Project - Table Creation Scripts (Oracle XE)
-- Author: Ahmet Yıldırım
--
-- Run order: TARIFFS first, then CUSTOMERS (FK -> TARIFFS),
-- then MONTHLY_STATS (FK -> CUSTOMERS).
-- After running this file, import the three CSVs in DBeaver:
--   TARIFFS.csv         -> TARIFFS
--   CUSTOMERS.csv       -> CUSTOMERS  (date format: DD/MM/YYYY)
--   MONTHLY_STATS.csv   -> MONTHLY_STATS
--------------------------------------------------------------------------------

-- Drop in reverse order if re-running (ignore errors on first run)
BEGIN EXECUTE IMMEDIATE 'DROP TABLE MONTHLY_STATS CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE CUSTOMERS CASCADE CONSTRAINTS';     EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE TARIFFS CASCADE CONSTRAINTS';       EXCEPTION WHEN OTHERS THEN NULL; END;
/

--------------------------------------------------------------------------------
-- TARIFFS
-- Reference table: 4 rows, one per tariff plan.
-- DATA_LIMIT is in MB; MINUTE_LIMIT and SMS_LIMIT are in count.
-- A 0 limit means "not included in the plan" (e.g. Kurumsal SMS has no data/minutes).
--------------------------------------------------------------------------------
CREATE TABLE TARIFFS (
    TARIFF_ID     NUMBER          NOT NULL,
    NAME          VARCHAR2(100)   NOT NULL,
    MONTHLY_FEE   NUMBER(10, 2)   NOT NULL,
    DATA_LIMIT    NUMBER          NOT NULL,
    MINUTE_LIMIT  NUMBER          NOT NULL,
    SMS_LIMIT     NUMBER          NOT NULL,
    CONSTRAINT PK_TARIFFS         PRIMARY KEY (TARIFF_ID),
    CONSTRAINT CK_TARIFFS_FEE     CHECK (MONTHLY_FEE  >= 0),
    CONSTRAINT CK_TARIFFS_DATA    CHECK (DATA_LIMIT   >= 0),
    CONSTRAINT CK_TARIFFS_MIN     CHECK (MINUTE_LIMIT >= 0),
    CONSTRAINT CK_TARIFFS_SMS     CHECK (SMS_LIMIT    >= 0)
);

--------------------------------------------------------------------------------
-- CUSTOMERS
-- Each customer is on exactly one tariff (FK to TARIFFS).
-- SIGNUP_DATE is a real DATE so we can sort and filter by signup chronologically.
--------------------------------------------------------------------------------
CREATE TABLE CUSTOMERS (
    CUSTOMER_ID   NUMBER          NOT NULL,
    NAME          VARCHAR2(100)   NOT NULL,
    CITY          VARCHAR2(100),
    SIGNUP_DATE   DATE            NOT NULL,
    TARIFF_ID     NUMBER          NOT NULL,
    CONSTRAINT PK_CUSTOMERS       PRIMARY KEY (CUSTOMER_ID),
    CONSTRAINT FK_CUSTOMERS_TAR   FOREIGN KEY (TARIFF_ID) REFERENCES TARIFFS (TARIFF_ID)
);

--------------------------------------------------------------------------------
-- MONTHLY_STATS
-- One row per customer per month (this dataset is "this month" only).
-- A customer with NO row in MONTHLY_STATS is a "missing record" (Q4).
-- USAGE values are how much of the tariff allowance has been consumed.
--------------------------------------------------------------------------------
CREATE TABLE MONTHLY_STATS (
    ID              NUMBER        NOT NULL,
    CUSTOMER_ID     NUMBER        NOT NULL,
    DATA_USAGE      NUMBER(12, 2) DEFAULT 0 NOT NULL,
    MINUTE_USAGE    NUMBER        DEFAULT 0 NOT NULL,
    SMS_USAGE       NUMBER        DEFAULT 0 NOT NULL,
    PAYMENT_STATUS  VARCHAR2(20)  NOT NULL,
    CONSTRAINT PK_MONTHLY_STATS   PRIMARY KEY (ID),
    CONSTRAINT FK_MONTHLY_CUST    FOREIGN KEY (CUSTOMER_ID) REFERENCES CUSTOMERS (CUSTOMER_ID),
    CONSTRAINT CK_DATA_USAGE      CHECK (DATA_USAGE   >= 0),
    CONSTRAINT CK_MIN_USAGE       CHECK (MINUTE_USAGE >= 0),
    CONSTRAINT CK_SMS_USAGE       CHECK (SMS_USAGE    >= 0)
);

--------------------------------------------------------------------------------
-- Indexes
-- These cover the common access paths of the queries in SOLUTIONS.sql:
--   - filtering customers by tariff, city, or signup_date
--   - looking up monthly stats by customer
--   - filtering monthly stats by payment status
--------------------------------------------------------------------------------
CREATE INDEX IDX_CUSTOMERS_TARIFF   ON CUSTOMERS    (TARIFF_ID);
CREATE INDEX IDX_CUSTOMERS_CITY     ON CUSTOMERS    (CITY);
CREATE INDEX IDX_CUSTOMERS_SIGNUP   ON CUSTOMERS    (SIGNUP_DATE);
CREATE INDEX IDX_MONTHLY_CUSTOMER   ON MONTHLY_STATS(CUSTOMER_ID);
CREATE INDEX IDX_MONTHLY_PAYMENT    ON MONTHLY_STATS(PAYMENT_STATUS);

COMMIT;
