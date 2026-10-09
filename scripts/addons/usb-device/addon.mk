ifneq ("$(findstring usb-device,$(IMAGE_ADDITIONS))","")
BSPDEPENDS += usb-device-$(BOARD_EXT)
BSPFILTER += "usb-device"
endif

$(BUILDDIR)/usb-device-stamp: $(BUILDDIR)/buildroot-prepare-checkout-stamp
	@echo "$(COLOUR_GREEN)Packaging usb-device for $(BOARD)$(END_COLOUR)"
	@$(eval USBDEVVERSION=$(shell echo "1.0.0"))
	@$(eval BV=$(shell cd $(BUILDDIR)/buildroot && git log -1 --format="%at" | xargs -I{} date -d @{} +-%Y%m%d-${KERNELREV}))
	@mkdir -p $(BUILDDIR)/package/usb-device-$(BOARD_EXT)-$(USBDEVVERSION)
	@cp -r /builder/deb/usb-device/* $(BUILDDIR)/package/usb-device-$(BOARD_EXT)-$(USBDEVVERSION)/
	@mkdir -pv $(BUILDDIR)/package/usb-device-$(BOARD_EXT)-$(USBDEVVERSION)/etc/init.d/
	@if [ "X$(findstring kvm,$(VARIANT))" = "X" ]; then \
		cp -a addons/usb-device/S03usbdev $(BUILDDIR)/package/usb-device-$(BOARD_EXT)-$(USBDEVVERSION)/etc/init.d/ ; \
	else \
		cp -a addons/nanokvm/S03usbdev $(BUILDDIR)/package/usb-device-$(BOARD_EXT)-$(USBDEVVERSION)/etc/init.d/ ; \
	fi
	@chmod +x $(BUILDDIR)/package/usb-device-$(BOARD_EXT)-$(USBDEVVERSION)/etc/init.d/S03usbdev
	@mkdir -pv $(BUILDDIR)/package/usb-device-$(BOARD_EXT)-$(USBDEVVERSION)/etc/systemd/system/
	@cp -a addons/usb-device/usb-device*.service $(BUILDDIR)/package/usb-device-$(BOARD_EXT)-$(USBDEVVERSION)/etc/systemd/system/
	@sed -i 's/Architecture: riscv64/Architecture: $(DEB_ARCH)/' $(BUILDDIR)/package/usb-device-$(BOARD_EXT)-$(USBDEVVERSION)/DEBIAN/control
	@sed -i 's/Version: 1.0.0/Version: $(USBDEVVERSION)$(BV)/' $(BUILDDIR)/package/usb-device-$(BOARD_EXT)-$(USBDEVVERSION)/DEBIAN/control
	@sed -i 's/Package: usb-device/Package: usb-device-$(BOARD_EXT)/' $(BUILDDIR)/package/usb-device-$(BOARD_EXT)-$(USBDEVVERSION)/DEBIAN/control
	@if [ "$(BOARD)" = "$(BOARD_EXT)" ]; then \
		sed -i '/Provides: .*/d' $(BUILDDIR)/package/usb-device-$(BOARD_EXT)-$(USBDEVVERSION)/DEBIAN/control && \
		sed -i '/Replaces: .*/d' $(BUILDDIR)/package/usb-device-$(BOARD_EXT)-$(USBDEVVERSION)/DEBIAN/control ; \
	else \
		sed -i 's/Provides: .*/Provides: usb-device-$(BOARD)/' $(BUILDDIR)/package/usb-device-$(BOARD_EXT)-$(USBDEVVERSION)/DEBIAN/control && \
		sed -i 's/Replaces: .*/Replaces: usb-device-$(BOARD)/' $(BUILDDIR)/package/usb-device-$(BOARD_EXT)-$(USBDEVVERSION)/DEBIAN/control ; \
	fi
	@cd $(BUILDDIR)/package/ && dpkg-deb --build usb-device-$(BOARD_EXT)-$(USBDEVVERSION) usb-device-$(BOARD_EXT)_$(USBDEVVERSION)$(BV)_$(DEB_ARCH).deb
	@cp $(BUILDDIR)/package/usb-device-$(BOARD_EXT)_$(USBDEVVERSION)$(BV)_$(DEB_ARCH).deb /output/
	@mkdir -p /rootfs/tmp/install/
	@cp /output/usb-device-$(BOARD_EXT)_$(USBDEVVERSION)$(BV)_$(DEB_ARCH).deb /rootfs/tmp/install/
	@echo "$(COLOUR_GREEN)Installing usb-device for $(BOARD)$(END_COLOUR)"
	@mkdir -pv /rootfs/boot/
	@touch /rootfs/boot/usb.dev
	@mkdir -p /rootfs/tmp/install/
	@echo " usb-device" >> /rootfs/tmp/install/systemd-enable
	@touch $@
