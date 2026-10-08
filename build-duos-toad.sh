#!/bin/sh
set -e
cd "$(cd "$(dirname "$0")" && pwd)"

# Rebuild the builder image so it contains the current scripts/ (including the
# preconfigure addon, the WiFi fixes and the toolchain tarball cache). Fast:
# .dockerignore keeps the build context tiny and the apt layer is cached.
docker build -t builder -f scripts/Dockerfile .

# Cached build (see build.sh / README: build state lives in named volumes, so
# re-runs only rebuild what changed; changing the hostname prefix / WiFi below
# automatically triggers an image-clean so the requested config is baked in).
# IMAGE_HOSTNAME_PREFIX gives every device a unique <prefix>-<hash> hostname,
# with wlan0 advertising <prefix>-<hash>-wifi. The hash is derived from the SoC
# UID at first boot, so one image works for any number of boards.
./build.sh BOARD=duos SECOND_CPU=arduino \
  IMAGE_HOSTNAME_PREFIX=duos-toad \
  WIFI_MODE=sta WIFI_SSID=cs4250 WIFI_PASS=ultrasecure \
  image
