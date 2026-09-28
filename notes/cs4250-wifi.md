# cs4250 WiFi auto-connect

How to make a board (or an image) automatically join the `cs4250` WiFi
network on boot. Credentials saved by this setup:

| SSID     | PSK          |
|----------|--------------|
| `cs4250` | `ultrasecure`|

Verified on the Oz64 board `oz64-nat` (kernel `5.10.260-20260911-7+duos`)
on 2026-09-28. Associated at ~-61 dBm, DHCP lease `192.168.8.200/24`,
gateway `192.168.8.1` reachable.

## How it works

- The `wifi-builtin` addon ships `/etc/init.d/S30wifi` (in-tree source:
  `scripts/addons/wifi-builtin/S30wifi`), run at boot by
  `wifi-builtin.service`.
- If `/boot/wifi.sta` exists, S30wifi selects station mode. With no
  `/boot/wpa_supplicant.conf`, it reads `/boot/wifi.ssid` and
  `/boot/wifi.pass` and writes `/etc/network/interfaces.d/wlan0`:

  ```
  allow-hotplug wlan0
  iface wlan0 inet dhcp
  	wpa-essid cs4250
  	wpa-psk ultrasecure
  	wpa-scan-ssid 1
  ```

- On hotplug, ifupdown runs `/etc/network/if-pre-up.d/wpasupplicant`,
  which starts `wpa_supplicant` from the `wpa-*` options (converting the
  passphrase with `wpa_passphrase`), and `dhcpcd` obtains a lease.

The three `/boot` files are the only per-network inputs; the SSID and
password live in cleartext on the FAT boot partition.

## Configure a running board

The board must already have a working `wlan0` (see
`notes/oz64-wifi-minimal.md` for the AIC8800 power/driver bring-up).

1. Save the credentials and switch to station mode:

   ```sh
   printf 'cs4250'      | sudo tee /boot/wifi.ssid >/dev/null
   printf 'ultrasecure' | sudo tee /boot/wifi.pass >/dev/null
   sudo touch /boot/wifi.sta
   sync
   ```

2. Fix the `S30wifi` `echo -e` bug on already-built images. `/bin/sh` is
   `dash` there, whose builtin `echo` does not understand `-e`, so the
   generated `wlan0` file gets literal `-e` prefixes and ifupdown never
   sees the `wpa-*` options:

   ```sh
   sudo cp -n /etc/init.d/S30wifi /etc/init.d/S30wifi.orig
   sudo sed -i 's#echo -e "#/bin/echo -e "#g' /etc/init.d/S30wifi
   ```

   Newer images should carry the fix (see "Configure an image" below).

3. Regenerate the interface config and connect:

   ```sh
   sudo /etc/init.d/S30wifi restart
   sudo ifdown --force wlan0
   sudo ifup wlan0
   ```

## Verify

```sh
sudo cat /etc/network/interfaces.d/wlan0     # wpa-essid/wpa-psk, no "-e"
ip -4 -br addr show wlan0                    # 192.168.8.x/24
sudo iw dev wlan0 link                       # Connected ... cs4250
ping -c2 192.168.8.1                         # 0% loss
```

Survives reboot: `sudo reboot`, then re-run the checks above.

## Configure an image

Bake the `/boot` inputs in at build time. Addon `addon.mk` files write to
`/rootfs/boot/` (same mechanism as `/boot/usb.rndis`,
`/boot/hostname.prefix`, etc.), for example:

```make
	@mkdir -p /rootfs/boot
	@printf 'cs4250'      > /rootfs/boot/wifi.ssid
	@printf 'ultrasecure' > /rootfs/boot/wifi.pass
	@touch /rootfs/boot/wifi.sta
```

The `wifi-builtin` addon is already part of the board's
`IMAGE_ADDITIONS` (e.g. `configs/oz64/settings.mk`), so no extra addon is
needed to install `S30wifi` itself — only the `/boot` files.

Fix the shipped script so the generated `wlan0` file is valid. In
`scripts/addons/wifi-builtin/S30wifi` (and the NanoKVM variant
`scripts/addons/nanokvm/S30wifi`) replace the three `echo -e "\t..."`
lines with `printf`:

```sh
printf '\twpa-essid %s\n' "$ssid"
printf '\twpa-psk %s\n'   "$pass"
printf '\twpa-scan-ssid 1\n'
```

## Revert

```sh
sudo rm -f /boot/wifi.sta /boot/wifi.ssid /boot/wifi.pass
sudo ifdown --force wlan0
sudo /etc/init.d/S30wifi restart
# only if the runtime patch from step 2 was applied:
sudo mv /etc/init.d/S30wifi.orig /etc/init.d/S30wifi
```

Deleting `/boot/wifi.sta` leaves `S30wifi` in its default mode
(`iface wlan0 inet manual`).
