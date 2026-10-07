# Fix: restore C906L remoteproc support (Arduino / FreeRTOS image)

Status: **fixed and verified on hardware (2026-10-06).**
Applies to: `BOARD=oz64 SECOND_CPU=arduino` (default) and
`BOARD=duos SECOND_CPU=arduino`.

## TL;DR

The image built `CONFIG_CVITEK_REMOTEPROC=m` and carried all the
mailbox/remoteproc/rpmsg patches, but the **device tree no longer described the
C906L**, so the driver probed nothing and there was no
`/sys/class/remoteproc/remoteproc0`. The regression came from commit
`9dc5f70` ("duos: dts: sync with duo-buildroot-sdk-v2", Feb 2025), which
switched the Duo S/Oz64 DTS to the vendor `soph_default_memmap.dtsi` and deleted
the `mbox` and `cv181x-c906_1` nodes.

Fix: `copy_dts_action` (configs/chip/sg200x/chip.mk) now appends
`configs/common/dts/cv181x/arduino-rproc.dtsi` to the board DTS when
`SECOND_CPU=arduino`. The fragment is `#ifndef __UBOOT__`-guarded, so the
u-boot/OpenSBI DTB is byte-identical to the camera personality.

## What was wrong

On the shipped Oz64 image (`SECOND_CPU=arduino`, DTB md5
`dbc156984c2ccd418ddf95aeb1ad5836`) `/proc/device-tree` had `fast_image`
(`compatible = "cvitek,rtos_image"`), `rtos_cmdqu` and
`reserved-memory/{ion,mmode_resv0}` — but **no `cv181x-c906_1` and no mailbox
node**, so `cvitek_rproc_match[] = { "cvitek,cv181x-c906_1" }` never matched.
The modules (`cvitek_remoteproc.ko`, `cvitek-mailbox.ko`) were present and
`cvitek_mailbox` would load, but bind to nothing.

The `settings.mk` comment that `SECOND_CPU=arduino` leaves the C906L "free for
the remoteproc driver" was only half true: it frees the core (`ION_SIZE=0`) but
the DTS was never restored.

## The fix

### `configs/common/dts/cv181x/arduino-rproc.dtsi` (new, shared)

`copy_dts_action` already copies `/configs/common/dts/$(CHIP)/*` into every
cv181x kernel and u-boot DTS directory, so one file covers oz64 and duos. It is
only *included* when the gate below runs, and it expands to nothing for u-boot.

It adds, under `/reserved-memory`:
`rproc@9fe00000` (`CVIMMAP_FREERTOS_ADDR/SIZE`, `no-map`) plus
`vdev0vring0/vdev0vring1/vdev0buffer` at `0x8f528000/0x8f52C000/0x8f530000`
(as set by `88d97d3`), and at the root: the `mbox@0x01900000`
(`cvitek,sg200x-mailbox`) and `cv181x-c906_1` nodes from the pre-`9dc5f70` DTS
(`memory-region`, `mboxes`, `resets = <&rst RST_C906_1>`,
`clocks = <&clk CV181X_CLK_C906_1>`, `firmware = "c906-mcu.elf"`).

**Why not reuse the existing `fast_image` node?** In the pinned kernel's
`soph_default_memmap.dtsi`, `fast_image` is a **root** node, not a child of
`/reserved-memory`. `cvitek_remoteproc` resolves `memory-region` with
`of_reserved_mem_lookup()` (patch 0003), which only sees `/reserved-memory`
children, so the fragment declares its own carveout.

**Why not swap the memmap include** (the original notes' preferred option)?
`copy_dts_action` feeds the same board DTS to u-boot (chip.mk:713) and
`u-boot.dtb` is embedded into OpenSBI (`FW_FDT_PATH`, chip.mk:790). Swapping
the include would change the bootloader artifact and could not be validated
without a full reflash. The additive fragment leaves u-boot untouched.

### `configs/chip/sg200x/chip.mk`

- `copy_dts_action`: when `SECOND_CPU=arduino`, append
  `#include "arduino-rproc.dtsi"` after `soph_default_memmap.dtsi` in
  `cv181x_milkv_duos_{sd,emmc}.dts`. Idempotent, and fail-loud if the expected
  memmap include is ever renamed.
- `toolchain-prepare-patch-stamp`: `mkdir -p $(BUILDDIR)` so `make linux` /
  `make dtbs` can be run directly (only `make image` used to create `/build`).
- New `make dtbs` target: builds only the DTBs (no kernel compile) and copies
  them to `/output` — used for the on-board validation below.

### `configs/duos/settings.mk`

Added the same `SECOND_CPU ?= camera` switch as oz64 (`ION_SIZE=0` and no panel
tuning for `arduino`; the existing `ION_SIZE=74`/panel tuning are now the
`camera` branch). Default is unchanged (`camera`). `duos_arm64` is not handled.

## Verified on hardware

Built the kernel DTB only and dropped it into
`/boot/fdt/linux-image-…+oz64/cvitek/cv181x_milkv_duos_sd.dtb` (md5
`8ea4f0c7463b481515b7d1d7074ab540`), then rebooted the Oz64:

```
$ ls /proc/device-tree | grep -E 'c906|mbox'
cv181x-c906_1
mbox@0x01900000
$ ls /proc/device-tree/reserved-memory
ion  mmode_resv0@80000000  rproc@9fe00000  vdev0buffer  vdev0vring0  vdev0vring1
$ sudo modprobe cvitek_remoteproc
$ ls /sys/class/remoteproc/
remoteproc0 -> .../platform/cv181x-c906_1/remoteproc/remoteproc0
$ cat /sys/class/remoteproc/remoteproc0/{name,state,firmware}
cv181x-c906_1
offline
c906-mcu.elf
```

End-to-end start with the ELF already present on the board
(`/lib/firmware/oled-bitbang.elf`, entry `0x9fe00000`, matches the carveout):

```
$ echo oled-bitbang.elf > /sys/class/remoteproc/remoteproc0/firmware
$ echo start > /sys/class/remoteproc/remoteproc0/state
$ cat /sys/class/remoteproc/remoteproc0/state
running
$ lsmod | grep cvitek_mailbox
cvitek_mailbox  8798  2        # both mbox channels requested
$ dmesg | grep -i c906
remoteproc remoteproc0: powering up cv181x-c906_1
remoteproc remoteproc0: Booting fw image oled-bitbang.elf, size 94408
cvitek-mailbox 1900000.mbox: Channel 1: direction 1, cpu 2, mask 1
cvitek-mailbox 1900000.mbox: Channel 0: direction 2, cpu 2, mask 1
remoteproc remoteproc0: Started from 0x9fe00000
remoteproc remoteproc0: remote processor cv181x-c906_1 is now up
```

The benign `Allocated carveout doesn't fit device address request` warning is
the remoteproc ELF loader running before `parse_fw` registers the carveouts; it
also occurred with the historical known-good layout. `echo stop` returns the
core to `offline`.

The build gate was checked against pristine copies: `camera` adds the include
0 times, `arduino` 1 time (idempotent on re-run), for both oz64 and duos.

## Validating a DTB change without an image rebuild

```sh
# from the repo root (builds only the DTBs, no kernel compile)
docker run --privileged --rm -v "$PWD/configs":/configs -v "$PWD/image":/output \
  builder make BOARD=oz64 SECOND_CPU=arduino dtbs
# then back up, scp the .dtb into /boot/fdt/<linux-image>/cvitek/ on the board,
# sync, reboot. Keep the original as <file>.dtb.orig for recovery (the /boot vfat
# partition can be restored from another machine if the kernel fails to boot).
```

## Caveats

- **Camera personality unchanged.** The fragment is only added when
  `SECOND_CPU=arduino`; camera uses `ION_SIZE=74` and the vendor memmap. The two
  are mutually exclusive: one C906L core, one `fast_image`/FreeRTOS window.
- **u-boot untouched.** The fragment is `#ifndef __UBOOT__`-guarded and u-boot's
  DTC cpp flags define `__UBOOT__` (u-boot `scripts/Makefile.lib:194`).
- **Remoteproc is not auto-started** and no firmware is shipped. Put the ELF in
  `/lib/firmware/` and `echo start > …/state` (or add a unit).
- **duos** is build-time-verified only (no Duo S hardware on hand). `duo256` is
  not covered (256 MB; the vdev addresses would need a re-check).
- **Caching:** the `linux-*`/`uboot-*` prepare stamps are not persona-aware, so a
  cached `/build` reused across `SECOND_CPU` values would skip the DTS patching.
  The standard flow (`docker run --rm`, no `/build` volume) rebuilds from
  scratch, so this does not bite in practice.

## References

- Regression: `9dc5f70` "duos: dts: sync with duo-buildroot-sdk-v2".
- Vring addresses: `88d97d3` "Fixup uboot addresses, and adjust remoteproc vrings".
- Driver patches: `configs/chip/sg200x/patches/linux/0001..0004`.
- Shared fragment: `configs/common/dts/cv181x/arduino-rproc.dtsi`.
- Gate / `dtbs`: `configs/chip/sg200x/chip.mk` (`copy_dts_action`).
- Runtime reference: `sg2000-hints/hints/fishwaldo-arduino.md`.
