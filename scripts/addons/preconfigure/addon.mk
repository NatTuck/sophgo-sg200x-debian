ifneq ("$(findstring preconfigure,$(IMAGE_ADDITIONS))","")
BSPFILTER += "preconfigure"
endif

# device-key writes a default /boot/hostname.prefix; make sure the explicit
# build-time value (if any) lands last.
ifneq ("$(findstring device-key,$(IMAGE_ADDITIONS))","")
$(BUILDDIR)/preconfigure-stamp: $(BUILDDIR)/device-key-stamp
endif

$(BUILDDIR)/preconfigure-stamp:
	@echo "$(COLOUR_GREEN)Preconfiguring image for $(BOARD)$(END_COLOUR)"
	@mkdir -p /rootfs/boot
	@if [ -n "$(IMAGE_HOSTNAME)" ]; then \
		printf '%s\n' '$(IMAGE_HOSTNAME)' > /rootfs/boot/hostname ; \
		echo "  hostname: $(IMAGE_HOSTNAME)" ; \
	fi
	@if [ -n "$(IMAGE_HOSTNAME_PREFIX)" ]; then \
		printf '%s\n' '$(IMAGE_HOSTNAME_PREFIX)' > /rootfs/boot/hostname.prefix ; \
		echo "  hostname prefix: $(IMAGE_HOSTNAME_PREFIX)" ; \
	fi
	@if [ -n "$(IMAGE_HOSTNAME)$(IMAGE_HOSTNAME_PREFIX)" ] && [ -f /rootfs/etc/dhcpcd.conf ]; then \
		conf=/rootfs/etc/dhcpcd.conf ; \
		sed -i -E 's/^slaac[[:space:]]+private.*/slaac hwaddr/' $$conf ; \
		sed -i -E 's/^duid[[:space:]]*$$/duid ll/' $$conf ; \
		grep -qE '^slaac[[:space:]]+hwaddr' $$conf || printf 'slaac hwaddr\n' >> $$conf ; \
		grep -qE '^duid[[:space:]]+ll' $$conf || printf 'duid ll\n' >> $$conf ; \
		grep -q '^nohook hostname' $$conf || printf 'nohook hostname\n' >> $$conf ; \
		echo "  deterministic IPv6: slaac hwaddr + duid ll" ; \
	fi
	@if [ -n "$(IMAGE_HOSTNAME)" ] && [ -f /rootfs/etc/dhcpcd.conf ]; then \
		printf '\n# %s: WiFi advertises its own DHCP hostname; ethernet keeps the base name\ninterface wlan0\n\thostname %s-wifi\n' "$(BOARD)" "$(IMAGE_HOSTNAME)" >> /rootfs/etc/dhcpcd.conf ; \
		echo "  wifi DHCP hostname: $(IMAGE_HOSTNAME)-wifi" ; \
	fi
	@case "$(WIFI_MODE)" in \
		none|"") : ;; \
		sta) \
			touch /rootfs/boot/wifi.sta ; \
			[ -z "$(WIFI_SSID)" ] || printf '%s\n' '$(WIFI_SSID)' > /rootfs/boot/wifi.ssid ; \
			[ -z "$(WIFI_PASS)" ] || printf '%s\n' '$(WIFI_PASS)' > /rootfs/boot/wifi.pass ; \
			echo "  wifi mode: sta" ;; \
		ap) \
			touch /rootfs/boot/wifi.ap ; \
			[ -z "$(WIFI_SSID)" ] || printf '%s\n' '$(WIFI_SSID)' > /rootfs/boot/wifi.ssid ; \
			[ -z "$(WIFI_PASS)" ] || printf '%s\n' '$(WIFI_PASS)' > /rootfs/boot/wifi.pass ; \
			[ -z "$(WIFI_IPV4_PREFIX)" ] || printf '%s\n' '$(WIFI_IPV4_PREFIX)' > /rootfs/boot/wifi.ipv4_prefix ; \
			echo "  wifi mode: ap" ;; \
		*) \
			echo "ERROR: WIFI_MODE must be none, sta or ap (got '$(WIFI_MODE)')" >&2 ; \
			exit 1 ;; \
	esac
	@if [ -n "$(WIFI_WPA_CONF)" ]; then \
		src="$(WIFI_WPA_CONF)" ; \
		[ -e "$$src" ] || src="/configs/$$src" ; \
		if [ ! -e "$$src" ]; then \
			echo "ERROR: WIFI_WPA_CONF '$(WIFI_WPA_CONF)' not found" >&2 ; \
			exit 1 ; \
		fi ; \
		cp -a "$$src" /rootfs/boot/wpa_supplicant.conf ; \
		touch /rootfs/boot/wifi.sta ; \
		echo "  wpa_supplicant.conf: $(WIFI_WPA_CONF)" ; \
	fi
	@if [ "$(SECOND_CPU)" = "arduino" ]; then \
		touch /rootfs/boot/arduino ; \
		echo "  second cpu: arduino (C906L left for remoteproc)" ; \
	fi
	@touch $@
