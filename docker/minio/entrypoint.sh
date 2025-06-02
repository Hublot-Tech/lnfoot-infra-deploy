#!/bin/sh
set -e # Exit on first error

# --- 1. Start MinIO server in the background using the passed arguments ---
echo "Starting MinIO server in background with arguments: '$@'"
/usr/bin/minio "$@" & # Use "$@" to pass the command arguments
MINIO_PID=$! # Capture the Process ID of the background MinIO process

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

# 1. Wait for MinIO alias to be successfully set
echo "Waiting for MinIO alias to be set..."
until mc alias set myminio http://minio:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}; do
    echo "MinIO alias not set, retrying..."
    sleep 2
done
echo "MinIO alias 'myminio' set."

# 4. Create the custom policy for the app client (read/write)
echo "Creating custom policy '${APP_CLIENT_POLICY_NAME}' for app client..."
echo "${APP_CLIENT_POLICY_JSON}" >/tmp/app_client_policy.json
if ! mc admin policy info myminio "${APP_CLIENT_POLICY_NAME}" >/dev/null 2>&1; then
    mc admin policy create myminio "${APP_CLIENT_POLICY_NAME}" /app_client_policy.json
    echo "Policy '${APP_CLIENT_POLICY_NAME}' added."
else
    echo "Policy '${APP_CLIENT_POLICY_NAME}' already exists."
fi

# 5. Create the app client user if it doesn't exist
echo "Creating user '${APP_CLIENT_ACCESS_KEY}' if it doesn't exist..."
if ! mc admin user info myminio "${APP_CLIENT_ACCESS_KEY}" >/dev/null 2>&1; then
    mc admin user add myminio "${APP_CLIENT_ACCESS_KEY}" "${APP_CLIENT_SECRET_KEY}"
    echo "User '${APP_CLIENT_ACCESS_KEY}' created."
else
    echo "User '${APP_CLIENT_ACCESS_KEY}' already exists."
fi

# Attach the custom global read/write policy to the new user
echo "Attaching policy '${APP_CLIENT_POLICY_NAME}' to user '${APP_CLIENT_ACCESS_KEY}'..."
# Removed grep check here. mc admin policy attach might error if already attached, but usually does not halt.
mc admin policy attach myminio "${APP_CLIENT_POLICY_NAME}" --user "${APP_CLIENT_ACCESS_KEY}" || true # Use || true to prevent script from stopping if already attached and cmd errors
echo "Policy '${APP_CLIENT_POLICY_NAME}' attached to user '${APP_CLIENT_ACCESS_KEY}' (or already was)."


echo "MinIO configuration complete."
echo ""
echo "========================================"
echo "  Public Access: Read-only (anonymous)"
echo "  App Client Access Key: ${APP_CLIENT_ACCESS_KEY}"
echo "  App Client Secret Key: ${APP_CLIENT_SECRET_KEY}"
echo "========================================"
echo "!!! MAKE SURE TO SAVE THE APP CLIENT SECRET KEY NOW. !!!"

# --- 4. Keep the background MinIO process alive ---
echo "Keeping MinIO server alive..."
wait $MINIO_PID