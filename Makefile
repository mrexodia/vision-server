# Makefile for Apple OCR Server

.PHONY: all build clean install run help test

# Default target
all: build

# Build the project
build:
	@echo "Building vision-server..."
	@swift build -c release
	@mkdir -p build
	@cp .build/release/vision-server build/vision-server-bin
	@echo ""
	@echo "✅ Build complete!"
	@echo "   Executable: build/vision-server-bin"
	@echo ""

# Build debug version
debug:
	@echo "Building vision-server (Debug)..."
	@swift build -c debug
	@mkdir -p build
	@cp .build/debug/vision-server build/vision-server-bin
	@echo ""
	@echo "✅ Debug build complete!"
	@echo "   Executable: build/vision-server-bin"
	@echo ""

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@swift package clean
	@rm -rf build .build
	@echo "✅ Clean complete!"

# Install to /usr/local/bin
install: build
	@echo "Installing vision-server to /usr/local/bin..."
	@mkdir -p /usr/local/bin
	@cp build/vision-server-bin /usr/local/bin/vision-server
	@chmod +x /usr/local/bin/vision-server
	@echo "✅ Installation complete!"
	@echo "   You can now run: vision-server"

# Uninstall from /usr/local/bin
uninstall:
	@echo "Uninstalling vision-server..."
	@rm -f /usr/local/bin/vision-server
	@echo "✅ Uninstall complete!"

# Run the server (on port 8080)
run: build
	@echo "Starting vision-server on port 8080..."
	@./build/vision-server-bin

# Run the server on a custom port
run-port: build
	@echo "Starting vision-server on port $(PORT)..."
	@./build/vision-server-bin --port $(PORT)

# Test with a sample image (requires IMAGE variable)
test: build
	@if [ -z "$(IMAGE)" ]; then \
		echo "❌ Error: IMAGE variable not set"; \
		echo "   Usage: make test IMAGE=/path/to/image.jpg"; \
		exit 1; \
	fi
	@echo "Testing with image: $(IMAGE)"
	@echo "Starting server in background..."
	@./build/vision-server-bin &
	@SERVER_PID=$$!; \
	sleep 2; \
	echo "Sending test request..."; \
	curl -s -X POST -F "image=@$(IMAGE)" http://localhost:8080/analyze | jq . || echo "Install jq for formatted output"; \
	echo "Stopping server..."; \
	kill $$SERVER_PID 2>/dev/null || true

# Show help
help:
	@echo "Apple OCR Server - Makefile Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build        Build the project (Release configuration)"
	@echo "  debug        Build the project (Debug configuration)"
	@echo "  clean        Remove all build artifacts"
	@echo "  install      Install the executable to /usr/local/bin"
	@echo "  uninstall    Remove the executable from /usr/local/bin"
	@echo "  run          Build and run the server on port 8080"
	@echo "  run-port     Build and run on custom port (e.g., make run-port PORT=3000)"
	@echo "  test         Build and test with an image (e.g., make test IMAGE=photo.jpg)"
	@echo "  help         Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make                     # Build the project"
	@echo "  make clean build         # Clean and rebuild"
	@echo "  make install             # Build and install to /usr/local/bin"
	@echo "  make run                 # Build and run server"
	@echo "  make run-port PORT=3000  # Run on port 3000"
	@echo "  make test IMAGE=pic.jpg  # Test with an image"
	@echo ""
