ifneq ("$(findstring wifi-builtin,$(IMAGE_ADDITIONS))","")
BSPDEPENDS += wifi-builtin-$(BOARD_EXT)
BSPFILTER += "wifi-builtin"
endif

$(BUILDDIR)/wifi-builtin-stamp: $(BUILDDIR)/buildroot-prepare-checkout-stamp
	@echo "$(COLOUR_GREEN)Packaging wifi-builtin for $(BOARD)$(END_COLOUR)"
	@$(eval WIFIBIVERSION=$(shell echo "1.0.0"))
	@$(eval BV=$(shell cd $(BUILDDIR)/buildroot && git log -1 --format="%at" | xargs -I{} date -d @{} +-%Y%m%d-${KERNELREV}))
	@mkdir -p $(BUILDDIR)/package/wifi-builtin-$(BOARD_EXT)-$(WIFIBIVERSION)
	@cp -r /builder/deb/wifi-builtin/* $(BUILDDIR)/package/wifi-builtin-$(BOARD_EXT)-$(WIFIBIVERSION)/
	@mkdir -pv $(BUILDDIR)/package/wifi-builtin-$(BOARD_EXT)-$(WIFIBIVERSION)/etc/init.d/
	@cp -a addons/wifi-builtin/S28wifimac $(BUILDDIR)/package/wifi-builtin-$(BOARD_EXT)-$(WIFIBIVERSION)/etc/init.d/
	@chmod +x $(BUILDDIR)/package/wifi-builtin-$(BOARD_EXT)-$(WIFIBIVERSION)/etc/init.d/S28wifimac
	@if [ "X$(findstring kvm,$(VARIANT))" = "X" ]; then \
		cp -a addons/wifi-builtin/S30wifi $(BUILDDIR)/package/wifi-builtin-$(BOARD_EXT)-$(WIFIBIVERSION)/etc/init.d/ ; \
	else \
		cp -a addons/nanokvm/S30wifi $(BUILDDIR)/package/wifi-builtin-$(BOARD_EXT)-$(WIFIBIVERSION)/etc/init.d/ ; \
	fi
	@chmod +x $(BUILDDIR)/package/wifi-builtin-$(BOARD_EXT)-$(WIFIBIVERSION)/etc/init.d/S30wifi
	@mkdir -pv $(BUILDDIR)/package/wifi-builtin-$(BOARD_EXT)-$(WIFIBIVERSION)/etc/systemd/system/
	@cp -a addons/wifi-builtin/wifi-builtin*.service $(BUILDDIR)/package/wifi-builtin-$(BOARD_EXT)-$(WIFIBIVERSION)/etc/systemd/system/
	@cp -a addons/wifi-builtin/wifi-hostapd*.service $(BUILDDIR)/package/wifi-builtin-$(BOARD_EXT)-$(WIFIBIVERSION)/etc/systemd/system/
	@cp -a addons/wifi-builtin/wifi-mac*.service $(BUILDDIR)/package/wifi-builtin-$(BOARD_EXT)-$(WIFIBIVERSION)/etc/systemd/system/
	@sed -i 's/Architecture: riscv64/Architecture: $(DEB_ARCH)/' $(BUILDDIR)/package/wifi-builtin-$(BOARD_EXT)-$(WIFIBIVERSION)/DEBIAN/control
	@sed -i 's/Version: 1.0.0/Version: $(WIFIBIVERSION)$(BV)/' $(BUILDDIR)/package/wifi-builtin-$(BOARD_EXT)-$(WIFIBIVERSION)/DEBIAN/control
	@sed -i 's/Package: wifi-builtin/Package: wifi-builtin-$(BOARD_EXT)/' $(BUILDDIR)/package/wifi-builtin-$(BOARD_EXT)-$(WIFIBIVERSION)/DEBIAN/control
	@if [ "$(BOARD)" = "$(BOARD_EXT)" ]; then \
		sed -i '/Provides: .*/d' $(BUILDDIR)/package/wifi-builtin-$(BOARD_EXT)-$(WIFIBIVERSION)/DEBIAN/control && \
		sed -i '/Replaces: .*/d' $(BUILDDIR)/package/wifi-builtin-$(BOARD_EXT)-$(WIFIBIVERSION)/DEBIAN/control ; \
	else \
		sed -i 's/Provides: .*/Provides: wifi-builtin-$(BOARD)/' $(BUILDDIR)/package/wifi-builtin-$(BOARD_EXT)-$(WIFIBIVERSION)/DEBIAN/control && \
		sed -i 's/Replaces: .*/Replaces: wifi-builtin-$(BOARD)/' $(BUILDDIR)/package/wifi-builtin-$(BOARD_EXT)-$(WIFIBIVERSION)/DEBIAN/control ; \
	fi
	@cd $(BUILDDIR)/package/ && dpkg-deb --build wifi-builtin-$(BOARD_EXT)-$(WIFIBIVERSION) wifi-builtin-$(BOARD_EXT)_$(WIFIBIVERSION)$(BV)_$(DEB_ARCH).deb
	@cp $(BUILDDIR)/package/wifi-builtin-$(BOARD_EXT)_$(WIFIBIVERSION)$(BV)_$(DEB_ARCH).deb /output/
	@mkdir -p /rootfs/tmp/install/
	@cp /output/wifi-builtin-$(BOARD_EXT)_$(WIFIBIVERSION)$(BV)_$(DEB_ARCH).deb /rootfs/tmp/install/
	@echo "$(COLOUR_GREEN)Installing wifi-builtin for $(BOARD)$(END_COLOUR)"
	@mkdir -pv /rootfs/etc/network/interfaces.d/
	@cp -a addons/wifi-builtin/wlan0 /rootfs/etc/network/interfaces.d/
	@mkdir -p /rootfs/tmp/install/
	@echo " wifi-builtin" >> /rootfs/tmp/install/systemd-enable
	@echo " wifi-builtin-wlan0.service" >> /rootfs/tmp/install/systemd-enable
	@echo " wifi-hostapd-wlan0.service" >> /rootfs/tmp/install/systemd-enable
	@[ "$(BOARD)" = "licheervnano" -o "$(BOARD)" = "licheea53nano" ] || echo " wifi-mac" >> /rootfs/tmp/install/systemd-enable
	@touch $@
