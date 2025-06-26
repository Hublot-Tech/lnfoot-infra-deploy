#!/bin/bash
set -e

# These variables should be passed as environment variables to the PostgreSQL container
# via docker-compose.yml or an .env file.
# Example:
# environment:
#   DB_NAME: lnfootdb
#   DB_USERNAME: lnfootuser
#   API_DB_PASSWORD: your_secure_password_here

echo "Creating database '$DB_NAME' and user '$DB_USERNAME'..."

# Connect to the default 'postgres' database (which always exists) as the superuser,
# and execute the SQL commands.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
    -- Create a new database for your Spring Boot application
    CREATE DATABASE "$DB_NAME";

    -- Create a new user for your Spring Boot application
    CREATE USER "$DB_USERNAME" WITH PASSWORD '$DB_PASSWORD';

    -- Grant all privileges on the new database to the new user
    GRANT ALL PRIVILEGES ON DATABASE "$DB_NAME" TO "$DB_USERNAME";
EOSQL

echo "Configuring schema privileges for '$DB_NAME'..."

# Connect to the newly created database and grant schema privileges
psql -v ON_ERROR_STOP=1 --username "$POSTES_USER" --dbname "$DB_NAME" <<-EOSQL
    GRANT ALL PRIVILEGES ON SCHEMA public TO "$DB_USERNAME";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO "$DB_USERNAME";
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO "$DB_USERNAME";
EOSQL

echo "Database and user setup complete for '$DB_NAME'."