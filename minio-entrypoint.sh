#!/bin/sh
set -e # Exit immediately if a command exits with a non-zero status.

# --- 1. Start MinIO server in the background using the passed arguments ---
echo "Starting MinIO server in background with arguments: '$@'"
/usr/bin/minio "$@" & # Use "$@" to pass the command arguments
MINIO_PID=$!          # Capture the Process ID of the background MinIO process

# --- 2. Wait for MinIO server to be healthy ---
echo "Waiting for MinIO server to become healthy..."
MAX_RETRIES=20 # Max attempts to check MinIO health
RETRY_COUNT=0
until curl -sS -f http://localhost:9000/minio/health/live; do
  echo "MinIO not ready (attempt $((RETRY_COUNT + 1))), retrying in 5 seconds..."
  sleep 5
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
    echo "MinIO did not become healthy within the expected time. Exiting."
    kill $MINIO_PID # Kill the background MinIO process if it failed to start
    exit 1
  fi
done
echo "MinIO server is healthy and ready for configuration."

# --- 3. Perform mc configurations ---
echo "Setting mc alias using root credentials..."
mc alias set myminio http://localhost:9000 "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}"
echo "mc alias 'myminio' set."

# Assuming these environment variables are passed to the minio service
NEW_USER_ACCESS_KEY="${MINIO_ACCESS_KEY}"
NEW_USER_SECRET_KEY="${MINIO_SECRET_KEY}"

# Create the new user with its access key and secret key (if it doesn't exist)
echo "Creating user '${NEW_USER_ACCESS_KEY}' if it doesn't exist..."
if ! mc admin user info myminio "${NEW_USER_ACCESS_KEY}" >/dev/null 2>&1; then
  mc admin user add myminio "${NEW_USER_ACCESS_KEY}" "${NEW_USER_SECRET_KEY}"
  echo "User '${NEW_USER_ACCESS_KEY}' created."
else
  echo "User '${NEW_USER_ACCESS_KEY}' already exists."
fi

# Attach a built-in 'readwrite' policy to the new user (if not already attached)
echo "Attaching 'readwrite' policy to user '${NEW_USER_ACCESS_KEY}'..."
if ! mc admin policy info myminio "${NEW_USER_ACCESS_KEY}" | grep -q "readwrite"; then
  mc admin policy attach myminio readwrite --user "${NEW_USER_ACCESS_KEY}"
  echo "Policy attached to user '${NEW_USER_ACCESS_KEY}'."
else
  echo "Policy 'readwrite' already attached to user '${NEW_USER_ACCESS_KEY}'."
fi

echo "MinIO configuration complete. New Keys:"
echo "========================================"
echo "  Client App Access Key: ${NEW_USER_ACCESS_KEY}"
echo "  Client App Secret Key: ${NEW_USER_SECRET_KEY}"
echo "========================================"
echo "!!! MAKE SURE TO SAVE THE SECRET KEY NOW. IT WILL NOT BE SHOWN AGAIN IN MINIO. !!!"

# --- 4. Keep the background MinIO process alive ---
echo "Keeping MinIO server alive..."
wait $MINIO_PID # Wait for the background MinIO server process to finish. This keeps the container running.
