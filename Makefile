.PHONY: generate build run test clean install

# Generate Xcode project from project.yml
generate:
	xcodegen generate

# Build release
build: generate
	xcodebuild -project Pasted.xcodeproj -scheme Pasted -configuration Release build

# Build and run (debug)
run: generate
	xcodebuild -project Pasted.xcodeproj -scheme Pasted -configuration Debug build
	open "$(shell xcodebuild -project Pasted.xcodeproj -scheme Pasted -configuration Debug -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $$3}')/Pasted.app"

# Run tests
test: generate
	xcodebuild -project Pasted.xcodeproj -scheme PastedTests -configuration Debug test

# Install to /Applications
install: build
	@echo "Installing Pasted.app to /Applications..."
	@BUILT=$$(xcodebuild -project Pasted.xcodeproj -scheme Pasted -configuration Release -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $$3}'); \
	cp -R "$$BUILT/Pasted.app" /Applications/Pasted.app
	@echo "Installed! Launch Pasted from /Applications or Spotlight."
	@echo ""
	@echo "IMPORTANT: Grant Accessibility permission:"
	@echo "  System Settings → Privacy & Security → Accessibility → Enable Pasted"

# Clean build artifacts
clean:
	xcodebuild -project Pasted.xcodeproj -scheme Pasted clean 2>/dev/null || true
	rm -rf build/ DerivedData/ .build/
	rm -rf Pasted.xcodeproj

# Quick start
setup: generate
	@echo "Pasted.xcodeproj generated!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. open Pasted.xcodeproj"
	@echo "  2. Cmd+R to build & run"
	@echo "  3. Grant Accessibility permission when prompted"
	@echo "  4. Press Shift+Cmd+V to invoke clipboard strip"
