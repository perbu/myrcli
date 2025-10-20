.PHONY: build install clean release uninstall help

APP_NAME = myrcli
APP_BUNDLE = $(APP_NAME).app
INSTALL_PATH = /usr/local/bin/$(APP_NAME)

help:
	@echo "Available targets:"
	@echo "  make build     - Build release binary and create app bundle (default)"
	@echo "  make install   - Install to /usr/local/bin (requires sudo)"
	@echo "  make clean     - Remove build artifacts"
	@echo "  make release   - Build universal binary (arm64 + x86_64)"
	@echo "  make uninstall - Remove from /usr/local/bin (requires sudo)"

build:
	swift build -c release
	mkdir -p $(APP_BUNDLE)/Contents/MacOS/
	cp ./.build/release/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp Info.plist $(APP_BUNDLE)/Contents
	codesign --force --deep --sign - $(APP_BUNDLE)
	@echo "Build complete! Run with: ./$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"

release:
	swift build -c release --arch arm64 --arch x86_64
	mkdir -p $(APP_BUNDLE)/Contents/MacOS/
	cp ./.build/apple/Products/Release/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp Info.plist $(APP_BUNDLE)/Contents
	codesign --force --deep --sign - $(APP_BUNDLE)
	@echo "Universal binary build complete!"

install: build
	@echo "Installing to $(INSTALL_PATH) (requires sudo)..."
	sudo cp ./$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME) $(INSTALL_PATH)
	@echo "Installed! Run with: $(APP_NAME)"

uninstall:
	@echo "Removing $(INSTALL_PATH) (requires sudo)..."
	sudo rm -f $(INSTALL_PATH)
	@echo "Uninstalled."

clean:
	swift package clean
	rm -rf $(APP_BUNDLE)
	rm -rf .build

# Default target
.DEFAULT_GOAL := build
