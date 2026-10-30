APP := PRFlow.app
BIN := .build/release/PRFlow
RES := $(APP)/Contents/Resources
ICONSET := /tmp/PRFlow.iconset

.PHONY: build run clean

build:
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	mkdir -p $(RES)
	cp $(BIN) $(APP)/Contents/MacOS/PRFlow
	cp Info.plist $(APP)/Contents/Info.plist
	@if [ -f Assets/app-icon.png ]; then \
		rm -rf $(ICONSET) && mkdir -p $(ICONSET); \
		for sz in 16 32 128 256 512; do \
			sips -z $$sz $$sz Assets/app-icon.png --out $(ICONSET)/icon_$${sz}x$${sz}.png >/dev/null; \
			sips -z $$((sz*2)) $$((sz*2)) Assets/app-icon.png --out $(ICONSET)/icon_$${sz}x$${sz}@2x.png >/dev/null; \
		done; \
		iconutil -c icns $(ICONSET) -o $(RES)/AppIcon.icns; \
		echo "  AppIcon.icns"; \
	fi
	@for f in menubar-icon glyph-glass; do \
		if [ -f Assets/$$f.png ]; then cp Assets/$$f.png $(RES)/; echo "  $$f.png"; fi; \
	done
	codesign --force --sign - $(APP) 2>/dev/null || true
	@echo "Built $(APP)"

run: build
	open $(APP)

clean:
	rm -rf .build $(APP)
