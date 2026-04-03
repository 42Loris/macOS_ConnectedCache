# Microsoft Connected Cache — macOS (Apple Silicon)

Runs MCC on macOS via Docker Desktop by bootstrapping Azure IoT Edge inside a container.
IoT Edge connects to Azure IoT Hub, which then deploys the actual MCC container as a
sibling container on your local Docker daemon.

## How it works

```
Docker Desktop (macOS)
  └── mcc-iotedge container  ← Ubuntu + IoT Edge (this repo)
        └── /var/run/docker.sock (mounted from host)
              └── MCC container  ← pulled by IoT Edge from Azure
              └── edgeAgent      ← pulled by IoT Edge
              └── edgeHub        ← pulled by IoT Edge
```

## Prerequisites

- Docker Desktop for Mac with **Rosetta emulation enabled**
  - Settings → General → "Use Rosetta for x86_64/amd64 emulation on Apple Silicon" ✓
- An MCC cache node registered in the [Azure portal](https://portal.azure.com)
- A fresh **Registration Key** — copy the install command from the Azure portal
  (each key is one-time use; generate a new one if re-deploying)

## Setup

```bash
cp .env.example .env
# Edit .env — fill in CUSTOMER_ID, CACHE_NODE_ID, CUSTOMER_KEY, REGISTRATION_KEY
```

## Run

```bash
docker compose up -d --build
docker compose logs -f
```

IoT Edge will take a few minutes to register with Azure and pull the MCC container.
Watch for `edgeAgent` and `MCC` containers appearing in `docker ps`.

## Stop

```bash
docker compose down
```

## Notes

- MCC and edgeAgent/edgeHub are sibling containers managed by IoT Edge — they appear
  in `docker ps` alongside `mcc-iotedge`.
- Ports 80/443 are bound by the MCC sibling container, not `mcc-iotedge` itself.
- Configure clients to use `http://<mac-ip>` as their DO cache host.
- Cache drive configuration is set via the Azure portal deployment manifest.
- REGISTRATION_KEY expires after first use — generate a new one from the portal
  if you need to redeploy from scratch.
