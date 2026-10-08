$(BUILDDIR)/hciattach-uart-stamp:
	@echo "$(COLOUR_GREEN)Packaging hciattach systemd service for $(BOARD)$(END_COLOUR)"
	@$(eval HCIATTACHVERSION=$(shell echo "1.0.0"))
	@mkdir -p $(BUILDDIR)/package/hciattach-uart-$(BOARD)-$(HCIATTACHVERSION)
	@cp -r /builder/deb/hciattach-uart/* $(BUILDDIR)/package/hciattach-uart-$(BOARD)-$(HCIATTACHVERSION)/
	@mkdir -p $(BUILDDIR)/package/hciattach-uart-$(BOARD)-$(HCIATTACHVERSION)/etc/systemd/system/
	@cp -a addons/hciattach-service/hciattach.service $(BUILDDIR)/package/hciattach-uart-$(BOARD)-$(HCIATTACHVERSION)/etc/systemd/system/
	@sed -i 's/Architecture: riscv64/Architecture: $(DEB_ARCH)/' $(BUILDDIR)/package/hciattach-uart-$(BOARD)-$(HCIATTACHVERSION)/DEBIAN/control
	@sed -i 's/Version: 1.0.0/Version: $(HCIATTACHVERSION)/' $(BUILDDIR)/package/hciattach-uart-$(BOARD)-$(HCIATTACHVERSION)/DEBIAN/control
	@sed -i 's/Package: hciattach-uart/Package: hciattach-uart-$(BOARD)/' $(BUILDDIR)/package/hciattach-uart-$(BOARD)-$(HCIATTACHVERSION)/DEBIAN/control
	@cd $(BUILDDIR)/package/ && dpkg-deb --build hciattach-uart-$(BOARD)-$(HCIATTACHVERSION) hciattach-uart-$(BOARD)_$(HCIATTACHVERSION)_$(DEB_ARCH).deb
	@cp $(BUILDDIR)/package/hciattach-uart-$(BOARD)_$(HCIATTACHVERSION)_$(DEB_ARCH).deb /output/
	@mkdir -p /rootfs/tmp/install/
	@cp /output/hciattach-uart-$(BOARD)_$(HCIATTACHVERSION)_$(DEB_ARCH).deb /rootfs/tmp/install/
	@echo "$(COLOUR_GREEN)Installing hciattach systemd service for $(BOARD)$(END_COLOUR)"
	@mkdir -p /rootfs/tmp/install/
	@echo " hciattach bluetooth" >> /rootfs/tmp/install/systemd-enable
	@touch $@
