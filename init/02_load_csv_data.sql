--------------------------------------------------------------------------------
-- Auto-load CSV data on container init.
-- Runs after 01_tables.sql via the docker-compose volume mount, as TELCO.
--
-- The trick: define the three CSVs as Oracle EXTERNAL TABLES (file-based, read
-- only), then INSERT ... SELECT into the real tables, then drop the externals.
-- The CSVs are mounted at /opt/csv/ by docker-compose.
-- Author: Ahmet Yıldırım
--------------------------------------------------------------------------------

-- The CSV_DIR directory object is created by the setup shell script (running
-- as SYSTEM, since CREATE DIRECTORY needs SYS-level privileges) and READ
-- access on it is granted to TELCO before this script runs.

--------------------------------------------------------------------------------
-- 2a. TARIFFS: external table -> real table
--------------------------------------------------------------------------------
CREATE TABLE EXT_TARIFFS (
    TARIFF_ID     NUMBER,
    NAME          VARCHAR2(100),
    MONTHLY_FEE   NUMBER(10, 2),
    DATA_LIMIT    NUMBER,
    MINUTE_LIMIT  NUMBER,
    SMS_LIMIT     NUMBER
)
ORGANIZATION EXTERNAL (
    TYPE ORACLE_LOADER
    DEFAULT DIRECTORY CSV_DIR
    ACCESS PARAMETERS (
        RECORDS DELIMITED BY NEWLINE
        SKIP 1
        CHARACTERSET 'AL32UTF8'
        NOLOGFILE
        NOBADFILE
        NODISCARDFILE
        FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
        MISSING FIELD VALUES ARE NULL
    )
    LOCATION ('TARIFFS.csv')
)
REJECT LIMIT UNLIMITED;

INSERT INTO TARIFFS SELECT * FROM EXT_TARIFFS;
DROP TABLE EXT_TARIFFS;

--------------------------------------------------------------------------------
-- 2b. CUSTOMERS: external table -> real table
--     Date format DD/MM/YYYY parsed via TO_DATE on insert.
--------------------------------------------------------------------------------
CREATE TABLE EXT_CUSTOMERS (
    CUSTOMER_ID   NUMBER,
    NAME          VARCHAR2(100),
    CITY          VARCHAR2(100),
    SIGNUP_DATE_S VARCHAR2(20),
    TARIFF_ID     NUMBER
)
ORGANIZATION EXTERNAL (
    TYPE ORACLE_LOADER
    DEFAULT DIRECTORY CSV_DIR
    ACCESS PARAMETERS (
        RECORDS DELIMITED BY NEWLINE
        SKIP 1
        CHARACTERSET 'AL32UTF8'
        NOLOGFILE
        NOBADFILE
        NODISCARDFILE
        FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
        MISSING FIELD VALUES ARE NULL (
            CUSTOMER_ID   CHAR(20),
            NAME          CHAR(100),
            CITY          CHAR(100),
            SIGNUP_DATE_S CHAR(20),
            TARIFF_ID     CHAR(20)
        )
    )
    LOCATION ('CUSTOMERS.csv')
)
REJECT LIMIT UNLIMITED;

INSERT INTO CUSTOMERS (CUSTOMER_ID, NAME, CITY, SIGNUP_DATE, TARIFF_ID)
SELECT CUSTOMER_ID, NAME, CITY, TO_DATE(SIGNUP_DATE_S, 'DD/MM/YYYY'), TARIFF_ID
FROM   EXT_CUSTOMERS;

DROP TABLE EXT_CUSTOMERS;

--------------------------------------------------------------------------------
-- 2c. MONTHLY_STATS: external table -> real table
--------------------------------------------------------------------------------
CREATE TABLE EXT_MONTHLY (
    ID              NUMBER,
    CUSTOMER_ID     NUMBER,
    DATA_USAGE      NUMBER(12, 2),
    MINUTE_USAGE    NUMBER,
    SMS_USAGE       NUMBER,
    PAYMENT_STATUS  VARCHAR2(20)
)
ORGANIZATION EXTERNAL (
    TYPE ORACLE_LOADER
    DEFAULT DIRECTORY CSV_DIR
    ACCESS PARAMETERS (
        RECORDS DELIMITED BY NEWLINE
        SKIP 1
        CHARACTERSET 'AL32UTF8'
        NOLOGFILE
        NOBADFILE
        NODISCARDFILE
        FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
        MISSING FIELD VALUES ARE NULL
    )
    LOCATION ('MONTHLY_STATS.csv')
)
REJECT LIMIT UNLIMITED;

INSERT INTO MONTHLY_STATS SELECT * FROM EXT_MONTHLY;
DROP TABLE EXT_MONTHLY;

COMMIT;
