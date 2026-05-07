#!/usr/bin/env bash
# 01_run_setup.sh
# Runs once on first DB init. Connects to the XEPDB1 pluggable DB explicitly
# (rather than relying on the gvenzl APP_USER/ subfolder convention which
# behaves differently across image versions) and seeds the project schema.
#
# Order:
#   1. As SYSTEM: create the CSV directory object and grant TELCO read access
#   2. As TELCO:  create tables, FKs, indexes (TABLE_CREATION_SCRIPTS.sql)
#   3. As TELCO:  import the three CSVs via external tables
#
# Author: Ahmet Yıldırım

set -e

PDB_USER_CONN="TELCO/${APP_USER_PASSWORD:-telco_pass}@localhost:1521/XEPDB1"
PDB_SYS_CONN="SYSTEM/${ORACLE_PASSWORD:-oracle_root_pass}@localhost:1521/XEPDB1"

echo "==> [setup 1/3] granting CSV directory access to TELCO"
sqlplus -s -L "$PDB_SYS_CONN" <<'SQL'
WHENEVER SQLERROR EXIT SQL.SQLCODE
CREATE OR REPLACE DIRECTORY CSV_DIR AS '/opt/csv';
GRANT READ, WRITE ON DIRECTORY CSV_DIR TO TELCO;
EXIT
SQL

echo "==> [setup 2/3] creating tables in TELCO schema"
sqlplus -s -L "$PDB_USER_CONN" @/opt/init/TABLE_CREATION_SCRIPTS.sql

echo "==> [setup 3/3] loading CSV data via external tables"
sqlplus -s -L "$PDB_USER_CONN" @/opt/init/02_load_csv_data.sql

echo "==> [setup done]"
