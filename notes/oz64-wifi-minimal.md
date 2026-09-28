# Oz64 WiFi — minimum live-board changes

This is the shortest path to get the onboard AIC8800DC WiFi working on an
Oz64 that is already running the scpcom Duo S Debian image, **without
rebuilding the image**. Everything here was verified on 2026-09-28.

Board facts used below:
- SDIO WiFi is on `mmc1` (`4320000.wifi-sd`).
- The AIC8800DC `CHIP_EN` / `WL_REG_ON` is SG2000 pad `AUX0` =
  `XGPIOA[30]` = **Linux GPIO 510**.
- The driver's default firmware dir is
  `/usr/lib/firmware/aic8800_sdio/aic8800_and_aic8800D80`
  (`/lib` is a symlink to `/usr/lib`).
- The shipped `aic8800_fdrv.ko` is built with `CONFIG_SDIO_BT=y`; the
  BT-over-SDIO path hangs the bus (`-110/intstatus=ff` storm) and wedges
  the machine. It must be rebuilt with that off.

There are three required changes: firmware, driver, and powering the chip.

## 1. Install the AIC8800DC firmware

```sh
cd /tmp
wget -q -O aicfw.tar.gz \
  https://codeload.github.com/scpcom/aic8800-sdio-firmware/tar.gz/6314482
mkdir -p aicfw
tar -xzf aicfw.tar.gz -C aicfw --strip-components=1 \
  aic8800-sdio-firmware-6314482/aic8800DC
sudo cp -a /tmp/aicfw/aic8800DC/. \
  /lib/firmware/aic8800_sdio/aic8800_and_aic8800D80/
# should now be non-empty:
find /lib/firmware -iname '*8800dc*' | head
```

The driver uses a single `aic_fw_path`, so the DC blobs are dropped into
the existing `aic8800_and_aic8800D80` directory.

## 2. Rebuild `aic8800_fdrv.ko` with BT-over-SDIO disabled

The image ships matching kernel headers, but Debian's riscv64 headers
contain x86_64 host tools and are missing a couple of files, so a few
tweaks are needed for a native build.

```sh
sudo apt-get update
sudo apt-get install -y --no-install-recommends build-essential

# source
cd ~ && rm -rf aicbuild && mkdir aicbuild && cd aicbuild
wget -q -O osdrv.tar.gz \
  https://codeload.github.com/scpcom/sophgo-osdrv/tar.gz/a2410f3ffcd29d8accca5e12d8c31bed4aacc178
mkdir src
tar -xzf osdrv.tar.gz -C src --strip-components=4 \
  '*/extdrv/wireless/aic8800'

# private copy of the kernel headers
KH=$PWD/kheaders
cp -a /usr/src/linux-headers-$(uname -r) "$KH"
# 1) -mno-ldd is a T-Head-only option unsupported by Debian gcc
sed -i 's|KBUILD_CFLAGS += -mno-ldd|KBUILD_CFLAGS += $(call cc-option,-mno-ldd)|' \
  "$KH/arch/riscv/Makefile"
# 2) headers omit the vdso Makefile
mkdir -p "$KH/arch/riscv/kernel/vdso"
printf 'obj-y :=\n' > "$KH/arch/riscv/kernel/vdso/Makefile"
# 3) rebuild the (x86_64) host tools for riscv64
( cd "$KH/scripts/basic" && gcc -O2 -o fixdep fixdep.c )
( cd "$KH/scripts/mod" && gcc -O2 -I. -o modpost modpost.c sumversion.c file2alias.c )

cd ~/aicbuild/src/aic8800_fdrv
make -C "$KH" M="$PWD" ARCH=riscv CROSS_COMPILE= \
  CONFIG_SDIO_BT=n CONFIG_COEX=n \
  CONFIG_VECTOR_0_7=n CONFIG_RISCV_ISA_THEAD=n \
  CONFIG_TOOLCHAIN_NEEDS_EXPLICIT_ZICSR_ZIFENCEI=y \
  CONFIG_AIC_FW_PATH='"/usr/lib/firmware/aic8800_sdio/aic8800_and_aic8800D80"' \
  KBUILD_MODPOST_WARN=1 \
  modules
ls -l aic8800_fdrv.ko
```

`KBUILD_MODPOST_WARN=1` is only needed because the fdrv references symbols
exported by the (separately loaded) `aic8800_bsp` module.

Sanity check that BT is really gone:

```sh
strings aic8800_fdrv.ko | grep -ciE 'btsdio|TDLS_SDIO_BT'   # expect 0
```

## 3. Power the chip and load the driver

The boot service `S25wifimod` has already loaded `aic8800_bsp` (and
`cfg80211`). Assert `CHIP_EN`, rescan the SDIO host, then load the new
fdrv. The card only appears after the GPIO is high **and** mmc1 is
rescanned (the mmc host already probed with no card at boot).

```sh
echo 510 | sudo tee /sys/class/gpio/export
echo out | sudo tee /sys/class/gpio/gpio510/direction
echo 1   | sudo tee /sys/class/gpio/gpio510/value
sleep 1
echo 1 | sudo tee /sys/class/mmc_host/mmc1/rescan
sleep 2
ls /sys/bus/mmc/devices/                 # expect mmc1:xxxx

sudo rmmod aic8800_fdrv 2>/dev/null
sudo insmod ~/aicbuild/src/aic8800_fdrv/aic8800_fdrv.ko
sleep 3
ip -br link | grep wlan0
```

You should get `mmc1:xxxx`, no `aicwf_sdio_hal_irqhandler` errors, and a
`wlan0` interface.

## 4. Connect (optional check)

```sh
sudo apt-get install -y iw wpasupplicant
sudo ip link set wlan0 up
sudo iw dev wlan0 scan | grep SSID
sudo iw dev wlan0 connect <OPEN-SSID>          # or use wpa_supplicant
sudo busybox udhcpc -i wlan0 -n -q -t 15 -T 2  # obtains a lease
```

Note: `busybox udhcpc` without a script prints the lease but does not
apply it; add the address manually if needed. If the board also has
ethernet on the same subnet, flush stale neighbours
(`sudo ip neigh flush all`) before pinging.

## 5. Make it survive a reboot (optional)

The changes above are runtime-only. To persist:

```sh
D=/mnt/system/ko/$(uname -r)/3rd
sudo cp -n $D/aic8800_fdrv.ko $D/aic8800_fdrv.ko.orig
sudo cp ~/aicbuild/src/aic8800_fdrv/aic8800_fdrv.ko $D/aic8800_fdrv.ko
```

Then edit `/etc/init.d/S25wifimod` and, in the `start` branch **before**
the `insmod` lines, add:

```sh
	echo 510 > /sys/class/gpio/export 2>/dev/null
	echo out > /sys/class/gpio/gpio510/direction 2>/dev/null
	echo 1   > /sys/class/gpio/gpio510/value 2>/dev/null
	sleep 1
	echo 1   > /sys/class/mmc_host/mmc1/rescan 2>/dev/null
	sleep 2
```

Keep a backup of the original script. After `sudo reboot`, the card
enumerates, the BT-disabled driver autoloads, and `wlan0` comes up.

## Why each change

- GPIO 510 = `WIFI_CHIP_EN`; without it the AIC8800DC is off and SD1 sees
  no card.
- `CONFIG_SDIO_BT=n` (and `CONFIG_COEX=n`): the BT-over-SDIO send
  (`TDLS_SDIO_BT_SEND_CFM`, msg id 3089) is what hangs the SDIO bus; the
  card is otherwise fine.
- DC firmware must be in the driver's default firmware directory, or
  firmware upload fails even after enumeration.

## Reverting

- Driver: `sudo cp $D/aic8800_fdrv.ko.orig $D/aic8800_fdrv.ko`
- Boot script: restore the `S25wifimod` backup.
- GPIO: `echo 510 | sudo tee /sys/class/gpio/unexport`.
