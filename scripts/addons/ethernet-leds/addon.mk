$(BUILDDIR)/ethernet-leds-stamp:
	@echo "$(COLOUR_GREEN)Packaging ethernet leds for $(BOARD)$(END_COLOUR)"
	@$(eval ETHLEDSVERSION=$(shell echo "1.0.0"))
	@mkdir -p $(BUILDDIR)/package/ethernet-leds-$(BOARD)-$(ETHLEDSVERSION)
	@cp -r /builder/deb/ethernet-leds/* $(BUILDDIR)/package/ethernet-leds-$(BOARD)-$(ETHLEDSVERSION)/
	@mkdir -p $(BUILDDIR)/package/ethernet-leds-$(BOARD)-$(ETHLEDSVERSION)/etc/systemd/system/
	@cp -a addons/ethernet-leds/ethernet-leds.service $(BUILDDIR)/package/ethernet-leds-$(BOARD)-$(ETHLEDSVERSION)/etc/systemd/system/
	@sed -i 's/Architecture: riscv64/Architecture: $(DEB_ARCH)/' $(BUILDDIR)/package/ethernet-leds-$(BOARD)-$(ETHLEDSVERSION)/DEBIAN/control
	@sed -i 's/Version: 1.0.0/Version: $(ETHLEDSVERSION)/' $(BUILDDIR)/package/ethernet-leds-$(BOARD)-$(ETHLEDSVERSION)/DEBIAN/control
	@sed -i 's/Package: ethernet-leds/Package: ethernet-leds-$(BOARD)/' $(BUILDDIR)/package/ethernet-leds-$(BOARD)-$(ETHLEDSVERSION)/DEBIAN/control
	@cd $(BUILDDIR)/package/ && dpkg-deb --build ethernet-leds-$(BOARD)-$(ETHLEDSVERSION) ethernet-leds-$(BOARD)_$(ETHLEDSVERSION)_$(DEB_ARCH).deb
	@cp $(BUILDDIR)/package/ethernet-leds-$(BOARD)_$(ETHLEDSVERSION)_$(DEB_ARCH).deb /output/
	@mkdir -p /rootfs/tmp/install/
	@cp /output/ethernet-leds-$(BOARD)_$(ETHLEDSVERSION)_$(DEB_ARCH).deb /rootfs/tmp/install/
	@echo "$(COLOUR_GREEN)Installing ethernet leds for $(BOARD)$(END_COLOUR)"
	@mkdir -p /rootfs/tmp/install/
	@echo " ethernet-leds" >> /rootfs/tmp/install/systemd-enable
	@touch $@
