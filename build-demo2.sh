#!/bin/sh
set -e
cd /home/nat/Code/sophgo-sg200x-debian

# Rebuild the builder image so it contains the current scripts/ (including the
# preconfigure addon, the WiFi fixes and the toolchain tarball cache). Uncomment
# when scripts/ changed; fast now thanks to .dockerignore + layer caching.
#docker build -t builder -f scripts/Dockerfile .

# Cached build (see build.sh / README: build state lives in named volumes, so
# re-runs only rebuild what changed; changing the WiFi/hostname below
# automatically triggers an image-clean so the requested config is baked in).
./build.sh BOARD=oz64 SECOND_CPU=arduino \
  IMAGE_HOSTNAME=oz64-toad \
  WIFI_MODE=sta WIFI_SSID=cs4250 WIFI_PASS=ultrasecure \
  image
