# syntax=docker/dockerfile:1
# Force x64 image — runs via Rosetta on Apple Silicon Mac
FROM --platform=linux/amd64 mcr.microsoft.com/mcc/linux/iot/mcc-ubuntu-iot-amd64:latest

# Expose HTTP and HTTPS ports used by MCC
EXPOSE 80 443
