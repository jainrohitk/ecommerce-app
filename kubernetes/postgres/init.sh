#!/bin/sh
set -eu
psql -v ON_ERROR_STOP=1 -U postgres -d astronomy_db -v catalog_password="$CATALOG_PASSWORD" <<'SQL'
CREATE ROLE catalog_reader LOGIN PASSWORD :'catalog_password';
REVOKE CONNECT ON DATABASE astronomy_db FROM PUBLIC;
GRANT CONNECT ON DATABASE astronomy_db TO catalog_reader;
SQL
psql -v ON_ERROR_STOP=1 -U postgres -d astronomy_db -f /bootstrap/schema.sql
