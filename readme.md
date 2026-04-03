# Microsoft Connected Cache — macOS (Apple Silicon)

Runs the official MCC x64 container on ARM Mac via Docker Desktop's Rosetta emulation.

## Prerequisites

- Docker Desktop for Mac with **Rosetta emulation enabled**
  - Settings → General → "Use Rosetta for x86_64/amd64 emulation on Apple Silicon" ✓
- An MCC cache node registered in the [Azure portal](https://portal.azure.com)

## Setup

```bash
cp .env.example .env
# Edit .env and fill in CUSTOMER_ID, CACHE_NODE_ID, CUSTOMER_KEY
```

## Run

```bash
docker compose up -d
docker compose logs -f
```

## Stop

```bash
docker compose down
```

## Notes

- Cache data persists in the `mcc-cache` Docker volume across restarts.
- The container image is `mcr.microsoft.com/mcc/linux/iot/mcc-ubuntu-iot-amd64:latest` (x64 only — emulated via Rosetta).
- MCC serves content on port 80 (HTTP). Configure clients to use `http://<mac-ip>` as their DO cache host.
