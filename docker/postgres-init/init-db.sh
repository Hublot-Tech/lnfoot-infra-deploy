#!/bin/bash
set -euo pipefail

echo "🔎 Validating required environment variables..."

# First user/db pair
: "${API_DB_NAME:?Environment variable API_DB_NAME is required}"
: "${API_DB_USERNAME:?Environment variable API_DB_USERNAME is required}"
: "${API_DB_PASSWORD:?Environment variable API_DB_PASSWORD is required}"

# Second user/db pair
: "${KEYCLOAK_DB_NAME:?Environment variable KEYCLOAK_DB_NAME is required}"
: "${KEYCLOAK_DB_USERNAME:?Environment variable KEYCLOAK_DB_USERNAME is required}"
: "${KEYCLOAK_DB_PASSWORD:?Environment variable KEYCLOAK_DB_PASSWORD is required}"

# Superuser (from the base image)
: "${POSTGRES_USER:?Environment variable POSTGRES_USER is required}"

echo "✅ Environment variables are set."

echo "⏳ Waiting for PostgreSQL to become available..."
until psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" -c '\q' &> /dev/null; do
  >&2 echo "🚧 PostgreSQL is unavailable - sleeping"
  sleep 1
done
echo "✅ PostgreSQL is up and running."

echo "⚙️ Creating users and databases..."

# Create users and databases
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
    -- API_DB and User1
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$API_DB_USERNAME') THEN
            CREATE USER "$API_DB_USERNAME" WITH PASSWORD '$API_DB_PASSWORD';
        END IF;
    END
    \$\$;

    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '$API_DB_NAME') THEN
            CREATE DATABASE "$API_DB_NAME" OWNER "$API_DB_USERNAME";
        END IF;
    END
    \$\$;

    GRANT ALL PRIVILEGES ON DATABASE "$API_DB_NAME" TO "$API_DB_USERNAME";

    -- KEYCLOAK_DB and User2
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$KEYCLOAK_DB_USERNAME') THEN
            CREATE USER "$KEYCLOAK_DB_USERNAME" WITH PASSWORD '$KEYCLOAK_DB_PASSWORD';
        END IF;
    END
    \$\$;

    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '$KEYCLOAK_DB_NAME') THEN
            CREATE DATABASE "$KEYCLOAK_DB_NAME" OWNER "$KEYCLOAK_DB_USERNAME";
        END IF;
    END
    \$\$;

    GRANT ALL PRIVILEGES ON DATABASE "$KEYCLOAK_DB_NAME" TO "$KEYCLOAK_DB_USERNAME";
EOSQL

echo "✅ Created databases '$API_DB_NAME' and '$KEYCLOAK_DB_NAME' with users '$API_DB_USERNAME' and '$KEYCLOAK_DB_USERNAME'."
