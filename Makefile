# Makefile for Vision Server

.PHONY: all build clean install run help test test-image

# Default target
all: build

# Build the project (release configuration)
build:
	@echo "Building vision-server..."
	@swift build -c release
	@echo "[OK] Build complete!"
	@echo "     Executable: .build/release/vision-server"

# Build debug version
debug:
	@echo "Building vision-server (Debug)..."
	@swift build -c debug
	@echo "[OK] Debug build complete!"
	@echo "     Executable: .build/debug/vision-server"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@swift package clean
	@rm -rf build .build
	@echo "[OK] Clean complete!"

# Install to /usr/local/bin
install: build
	@echo "Installing vision-server to /usr/local/bin..."
	@mkdir -p /usr/local/bin
	@cp .build/release/vision-server /usr/local/bin/vision-server
	@chmod +x /usr/local/bin/vision-server
	@echo "[OK] Installation complete!"
	@echo "     You can now run: vision-server"

# Uninstall from /usr/local/bin
uninstall:
	@echo "Uninstalling vision-server..."
	@rm -f /usr/local/bin/vision-server
	@echo "[OK] Uninstall complete!"

# Run the server (default: 127.0.0.1:8080)
run: build
	@echo "Starting vision-server on 127.0.0.1:8080..."
	@./.build/release/vision-server

# Run the server with custom host and/or port
run-custom: build
	@if [ -z "$(HOST)" ] && [ -z "$(PORT)" ]; then \
		echo "[ERROR] Please specify HOST and/or PORT"; \
		echo "        Usage: make run-custom HOST=127.0.0.1 PORT=3000"; \
		exit 1; \
	fi
	@HOST_ARG=""; \
	PORT_ARG=""; \
	if [ ! -z "$(HOST)" ]; then HOST_ARG="--host $(HOST)"; fi; \
	if [ ! -z "$(PORT)" ]; then PORT_ARG="--port $(PORT)"; fi; \
	echo "Starting vision-server with $$HOST_ARG $$PORT_ARG..."; \
	./.build/release/vision-server $$HOST_ARG $$PORT_ARG

# Test with the default test images
test: build
	@echo "Starting server..."
	@./.build/release/vision-server &
	@SERVER_PID=$$!; \
	sleep 2; \
	echo "Testing with meme.jpeg..."; \
	curl -s -X POST -H "Content-Type: application/octet-stream" --data-binary @tests/meme.jpeg http://localhost:8080/analyze | jq . || curl -s -X POST -H "Content-Type: application/octet-stream" --data-binary @tests/meme.jpeg http://localhost:8080/analyze; \
	echo ""; \
	echo "Stopping server..."; \
	kill $$SERVER_PID 2>/dev/null || true; \
	echo "[OK] Test complete!"

# Test with a specific image
test-image:
	@if [ -z "$(IMAGE)" ]; then \
		echo "[ERROR] IMAGE variable not set"; \
		echo "        Usage: make test-image IMAGE=/path/to/image.jpg"; \
		exit 1; \
	fi
	@echo "Testing with image: $(IMAGE)"
	@curl -s -X POST -H "Content-Type: application/octet-stream" --data-binary @$(IMAGE) http://localhost:8080/analyze | jq . || curl -s -X POST -H "Content-Type: application/octet-stream" --data-binary @$(IMAGE) http://localhost:8080/analyze

# Show help
help:
	@echo "Vision Server - Makefile Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build        Build the project (Release configuration)"
	@echo "  debug        Build the project (Debug configuration)"
	@echo "  clean        Remove all build artifacts"
	@echo "  install      Install the executable to /usr/local/bin"
	@echo "  uninstall    Remove the executable from /usr/local/bin"
	@echo "  run          Build and run the server on 127.0.0.1:8080"
	@echo "  run-custom   Build and run with custom host/port"
	@echo "  test         Build and test with the included test images"
	@echo "  test-image   Test with a specific image (e.g., make test-image IMAGE=photo.jpg)"
	@echo "  help         Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make                                  # Build the project"
	@echo "  make clean build                      # Clean and rebuild"
	@echo "  make install                          # Build and install to /usr/local/bin"
	@echo "  make run                              # Build and run server on 127.0.0.1:8080"
	@echo "  make run-custom PORT=3000             # Run on port 3000"
	@echo "  make run-custom HOST=127.0.0.1        # Run on localhost only"
	@echo "  make run-custom HOST=0.0.0.0 PORT=80  # Run on all interfaces, port 80"
	@echo "  make test                             # Test with default test images"
	@echo "  make test-image IMAGE=pic.jpg         # Test with a specific image"
	@echo ""
