CHIP=cv181x
STORAGE_TYPE?=sd
VARIANT?=e
UBOOT_CHIP=cv181x
UBOOT_BOARD=milkv_duos_$(STORAGE_TYPE)
BOOT_CPU=riscv
ARCH=riscv
DDR_CFG=ddr3_1866_x16

# The SG2000 has a single small C906L core. It can either run the vendor ISP
# (camera/VPSS/VENC) or be handed to a user FreeRTOS/Arduino image through the
# kernel remoteproc driver - not both. Select one at build time. This changes
# the memory map, so the two personalities are separate full image builds.
SECOND_CPU ?= camera

ifeq ($(SECOND_CPU),camera)
ION_SIZE=74
PANEL_TUNING_DEFAULT?=MIPI_panel_milkv_8hd
PANEL_TUNING_EXTRA?=MIPI_panel_milkv_8hd_2lane MIPI_panel_milkv_st7796s
else ifeq ($(SECOND_CPU),arduino)
# ION_SIZE=0 makes chip.mk zero the ISP/H26X/bootlogo regions and
# load-systemko's S00kmod then skips every ISP/vcodec module, leaving the
# C906L free for the remoteproc driver.
ION_SIZE=0
PANEL_TUNING_DEFAULT=
PANEL_TUNING_EXTRA=
else
$(error SECOND_CPU must be 'camera' or 'arduino' (got '$(SECOND_CPU)'))
endif

PARTITION_FILE=partition_$(STORAGE_TYPE).xml

PACKAGES += " cvi-pinmux-cv181x hostapd udhcpd wireless-regdb wpasupplicant bluez"

IMAGE_ADDITIONS += "duo-pinmux"
IMAGE_ADDITIONS += "sensor-config"
IMAGE_ADDITIONS += "device-key"
IMAGE_ADDITIONS += "ethernet-builtin"
IMAGE_ADDITIONS += "load-systemko"
IMAGE_ADDITIONS += "tpusdk"
IMAGE_ADDITIONS += "usb-device"
IMAGE_ADDITIONS += "wifi-builtin"
IMAGE_ADDITIONS += "aic8800-firmware"
IMAGE_ADDITIONS += "ethernet-leds"
IMAGE_ADDITIONS += "usb-switch"
IMAGE_ADDITIONS += "hciattach-uart"