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

# Clean the build artifacts and packaged app
clean:
	@echo "Cleaning build artifacts..."
	swift package clean
	@rm -rf build

# Phony targets to avoid conflicts with file names
.PHONY: all build run archive clean
