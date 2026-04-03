# syntax=docker/dockerfile:1
# Ubuntu 22.04 base with Azure IoT Edge — runs on macOS via Docker Desktop (Rosetta)
FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl wget openssl bc coreutils \
    && rm -rf /var/lib/apt/lists/*

# Add Microsoft package repository
RUN wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb \
        -O /tmp/mspkg.deb \
    && dpkg -i /tmp/mspkg.deb \
    && rm /tmp/mspkg.deb

# Install IoT Edge + Identity Service (versions from deploymcc.sh defaults)
RUN apt-get update && apt-get install -y \
    aziot-edge=1.5.16-1 \
    aziot-identity-service=1.5.5-1 \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Ports are bound by the MCC sibling container that IoT Edge pulls — not this one
EXPOSE 80 443

ENTRYPOINT ["/entrypoint.sh"]
