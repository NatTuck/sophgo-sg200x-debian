# Debian Images for Sophgo cv181x/sg200x based boards 
This repository builds debian images for Sophgo cv181x/sg200x based boards such as MilkV Duo256/DuoS, Sipeed LicheeRvNano/NanoKVM and the Pine64 Oz64.

(Note, we don't support the MilkV Duo, as it does not have enough ram to run Debian)

The images aim to be as close to possible to debian best practices as possible

[AX620Q/AX630C based boards](configs/chip/ax620e#readme) are supported too.

## Flashing the Image

### Duo256, DuoS, and LicheeRVNano
To flash from linux, either build your own image and then run the following command:
```
sudo dd if=image/(board)_sd.img of=/dev/sdX bs=4M status=progress
```
... or download a image from the releases page, and then run the following command:
```
lz4 -cd (board)_sd.img.lz4 | sudo dd of=/dev/sdX bs=4M status=progress
```

From windows, you can use tools such as balena etcher

where the (board)_sd.img is the image file you want to flash, and /dev/sdX is the device you want to flash to.
(if you build for a different board, the image file name will be different)

### DuoS with EMMC
To flash the DuoS with EMMC, you need to use the vendor tools to flash the image to the EMMC. You can follow the
instructions at https://milkv.io/docs/duo/getting-started/duos#emmc-version-firmware-burning but instead of downloading 
the  milkv-duos-emmc-v1.1.0-2024-0410.zip file, you download the duos_emmc.zip from the releases on this repository.

if you already have a image installed, but wish to upgrade, when u-boot loads up, interupt the boot process by pressing any
key and typing the following commands:
```
cvi_update
```

The flashing should then continue

## Running Arduino Sketches

Running Arduino sketches on the second core requires an image built with `SECOND_CPU=arduino`.

> *On the Oz64, you can compile sketches with Arduino IDE, but you cannot upload it through its USB host port. Copy the compiled ELF onto the board and start it using remoteproc.*

First, download and install [Arduino CLI](https://docs.arduino.cc/arduino-cli/installation/) for your system.
- On macOS, you can use brew:
    ```
    brew update
    brew install arduino-cli
    ```
- On Linux, it's easiest to install it using their installer:
    ```
    curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh
    ```
    This will install to `$PWD/bin`. Make sure the installation directory is in your environment's PATH.

Then install the (forked) `sophgo-arduino` core, which includes support for the following boards:

- MilkV Duo
- MilkV Duo256
- MilkV DuoS
- PINE64 Oz64

Note: this repository can only build `SECOND_CPU=arduino` images for `duos` and `oz64`; the MilkV Duo is not supported here at all and `duo256` is untested (see `notes/fix-arduino.md`). The list above is the set of boards the Arduino core itself supports.

```
arduino-cli config add board_manager.additional_urls https://github.com/NatTuck/sophgo-arduino/releases/download/v0.2.7-a/package_sg200x_index.json
arduino-cli core update-index
arduino-cli core install sophgo:SG200X
```

You can verify that you have support for your board with:
```
arduino-cli board listall
```

> *If the PINE64 Oz64 isn't listed, you likely have a stale board manager URL in your config. The above is a fork that specifically adds support. Remove the old URL with `arduino-cli config remove board_manager.additional_urls <old-url>` (see `arduino-cli config get board_manager.additional_urls`), then re-run `core update-index`.*

Then, compile the sketch for your platform. E.g., use `duos` for the MilkV DuoS or `oz64` for the PINE64 Oz64.

```bash
mkdir -p Blink1
cat << 'EOF' > Blink1/Blink1.ino
#define LED_PIN 7

void setup() {
  pinMode(LED_PIN, OUTPUT);
}

void loop() {
  digitalWrite(LED_PIN, HIGH);
  delay(100);
  digitalWrite(LED_PIN, LOW);
  delay(100);
}
EOF

arduino-cli compile --fqbn sophgo:SG200X:oz64 --build-path Blink1/build Blink1

ls Blink1/build
# expected:
# Blink1.ino.bin  Blink1.ino.hex  build.options.json     core            libraries        sketch
# Blink1.ino.elf  Blink1.ino.map  compile_commands.json  includes.cache  libraries.cache
```

The example uses `LED_PIN 7`, which is not the built-in-LED constant (`LED_BUILTIN`); set it to the pin your LED is actually on.

On some boards the linker prints `_getpid`/`_kill` "not implemented and will always fail" warnings (e.g. `duos`); they are harmless. Compilation must exit 0, otherwise you may upload a stale ELF by accident.

After you have your firmware `.elf`, copy it onto the board and start it. The remote must be `offline` before you select a new firmware: if `cat /sys/class/remoteproc/remoteproc0/state` already says `running`, stop it first with `echo stop | sudo tee /sys/class/remoteproc/remoteproc0/state`.

Example with SSH:

```
# on host, replace oz64 with your board hostname/IP
scp Blink1/build/Blink1.ino.elf debian@oz64:/tmp/blink.elf
ssh debian@oz64

# on dev board
sudo cp /tmp/blink.elf /lib/firmware/blink.elf
# load the remoteproc driver if it isn't loaded already
sudo modprobe cvitek_remoteproc
echo blink.elf | sudo tee /sys/class/remoteproc/remoteproc0/firmware
echo start | sudo tee /sys/class/remoteproc/remoteproc0/state
```

If you get a `No such file or directory` error, your elf was probably not copied into `/lib/firmware`.

If you get an error about the device being unavailable or busy, make sure to stop any existing firmware by setting `state` to `stop`.

## Image Info
Logins: root/rv and debian/rv

(root login is disabled via SSH, login via debian, and SU to root if needed)

### USB Gadget Support
by default, a rndis interface is started on the USB port, and the IP address is
10.x.y.1 - It also starts a DHCP Server on that interface, so your PC should automatically get an IP address in the 10.x.y.z range

To Disable the rndis interface, you can run the following command:
```
rm /boot/usb.rndis
```

There is also a option to start a serial port (ACM) interface instead of the rndis interface, to do this, you can run the following command:
```
rm /boot/usb.rndis
touch /boot/usb.GS0
```

After executing these commands, you need to reboot.

### DuoS - USB Type A Port
After disabling the usb-gadgets, if you want to use the USB Type A Ports, then you need to turn them on:
```
rm /boot/usb.dev
systemctl enable usb-switch
```

and reboot afterwards. 

### WiFi on DuoS/LicheeRVNano/Oz64
For the LicheeRVNano/DuoS/Oz64 boards, WiFi is enabled. To connect to your wifi network, execute the following command (example, use ssid and password of your wifi network):
```
touch /boot/wifi.sta
echo "My WiFi" | tee /boot/wifi.ssid
printf '%s\n' 'Pa$$w0rd' | tee /boot/wifi.pass
```

### Ethernet
For Boards with ethernet, they should automatically get a IP address if your network has a DHCP Server. You can configure the 
ethernet port in /etc/network/interfaces.d/end0

### Camera/ISP/Panel Support
The images are based on the vendor 5.10 kernel and osdrv, also including the following drivers:
- mipi-rx/csi drivers
- mipi-tx/dsi drivers
- TPU Drivers
- Any of the Video Encoding Drivers

The extra drivers are build on a separate package called cvitek-osdrv-(board), they will be installed to /mnt/system/ko

The libs and samples are build on a separate package called cvitek-middleware-(board), they will be installed to /mnt/system/usr

The images, by default, allocate minimum amount of memory for the ION heap to use vi/venc, so you get more memory for the OS

### Ardunio/Freertos Support
The SG2000 has a single small C906L core. It can either run the vendor ISP
(camera/VPSS/VENC/TPU) or a user FreeRTOS/Arduino image via the kernel
remoteproc driver, **but not both** — the two occupy the same core and the same
`fast_image`/`CVIMMAP_FREERTOS_*` memory window, so there is no single image that
can do either at runtime. Select one personality at build time with `SECOND_CPU`
(see [Build-time Configuration](#build-time-configuration)):

- `SECOND_CPU=camera` uses the C906L for the ISP. This is the default on
  `duos`/`duo256`/`lichee*`; Arduino is not available there.
- `SECOND_CPU=arduino` sets `ION_SIZE=0`, so the ISP/vcodec modules are not
  loaded and the C906L is left free. It adds the `mbox`/`cv181x-c906_1` nodes to
  the kernel DTB (via `configs/common/dts/cv181x/arduino-rproc.dtsi`), so the
  kernel binds `cvitek_mailbox` + `cvitek_remoteproc` and exposes
  `/sys/class/remoteproc/remoteproc0`. This is the default on `oz64`.

Because the choice changes the memory map, the two personalities are separate
full image builds. The remoteproc is **not auto-started**: users supply their
own Arduino/FreeRTOS ELF (e.g. into `/lib/firmware/`) and start it manually with
`echo start > /sys/class/remoteproc/remoteproc0/state` (or add a unit).

### LCD Panel Support
If you have a DSI LCD panel connected you can install the matching bootloader.

LicheeRV Nano

 - cvitek-fsbl-licheervnano (no LCD)
 - cvitek-fsbl-licheervnano-d240si31 (2.4 inch, hynitron cst7xx touchscreen, a.k.a st7701_lct024bsi20)
 - cvitek-fsbl-licheervnano-lt9611-1024x768-60hz (dsi to hdmi)
 - cvitek-fsbl-licheervnano-lt9611-1280x720-60hz (dsi to hdmi)
 - cvitek-fsbl-licheervnano-mtd700920b (7 inch)
 - cvitek-fsbl-licheervnano-st7701-d300fpc9307a (3 inch)
 - cvitek-fsbl-licheervnano-st7701-d310t9362v1 (3.1 inch)
 - cvitek-fsbl-licheervnano-st7701-dxq5d0019b480854 (5 inch)
 - cvitek-fsbl-licheervnano-st7701-dxq5d0019-v0 (5 inch)
 - cvitek-fsbl-licheervnano-st7701-hd228001c31 (2.28 inch, hynitron cst3xx touchscreen)
 - cvitek-fsbl-licheervnano-st7701-hd228001c31-alt0 (2.28 inch)
 - cvitek-fsbl-licheervnano-st7701-lhcm228ts003a (2.28 inch)
 - cvitek-fsbl-licheervnano-zct2133v1 (7 inch)

Milk-V DuoS

 - cvitek-fsbl-duos (no LCD)
 - cvitek-fsbl-duos-milkv-8hd (8 inch)
 - cvitek-fsbl-duos-milkv-8hd-2lane (8 inch)
 - cvitek-fsbl-duos-milkv-st7796s (4 inch)

Example if you have a st7701_hd228001c31 connected:
```
apt-get install cvitek-fsbl-licheervnano-st7701-hd228001c31
apt-get remove cvitek-fsbl-licheervnano
```

You may also want to enable the FB driver:
```
touch /boot/fb
```

If you have a SPI LCD panel connected you can enable the matching driver.

Additional changes to the DTS file maybe required if not using ST7789x based panel.

Available panel parameters for st7789x:
 - st7789
 - st7789v_milkv
 - st7789v_weactstudio

st7789 on spi2 of LicheeRV Nano:
```
echo "st7789x panel=st7789" > /boot/fb
```

milkv_st7789v on spi3 of Milk-V DuoS:
```
echo "st7789x panel=st7789v_milkv" > /boot/fb
```

### Additional Packages
This image also adds the debian repository for board-related packages so you can install additional repositories. The debian repository is hosted at 
https://scpcom.github.io/deb which pulls down the compiled debian packages from the above github repository occasionally.

Available debian packages:

 - cvi-pinmux-cv181x  
 Contains a tool named cvi_pinmux which allows to change the function of the pins (GPIO, SPI etc.).
 - firmware-aic8800-cv181x  
 Firmware for the on-board WiFi.
 - firmware-vcodec-cv181x  
 Firmware for the video encoder/decoder running on the small C906 core.

…and board-specific packages like:

 - board-support-licheervnano-kvm  
 Meta package, installs all board-specific packages.
 - cvitek-fsbl-licheervnano  
 The boot loader (including opensbi and u-boot).
 - cvitek-middleware-licheervnano  
 Libs and samples for the ISP (vi/vo/venc/vdec etc.).
 - cvitek-middleware-dev-licheervnano  
 Headers for the ISP libs.
 - cvitek-osdrv-licheervnano-kvm  
 Additional kernel drivers (required for camera support etc.).
 - cvitek-tpusdk-licheervnano  
 Libs and samples for the TPU (AI)
 - device-key-licheervnano  
 Startup script that sets the Ethernet MAC address and hostname based on the hash off the device uuid.
 - duo-pinmux-duos  
 Same as cvi-pinmux but customized for Milk-V Duo series boards.
 - ethernet-leds-duos  
 Startup script to enable ethernet LED triggers.
 - gadget-nic-licheervnano  
 Startup script to setup USB Gadget NCM/RNDIS networking.
 - hciattach-uart-duos  
 Startup script to attach bluetooth to UART.
 - linux-headers-licheervnano-kvm  
 The kernel headers for the board.
 - linux-image-licheervnano-kvm  
 The kernel customized for the board.
 - load-systemko-licheervnano  
 Startup script that loads the additional drivers (see cvitek-osdrv-licheervnano-kvm).
 - maixapp-licheervnano  
 App(s) built with MaixCDK.
 - nanokvm-licheervnano  
 NanoKVM Server that provides the web interface to control your device.
 - sensor-config-licheervnano  
 Configuration files and parameters required to initialize the camera sensor.
 - usb-device-licheervnano  
 Startup script to setup USB gadget devices.
 - usb-switch-duos  
 Startup script to enable the USB switch.
 - wifi-builtin-licheervnano  
 Startup scripts to initialize the on-board WiFi.
 - zram-config-licheervnano  
 Scripts to setup compressed ZRAM devices for overlayfs and zswap.

The package names are depending on the board you are using (licheervnano, duo256 or duos) and the variant (kvm = NanoKVM, e = all others).
For example if you want the kernel for Milk-V Duo256 the package is called linux-image-duo256-e.

## Building the Image
To build a stock image with no modifications:
```
podman run --privileged -it --rm -v ./configs/:/configs -v ./image:/output ghcr.io/scpcom/sophgo-sg200x-debian:debian make BOARD=licheervnano image
```

Replace the licheervnano with the board you want to build for:
- duo256
- duos
- licheervnano
- oz64 (Pine64 Oz64; reuses the Duo S u-boot and boots with an Oz64
  device tree that enables the onboard AIC8800DC WiFi on XGPIOA[30])

If you want to create a image for the DuoS with EMMC, you can add "STORAGE_TYPE=emmc" to the make command:
```
podman run --privileged -it --rm -v ./configs/:/configs -v ./image:/output ghcr.io/scpcom/sophgo-sg200x-debian:debian make BOARD=duos STORAGE_TYPE=emmc image
```

If you want to create a image for the NanoKVM, you can add "VARIANT=kvm" to the make command:
```
podman run --privileged -it --rm -v ./configs/:/configs -v ./image:/output ghcr.io/scpcom/sophgo-sg200x-debian:debian make BOARD=licheervnano VARIANT=kvm image
```

The Docker image will build the image and place it in the image directory

### Faster, cached builds
The `docker run --rm` above throws the whole build tree away after every run,
so the kernel/osdrv/middleware/buildroot are re-cloned and re-compiled, the
rootfs is rebuilt and ~1 GB of cross-toolchains are re-downloaded. The
`build.sh` wrapper keeps that state in named volumes instead:

```
./build.sh BOARD=oz64 SECOND_CPU=arduino IMAGE_HOSTNAME=oz64-toad image
```

It is a thin wrapper around the same `builder` image and passes every argument
through to `make`. The cache volumes are:

| volume | mount | scope |
| --- | --- | --- |
| `sg200x-build-<board>-<variant>-<storage>-<second_cpu>-<arch>-<gitref>` | `/build` | per configuration |
| `sg200x-rootfs-<...>` | `/rootfs` | per configuration |
| `sg200x-host-tools` | `/host-tools` | shared (cross toolchains, plus a tarball cache in `/host-tools/dl`) |
| `sg200x-apt` | `/var/cache/apt` | shared |

Extra commands:

```
./build.sh --clean BOARD=oz64 image   # drop this config's build/rootfs (full rebuild)
./build.sh --purge BOARD=oz64 image   # also drop the shared toolchains + apt cache
./build.sh BOARD=oz64 image-clean     # redo just the rootfs/image assembly
./build.sh BOARD=oz64 linux-clean     # drop the kernel tree, then rebuild `image`
```

The make stamps do not track `IMAGE_HOSTNAME`/`WIFI_*` either, so `build.sh`
fingerprints the make variables and, for `image` builds, automatically prepends
`image-clean` when they change. That way each run bakes the configuration you
asked for (`oz64-nat` + `domenet`, or `oz64-toad` + `cs4250`) while still
reusing the compiled kernel/osdrv/middleware/buildroot. Force it with
`--refresh`, or disable it with `--no-refresh`.

Note: the make stamps do **not** track the contents of `configs/`, only their
prerequisites, so after editing a patch/DTS/addon you must drop the affected
stage (`image-clean`, `linux-clean`, `osdrv-clean`, `buildroot-clean`, ...) or
use `--clean`. Editing a Kconfig/defconfig or a kernel patch requires
`linux-clean`; adding/altering an addon requires `image-clean`. The cache
mainly avoids redoing the stages you did not touch.

### Build-time Configuration
The `oz64` target accepts a few optional make variables. They are written to
the FAT boot partition and read by the on-device init scripts, so they persist
across reboots without modifying the rootfs.

| Variable | Values | Effect |
| --- | --- | --- |
| `IMAGE_HOSTNAME` | e.g. `oz64-nat` | Sets the hostname exactly (`/boot/hostname`). |
| `IMAGE_HOSTNAME_PREFIX` | e.g. `oz64` | Sets the `<prefix>-<hash>` hostname prefix (`/boot/hostname.prefix`). |
| `WIFI_MODE` | `none`, `sta`, `ap` | WiFi mode at boot (default `none`). |
| `WIFI_SSID` / `WIFI_PASS` | strings | Credentials for `sta` mode. Leave `WIFI_PASS` empty for an **open** network (the interface is configured with `wpa-key-mgmt NONE`). |
| `WIFI_IPV4_PREFIX` | e.g. `10.42.0` | AP subnet prefix (`ap` mode only). |
| `WIFI_WPA_CONF` | path | `wpa_supplicant.conf` to bake in; implies `sta` and wires `wpa-conf` for you. Relative paths resolve under `/configs`. |
| `SECOND_CPU` | `camera`, `arduino` | Selects the C906L personality (`camera` default on `duos`, `arduino` default on `oz64`); see [Ardunio/Freertos Support](#arduniofreertos-support). |

When `IMAGE_HOSTNAME` is set, the two network interfaces advertise **distinct
DHCP/DNS names** so IPv4 and IPv6 stay unambiguous: ethernet keeps `<name>` and
WiFi uses `<name>-wifi` (e.g. `oz64-nat` and `oz64-nat-wifi`). IPv6 addresses
are made **deterministic** (`slaac hwaddr` + `duid ll`, derived from the
device-key MACs), so they stay stable across reboots/reflashes and the router's
DNS does not accumulate stale records. The mDNS name `<name>.local` is
unchanged.

Example - an Oz64 image that joins `cs4250` and is reachable as `oz64-nat`:
```
podman run --privileged -it --rm -v ./configs/:/configs -v ./image:/output ghcr.io/scpcom/sophgo-sg200x-debian:debian make BOARD=oz64 SECOND_CPU=arduino IMAGE_HOSTNAME=oz64-nat WIFI_MODE=sta WIFI_SSID=cs4250 WIFI_PASS=ultrasecure image
```

Open network (no `WIFI_PASS`):
```
make BOARD=oz64 WIFI_MODE=sta WIFI_SSID=domenet image
```

Access-point mode:
```
make BOARD=oz64 WIFI_MODE=ap WIFI_SSID=oz64 WIFI_PASS=oz64oz64 WIFI_IPV4_PREFIX=10.42.0 image
```

Bake in a full `wpa_supplicant.conf` (place it under `configs/oz64/`); this is
also the escape hatch for WPA3/enterprise or multiple networks:
```
make BOARD=oz64 WIFI_WPA_CONF=oz64/wpa_supplicant.conf image
```

WiFi credentials are stored in cleartext on the boot partition. As the values
pass through `make`, a literal `$` in a password must be written as `$$`.

addition make targets are available when building:
- image - builds the image
- clean - cleans the build directory
- linux - build a kernel debian package
- fsbl - build the fsbl debain package (that includes cvitek-fsbl, opensbi and u-boot)

## Customizing the Image
The configs directory contains patches, configuration and device tree files that are used to build the image.

The configs/common directory contains the common configuration for all boards, and the configs/licheervnano and configs/duo256 directories contain the board specific configuration.

To add packages to the image, either add the package name in PACKAGES variable of configs/settings.mk or if the packae is specific to a board, add it to the configs/\<board\>/settings.mk file

Patches for the kernel, opensbi, u-boot or fsbl can be placed in configs/common/patches/ or configs/\<board\>/patches/ depending what they are for.

To assist with developing the image, you can get a shell in the docker container by running:
```
docker run --privileged -it --rm -v ./configs/:/configs -v ./image:/output -v ./scripts/:/builder builder /bin/bash
```
inside the container, packages are build in the /builder/ directory, and the rootfs is placed at /rootfs/ directory

## ARM Images
If the A53 CPU core is enabled on your board you can build the matching arm64 images.

Use podman/docker run like described above and choose one of the supported boards:
```
make BOARD=duos ARCH=arm64 image
make BOARD=duo256 ARCH=arm64 image
make BOARD=licheea53nano ARCH=arm64 image
```
You can replace ARCH=arm64 with ARCH=arm to get 32 bit (armhf) images.

## Mirroring
If you want to get a copy of all required sources you can use the related scripts.

Get a local copy of all sources:
```
./scripts/mirror/do-clone.sh
```

Next you can push all sources to your git:
```
GIT_TARGET_HOST=git.example.dev GIT_TARGET_USER=yournamehere ./scripts/mirror/do-push.sh
```

You can re-run the push script to keep the repositories up-to-date.

Build Image by using your git:
```
make BOARD=licheervnano GIT_USER_URL=https://git.example.dev/yournamehere image
```

If you also provide an update server, a mirror of the release downloads (for MaixCDK pre-built python3) and the toolchains you can run:
```
make BOARD=licheervnano GIT_HOST=https://git.example.dev GIT_USER=yournamehere GIT_RELEASES_URL=https://downloads.example.dev/path/to/releases TOOLCHAIN_URL=https://downloads.example.dev/path/to/toolchain USER_SITE_URL=https://downloads.example.dev/path/to/updates image
```

# TODO
- DeviceTree Overlay Support
- Possibly mainline kernel support via the sophgo linux for-next repositories
