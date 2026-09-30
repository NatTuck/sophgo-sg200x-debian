KERNELREV="7"
BSPVERSION=1.0.80

# Build-time image personalisation. All are optional; when unset the image
# keeps its stock behaviour. Pass them on the make command line, e.g.
#   make BOARD=oz64 IMAGE_HOSTNAME=oz64-nat WIFI_MODE=sta \
#        WIFI_SSID=cs4250 WIFI_PASS=ultrasecure SECOND_CPU=arduino image
#
# IMAGE_HOSTNAME        exact hostname, persisted in /boot/hostname
# IMAGE_HOSTNAME_PREFIX prefix for the default <prefix>-<hash> hostname
# WIFI_MODE             none (default) | sta (WiFi client) | ap (access point)
# WIFI_SSID / WIFI_PASS credentials for sta/ap mode; leave WIFI_PASS empty
#                       for an open station network (emits wpa-key-mgmt NONE)
# WIFI_IPV4_PREFIX      AP subnet prefix, e.g. 10.0.0 (ap mode only)
# WIFI_WPA_CONF         wpa_supplicant.conf to bake in (implies sta mode);
#                       a path relative to /configs or an absolute path
IMAGE_HOSTNAME ?=
IMAGE_HOSTNAME_PREFIX ?=
WIFI_MODE ?= none
WIFI_SSID ?=
WIFI_PASS ?=
WIFI_IPV4_PREFIX ?=
WIFI_WPA_CONF ?=

PACKAGES="busybox-static ca-certificates debian-archive-keyring dosfstools binutils file tree sudo bash-completion u-boot-menu openssh-server dnsmasq-base libpam-systemd ppp libatomic1 libgomp1 libengine-pkcs11-openssl iptables lldpd locales locales-all picocom psmisc vim usbutils parted exfatprogs systemd-sysv i2c-tools net-tools ifupdown arp-scan cron ethtool avahi-utils gnupg rsync u-boot-tools libubootenv-tool bc curl fake-hwclock lzip python3-requests unzip wget"
ifeq ("$(findstring ubuntu,$(DEB_URL))","")
PACKAGES += " chrony"
endif
ifeq ("$(findstring kvm,$(VARIANT))","")
PACKAGES += " network-manager"
endif

IMAGE_ADDITIONS="gadget-nic"
IMAGE_ADDITIONS += "preconfigure"
