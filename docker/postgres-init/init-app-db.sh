#!/bin/bash
set -e

# These variables should be passed as environment variables to the PostgreSQL container
# via docker-compose.yml or an .env file.
# Example:
# environment:
#   DB_NAME: lnfootdb
#   DB_USERNAME: lnfootuser
#   API_DB_PASSWORD: your_secure_password_here

echo "Ensuring database '$DB_NAME' and user '$DB_USERNAME' exist..."

# Connect to the default 'postgres' database (which always exists) as the superuser,
# and execute the SQL commands.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
    -- Create a new database for your Spring Boot application if it doesn't already exist
    CREATE DATABASE "$DB_NAME" IF NOT EXISTS;

    -- Create a new user for your Spring Boot application if it doesn't already exist
    -- Note: This approach handles the user creation more gracefully on re-runs.
    -- If you need to *update* the password, you'd use ALTER USER.
    DO
    \$do\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USERNAME') THEN
            CREATE USER "$DB_USERNAME" WITH PASSWORD '$API_DB_PASSWORD';
        END IF;
    END
    \$do\$;

    -- Grant all privileges on the new database to the new user
    -- This is idempotent; re-running has no effect if privileges are already granted.
    GRANT ALL PRIVILEGES ON DATABASE "$DB_NAME" TO "$DB_USERNAME";
EOSQL

echo "Configuring schema privileges for '$DB_NAME'..."

# Connect to the newly created database and grant schema privileges
# These are generally idempotent.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$DB_NAME" <<-EOSQL
    GRANT ALL PRIVILEGES ON SCHEMA public TO "$DB_USERNAME";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO "$DB_USERNAME";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO "$DB_USERNAME";
    -- You might also want to grant usage on types and functions if your schema uses them
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON FUNCTIONS TO "$DB_USERNAME";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TYPES TO "$DB_USERNAME";
EOSQL

echo "Database and user setup (or update) complete for '$DB_NAME'."