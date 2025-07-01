#!/bin/bash
set -e

# These variables should be passed as environment variables to the PostgreSQL container
# via docker-compose.yml or an .env file.
# Example:
# environment:
#   DB_NAME: lnfootdb
#   DB_USERNAME: lnfootuser
#   API_DB_PASSWORD: your_secure_password_here

# --- Add a waiting mechanism for PostgreSQL to be ready ---
echo "Waiting for PostgreSQL to become available..."
until psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" -c '\q'; do
  >&2 echo "PostgreSQL is unavailable - sleeping"
  sleep 1
done
echo "PostgreSQL is up and running, continuing with setup."
# --- End of waiting mechanism ---

echo "Ensuring database '$DB_NAME' and user '$DB_USERNAME' exist..."

# Connect to the default 'postgres' database (which always exists) as the superuser,
# and execute the SQL commands.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
    -- Create a new database for your Spring Boot application if it doesn't already exist
    -- This uses a DO block for robust compatibility with conditional logic
    DO
    \$do\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME') THEN
            CREATE DATABASE "$DB_NAME";
        END IF;
    END
    \$do\$;

    -- Create a new user for your Spring Boot application if it doesn't already exist
    DO
    \$do\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USERNAME') THEN
            CREATE USER "$DB_USERNAME" WITH PASSWORD '$DB_PASSWORD';
        END IF;
    END
    \$do\$;

    -- Grant all privileges on the new database to the new user
    GRANT ALL PRIVILEGES ON DATABASE "$DB_NAME" TO "$DB_USERNAME";
EOSQL

echo "Configuring schema privileges for '$DB_NAME'..."

# Connect to the newly created database and grant schema privileges
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$DB_NAME" <<-EOSQL
    GRANT ALL PRIVILEGES ON SCHEMA lnfoot_api TO "$DB_USERNAME";
    ALTER DEFAULT PRIVILEGES IN SCHEMA lnfoot_api GRANT ALL PRIVILEGES ON TABLES TO "$DB_USERNAME";
    ALTER DEFAULT PRIVILEGES IN SCHEMA lnfoot_api GRANT ALL PRIVILEGES ON SEQUENCES TO "$DB_USERNAME";
    ALTER DEFAULT PRIVILEGES IN SCHEMA lnfoot_api GRANT ALL PRIVILEGES ON FUNCTIONS TO "$DB_USERNAME";
    ALTER DEFAULT PRIVILEGES IN SCHEMA lnfoot_api GRANT ALL PRIVILEGES ON TYPES TO "$DB_USERNAME";
EOSQL


# Connect to the newly created database and grant schema privileges
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$DB_NAME" <<-EOSQL
    GRANT ALL PRIVILEGES ON SCHEMA lnfoot_web TO "$DB_USERNAME";
    ALTER DEFAULT PRIVILEGES IN SCHEMA lnfoot_web GRANT ALL PRIVILEGES ON TABLES TO "$DB_USERNAME";
    ALTER DEFAULT PRIVILEGES IN SCHEMA lnfoot_web GRANT ALL PRIVILEGES ON SEQUENCES TO "$DB_USERNAME";
    ALTER DEFAULT PRIVILEGES IN SCHEMA lnfoot_web GRANT ALL PRIVILEGES ON FUNCTIONS TO "$DB_USERNAME";
    ALTER DEFAULT PRIVILEGES IN SCHEMA lnfoot_web GRANT ALL PRIVILEGES ON TYPES TO "$DB_USERNAME";
EOSQL

echo "Database and user setup (or update) complete for '$DB_NAME'."