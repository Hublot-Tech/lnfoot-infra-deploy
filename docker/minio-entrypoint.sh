# 1. Wait for MinIO alias to be successfully set (retry if MinIO is briefly unavailable)
echo "Waiting for MinIO alias to be set..."
until mc alias set myminio http://minio:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}; do
    sleep 2
done
echo "MinIO alias 'myminio' set."

# 2. Create the new user with their keys
echo "Creating user '${APP_ACCESS_KEY}'..."
mc admin user add myminio ${APP_ACCESS_KEY} ${APP_SECRET_KEY}
echo "User '${APP_ACCESS_KEY}' created."

# 3. Attach a built-in 'readwrite' policy to the new user
echo "Attaching 'readwrite' policy to user '${APP_ACCESS_KEY}'..."
mc admin policy attach myminio readwrite --user ${APP_ACCESS_KEY}
echo "Policy attached."

echo "MinIO configuration complete."
echo ""
echo "========================================"
echo "  New Client App Access Key: ${APP_ACCESS_KEY}"
echo "  New Client App Secret Key: ${APP_SECRET_KEY}"
echo "========================================"
echo "!!! MAKE SURE TO SAVE THE SECRET KEY NOW. IT WILL NOT BE SHOWN AGAIN IN MINIO. !!!"
