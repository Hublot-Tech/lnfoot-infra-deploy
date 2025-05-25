# infra-deploy

**Infrastructure Deployment Repository for LN Foot Project**

This repository automates the deployment of the entire LN Foot platform, including:

- 🧩 Landing page
- ⚙️ Admin platform
- 🔌 API backend
- 🛡 Keycloak (Identity provider)
- ☁️ MinIO (Object storage)
- 🌐 Caddy (Reverse proxy + HTTPS)

---

## 📁 Project Structure

```

docker/
├── Caddyfile                     # Reverse proxy config (Caddy)
├── compose.yml                   # Main Docker Compose file
├── keycloak/
│   ├── config/
│   │   ├── realm.theme.ln-foot-01.json
│   └── config.env                # Keycloak environment variables
├── minio/
│   └── config.env                # MinIO environment variables

````

---

## 🚀 Deployment Workflow

Deployment is automated via GitHub Actions and triggered when version tags are pushed from the following service repositories:

| Service | Example Repo Name      | Tag Format           | Example Tag       |
|---------|------------------------|----------------------|-------------------|
| Landing | `lnfoot-landing`       | `landing-vX.Y.Z`     | `landing-v1.0.0`  |
| Admin   | `lnfoot-admin`         | `admin-vX.Y.Z`       | `admin-v2.1.0`    |
| API     | `lnfoot-api`           | `api-vX.Y.Z`         | `api-v0.9.5`      |

Upon receiving a tag:
1. The corresponding Docker image is pulled from GHCR.
2. Docker Compose is restarted with the new image tag.
3. Other infrastructure services (Keycloak, MinIO, Caddy) remain unchanged unless manually updated.

---

## 🔧 Server Requirements

Make sure your VPS or bare-metal server has:

- Docker
- Docker Compose
- Open ports: 80/443, 5432 (Postgres), 9000 (MinIO), 8080/8443 (Keycloak)
- Domain configured (if using Caddy with HTTPS)

---

## 🔐 GitHub Secrets

Set the following secrets in your **`infra-deploy` repo → Settings → Secrets and Variables → Actions**:

| Secret Name           | Description                                 |
|-----------------------|---------------------------------------------|
| `VPS_HOST`            | IP or domain of the VPS                     |
| `VPS_USER`            | SSH username (e.g. `ubuntu`)                |
| `VPS_SSH_PRIVATE_KEY` | Private SSH key to connect to the VPS       |
| `GHCR_TOKEN`          | Personal access token to pull GHCR images   |

---

## 📜 Docker Compose Environment

- **Keycloak** uses its own `.env` file: `docker/keycloak/config.env`
- **MinIO** uses: `docker/minio/config.env`
- Database URLs and service credentials are managed through environment files and/or Docker secrets (recommended).

---

## 🛠 Local Development

You can test the infrastructure locally with:

```bash
cd docker
docker compose --env-file keycloak/config.env --env-file minio/config.env up -d
````

Make sure to:

* Configure your `/etc/hosts` file for local domains used by Caddy.
* Provide valid `.env` values for each service.

---

## 🧩 Adding a New Service

To add a new service to the infra:

1. Update `docker/compose.yml`
2. Add any necessary `.env` files under `docker/<service>/config.env`
3. Update GitHub Actions workflows (if needed)

---

## 📄 License

MIT License — maintained by LN Foot team

```
