#!/bin/sh
set -e
cd /home/nat/Code/sophgo-sg200x-debian

# Rebuild the builder image so it contains the current scripts/ (including the
# preconfigure addon and the WiFi fixes).
docker build -t builder -f scripts/Dockerfile .

# Build the Oz64 image, preconfigured to join the open "domenet" WiFi and come
# up as "oz64-nat". If the network is secured, add: WIFI_PASS='the-password'
docker run --privileged -it --rm \
  -v "$PWD/configs":/configs -v "$PWD/image":/output \
  builder make BOARD=oz64 SECOND_CPU=arduino \
  IMAGE_HOSTNAME=oz64-nat \
  WIFI_MODE=sta WIFI_SSID=domenet \
  image
