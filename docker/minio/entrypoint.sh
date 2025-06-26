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

# --- NEW ADDITION: Set up the 'local' alias with admin credentials ---
MINIO_ALIAS="local"
echo "Setting up MinIO alias '${MINIO_ALIAS}' with admin credentials..."
until mc alias set "${MINIO_ALIAS}" http://localhost:9000 "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}"; do
  echo "MinIO alias '${MINIO_ALIAS}' not set, retrying..."
  sleep 2
done
echo "MinIO alias '${MINIO_ALIAS}' set successfully."

# 4. Create the custom policy for the app client (read/write)
echo "Creating custom policy '${APP_CLIENT_POLICY_NAME}' for app client..."

# Store the output and exit code of the policy info command
POLICY_INFO_OUTPUT=$(mc admin policy info "${MINIO_ALIAS}" "${APP_CLIENT_POLICY_NAME}" 2>&1)
POLICY_INFO_EXIT_CODE=$?

# Check the exit code for success/failure
if [ "$POLICY_INFO_EXIT_CODE" -ne 0 ]; then
    echo "Policy '${APP_CLIENT_POLICY_NAME}' does NOT exist or an error occurred while checking."
    echo "Output of 'mc admin policy info':"
    echo "${POLICY_INFO_OUTPUT}" # Output the stored command result

    echo "Attempting to create policy '${APP_CLIENT_POLICY_NAME}'..."
    mc admin policy create "${MINIO_ALIAS}" "${APP_CLIENT_POLICY_NAME}" /app_client_policy.json
    echo "Policy '${APP_CLIENT_POLICY_NAME}' added."
else
    echo "Policy '${APP_CLIENT_POLICY_NAME}' already exists. Output of 'mc admin policy info':"
    echo "${POLICY_INFO_OUTPUT}" # Output the stored command result
fi


# 5. Create the app client user if it doesn't exist
echo "Creating user '${APP_CLIENT_ACCESS_KEY}' if it doesn't exist..."
# Store the output and exit code of the user info command
USER_INFO_OUTPUT=$(mc admin user info "${MINIO_ALIAS}" "${APP_CLIENT_ACCESS_KEY}" 2>&1)
USER_INFO_EXIT_CODE=$?

if [ "$USER_INFO_EXIT_CODE" -ne 0 ]; then
    echo "User '${APP_CLIENT_ACCESS_KEY}' does NOT exist or an error occurred while checking."
    echo "Output of 'mc admin user info':"
    echo "${USER_INFO_OUTPUT}" # Output the stored command result

    echo "Attempting to create user '${APP_CLIENT_ACCESS_KEY}'..."
    mc admin user add "${MINIO_ALIAS}" "${APP_CLIENT_ACCESS_KEY}" "${APP_CLIENT_SECRET_KEY}"
    echo "User '${APP_CLIENT_ACCESS_KEY}' created."
else
    echo "User '${APP_CLIENT_ACCESS_KEY}' already exists. Output of 'mc admin user info':"
    echo "${USER_INFO_OUTPUT}" # Output the stored command result
fi

# Attach the custom global read/write policy to the new user
echo "Attaching policy '${APP_CLIENT_POLICY_NAME}' to user '${APP_CLIENT_ACCESS_KEY}'..."
# Capture output for policy attach as well for debugging if needed
POLICY_ATTACH_OUTPUT=$(mc admin policy attach "${MINIO_ALIAS}" "${APP_CLIENT_POLICY_NAME}" --user "${APP_CLIENT_ACCESS_KEY}" 2>&1)
POLICY_ATTACH_EXIT_CODE=$?

if [ "$POLICY_ATTACH_EXIT_CODE" -ne 0 ]; then
    echo "Failed to attach policy '${APP_CLIENT_POLICY_NAME}' to user '${APP_CLIENT_ACCESS_KEY}'."
    echo "Output of 'mc admin policy attach':"
    echo "${POLICY_ATTACH_OUTPUT}"
    # Decide if you want to exit here or continue. Using || true previously indicated continuing.
    # For now, we'll just log and continue as per previous logic.
else
    echo "Policy '${APP_CLIENT_POLICY_NAME}' attached to user '${APP_CLIENT_ACCESS_KEY}' (or already was)."
    echo "Output of 'mc admin policy attach':"
    echo "${POLICY_ATTACH_OUTPUT}"
fi


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
