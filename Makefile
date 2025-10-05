# Makefile for the ai_plugins Swift project

# Define the project name and directories
PROJECT_NAME = ai_plugins
BUILD_DIR = .build
RELEASE_BUILD_DIR = build/release

# Default target: build the project for debugging
all: build

# Build the Swift project for debugging
build:
	@echo "Building $(PROJECT_NAME) for debug..."
	swift build

# Run the application from the command line (builds if necessary)
run:
	@echo "Running $(PROJECT_NAME)..."
	open $(BUILD_DIR)/debug/$(PROJECT_NAME)

# Create a universal release build and package the .app bundle
archive:
	@echo "Archiving $(PROJECT_NAME) for release..."
	@echo "The final app will be located in the $(RELEASE_BUILD_DIR) directory."
	swift build -c release --arch arm64 --arch x86_64
	@mkdir -p $(RELEASE_BUILD_DIR)
	@cp -R $(BUILD_DIR)/apple/Products/Release/$(PROJECT_NAME).app $(RELEASE_BUILD_DIR)/

# Install the application to /Applications
install: build
	@echo "Installing $(PROJECT_NAME) to /Applications..."
	@if [ -d "/Applications/$(PROJECT_NAME).app" ]; then \
		echo "Removing existing $(PROJECT_NAME).app from /Applications..."; \
		rm -rf "/Applications/$(PROJECT_NAME).app"; \
	fi
	@echo "Creating $(PROJECT_NAME).app bundle..."
	@mkdir -p "/Applications/$(PROJECT_NAME).app/Contents/MacOS"
	@mkdir -p "/Applications/$(PROJECT_NAME).app/Contents/Resources"
	@cp $(BUILD_DIR)/debug/$(PROJECT_NAME) "/Applications/$(PROJECT_NAME).app/Contents/MacOS/"
	@if [ -d "$(BUILD_DIR)/debug/$(PROJECT_NAME)_$(PROJECT_NAME).bundle" ]; then \
		cp -R $(BUILD_DIR)/debug/$(PROJECT_NAME)_$(PROJECT_NAME).bundle "/Applications/$(PROJECT_NAME).app/Contents/Resources/"; \
	fi
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > "/Applications/$(PROJECT_NAME).app/Contents/Info.plist"
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> "/Applications/$(PROJECT_NAME).app/Contents/Info.plist"
	@echo '<plist version="1.0">' >> "/Applications/$(PROJECT_NAME).app/Contents/Info.plist"
	@echo '<dict>' >> "/Applications/$(PROJECT_NAME).app/Contents/Info.plist"
	@echo '    <key>CFBundleExecutable</key>' >> "/Applications/$(PROJECT_NAME).app/Contents/Info.plist"
	@echo '    <string>$(PROJECT_NAME)</string>' >> "/Applications/$(PROJECT_NAME).app/Contents/Info.plist"
	@echo '    <key>CFBundleIdentifier</key>' >> "/Applications/$(PROJECT_NAME).app/Contents/Info.plist"
	@echo '    <string>com.example.$(PROJECT_NAME)</string>' >> "/Applications/$(PROJECT_NAME).app/Contents/Info.plist"
	@echo '    <key>CFBundleName</key>' >> "/Applications/$(PROJECT_NAME).app/Contents/Info.plist"
	@echo '    <string>AI Plugins</string>' >> "/Applications/$(PROJECT_NAME).app/Contents/Info.plist"
	@echo '    <key>CFBundlePackageType</key>' >> "/Applications/$(PROJECT_NAME).app/Contents/Info.plist"
	@echo '    <string>APPL</string>' >> "/Applications/$(PROJECT_NAME).app/Contents/Info.plist"
	@echo '    <key>CFBundleShortVersionString</key>' >> "/Applications/$(PROJECT_NAME).app/Contents/Info.plist"
	@echo '    <string>1.0</string>' >> "/Applications/$(PROJECT_NAME).app/Contents/Info.plist"
	@echo '    <key>CFBundleVersion</key>' >> "/Applications/$(PROJECT_NAME).app/Contents/Info.plist"
	@echo '    <string>1</string>' >> "/Applications/$(PROJECT_NAME).app/Contents/Info.plist"
	@echo '    <key>LSMinimumSystemVersion</key>' >> "/Applications/$(PROJECT_NAME).app/Contents/Info.plist"
	@echo '    <string>13.0</string>' >> "/Applications/$(PROJECT_NAME).app/Contents/Info.plist"
	@echo '    <key>NSHighResolutionCapable</key>' >> "/Applications/$(PROJECT_NAME).app/Contents/Info.plist"
	@echo '    <true/>' >> "/Applications/$(PROJECT_NAME).app/Contents/Info.plist"
	@echo '</dict>' >> "/Applications/$(PROJECT_NAME).app/Contents/Info.plist"
	@echo '</plist>' >> "/Applications/$(PROJECT_NAME).app/Contents/Info.plist"
	@echo "Installation complete! You can now launch $(PROJECT_NAME) from /Applications."

# Install release version to /Applications
install-release: archive
	@echo "Installing $(PROJECT_NAME) (release) to /Applications..."
	@if [ -d "/Applications/$(PROJECT_NAME).app" ]; then \
		echo "Removing existing $(PROJECT_NAME).app from /Applications..."; \
		rm -rf "/Applications/$(PROJECT_NAME).app"; \
	fi
	@echo "Copying $(PROJECT_NAME).app to /Applications..."
	@cp -R $(RELEASE_BUILD_DIR)/$(PROJECT_NAME).app "/Applications/"
	@echo "Installation complete! You can now launch $(PROJECT_NAME) from /Applications."

# Clean the build artifacts and packaged app
clean:
	@echo "Cleaning build artifacts..."
	swift package clean
	@rm -rf build

# Phony targets to avoid conflicts with file names
.PHONY: all build run archive install install-release clean
