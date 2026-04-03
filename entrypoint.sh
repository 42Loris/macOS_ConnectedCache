#!/bin/bash
set -euo pipefail

# --- Validate required environment variables ---
: "${CUSTOMER_ID:?CUSTOMER_ID is required — get it from the Azure portal}"
: "${CACHE_NODE_ID:?CACHE_NODE_ID is required — get it from the Azure portal}"
: "${CUSTOMER_KEY:?CUSTOMER_KEY is required — get it from the Azure portal}"
: "${REGISTRATION_KEY:?REGISTRATION_KEY is required — get a fresh one from the Azure portal command line}"

GEO_HOST="geomcc.prod.do.dsp.mp.microsoft.com"
MCCKV_HOST="mcckv.prod.do.dsp.mp.microsoft.com"

# --- Step 1: Resolve the KV endpoint via geo lookup (same as deploymcc.sh) ---
echo "[MCC] Fetching geo endpoint..."
GeoResponse=$(curl -sf --insecure "https://${GEO_HOST}/geo?type=emcc" || echo "")
MCCKvHost=$(echo "$GeoResponse" \
    | grep -Po '"MCCKV_KeyValue_EndpointFullUri":.*?[^\\]",' \
    | tr ',' '\n' | cut -d '"' -f4 | cut -d '/' -f3 || echo "")
KvEndpointUrl="${MCCKvHost:-$MCCKV_HOST}"
echo "[MCC] Using KV endpoint: $KvEndpointUrl"

# --- Step 2: Fetch DPS scope ID + primary key using customer credentials ---
echo "[MCC] Fetching DPS credentials..."
KvResponse=$(curl -sf --insecure \
    "https://${KvEndpointUrl}/mccTool?toolName=deviceRegistration&customerKey=${CUSTOMER_KEY}&customerId=${CUSTOMER_ID}&cacheNodeId=${CACHE_NODE_ID}&registrationKey=${REGISTRATION_KEY}" \
    || echo "")

IsValidCustomer=$(echo "$KvResponse" | grep -Po '"IsValidCustomer":.*?[^\\]"' | cut -d '"' -f4 || echo "")
if [ "$IsValidCustomer" != "true" ]; then
    echo "[MCC] ERROR: Invalid credentials. Verify CUSTOMER_ID, CUSTOMER_KEY, and REGISTRATION_KEY in the Azure portal."
    exit 1
fi

ScopeId=$(echo "$KvResponse" | grep -Po '"scopeId":.*?[^\\]"' | cut -d '"' -f4 || echo "")
PrimaryKey=$(echo "$KvResponse" | grep -Po '"primaryKey":.*?[^\\]"' | cut -d '"' -f4 || echo "")

if [ -z "$ScopeId" ] || [ -z "$PrimaryKey" ]; then
    echo "[MCC] ERROR: Could not parse scopeId or primaryKey."
    echo "[MCC] REGISTRATION_KEY may be expired — generate a new command line in the Azure portal."
    exit 1
fi

echo "[MCC] DPS credentials obtained. Scope ID: ${ScopeId:0:8}..."

# --- Step 3: Write IoT Edge config.toml ---
mkdir -p /etc/aziot

cat > /etc/aziot/config.toml << EOF
[provisioning]
source = "dps"
global_endpoint = "https://global.azure-devices-provisioning.net"
id_scope = "${ScopeId}"

[provisioning.attestation]
method = "symmetric_key"
registration_id = "${CACHE_NODE_ID}"
symmetric_key = { value = "${PrimaryKey}" }

[agent]
name = "edgeAgent"
type = "docker"

[agent.config]
image = "mcr.microsoft.com/azureiotedge-agent:1.5"

[agent.env]
"UpstreamProtocol" = "AmqpWs"

# Point IoT Edge at the host Docker socket (mounted into this container)
[moby_runtime]
uri = "unix:///var/run/docker.sock"
network = "azure-iot-edge"
EOF

echo "[MCC] IoT Edge config written."

# --- Step 4: Apply config (writes per-service config drops under /etc/aziot/) ---
# iotedge config apply will fail on the systemctl restart step — that's expected.
echo "[MCC] Applying IoT Edge configuration..."
mkdir -p /run/aziot /run/iotedge /var/lib/aziot/certd /var/lib/aziot/identityd \
         /var/lib/aziot/keyd /var/lib/iotedge

iotedge config apply -c /etc/aziot/config.toml 2>&1 | grep -v "systemctl" || true

# --- Step 5: Start aziot daemons in dependency order ---
# keyd must be up before certd, certd before identityd, identityd before edged.
echo "[MCC] Starting aziot-keyd..."
/usr/libexec/aziot/aziot-keyd &
until [ -S /run/aziot/keyd.sock ] 2>/dev/null; do sleep 0.5; done
echo "[MCC] aziot-keyd ready."

echo "[MCC] Starting aziot-certd..."
/usr/libexec/aziot/aziot-certd &
until [ -S /run/aziot/certd.sock ] 2>/dev/null; do sleep 0.5; done
echo "[MCC] aziot-certd ready."

echo "[MCC] Starting aziot-identityd..."
/usr/libexec/aziot/aziot-identityd &
until [ -S /run/aziot/identityd.sock ] 2>/dev/null; do sleep 0.5; done
echo "[MCC] aziot-identityd ready."

echo "[MCC] Starting aziot-edged..."
echo "[MCC] edgeAgent will connect to IoT Hub and pull the MCC container — this can take a few minutes."
/usr/libexec/aziot/aziot-edged &

# Keep the container alive; exit if any daemon dies
wait -n
echo "[MCC] A daemon exited unexpectedly. Check logs with: docker logs mcc-iotedge"
exit 1
