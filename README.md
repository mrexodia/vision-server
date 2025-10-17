# Vision Server

A pure HTTP API server for macOS that analyzes images using Apple's Vision framework. Upload an image and receive comprehensive analysis including text recognition, face detection, barcodes, and object classification.

## Features

- **Text Recognition** - Supports 18 languages (English, Chinese, French, German, Spanish, Portuguese, Russian, Ukrainian, Korean, Japanese, Arabic, Hebrew, Thai, Vietnamese, and more)
- **Face Detection** - Detects faces with landmarks (eyes, nose, mouth, eyebrows, face contour)
- **Barcode & QR Code Detection** - Supports QR, Code 128, Code 39, EAN-13, UPC-E, PDF417, Aztec, and more
- **Object Classification** - Identifies objects in images using Vision's built-in models

## Supported Image Formats

- JPEG / JPG
- PNG
- HEIC / HEIF
- TIFF
- BMP
- GIF

## Prerequisites

- macOS 13.0 or later
- Swift 5.9 or later
- Xcode Command Line Tools (for `swift` command)

## Quick Start

```bash
# Build and run the server
make run

# Test with an image
make test-image IMAGE=photo.jpg
```

## Building

### Using Make (Recommended)

```bash
# Build the project
make

# Build and install to /usr/local/bin
make install

# Clean build artifacts
make clean

# See all available commands
make help
```

### Using Swift Package Manager Directly

```bash
# Build release version
swift build -c release

# Run the server (defaults to 127.0.0.1:8080)
.build/release/vision-server

# Run on custom port
.build/release/vision-server --port 3000

# Run on all network interfaces
.build/release/vision-server --host 0.0.0.0

# Run on specific host and port
.build/release/vision-server --host 0.0.0.0 --port 3000

# Show all options
.build/release/vision-server --help
```

## API Reference

The service is fully self-documenting via OpenAPI 3.0 specification.

### GET / and GET /openapi.json

Returns the complete OpenAPI 3.0 specification for the API.

**Usage:**
```bash
# Get the OpenAPI spec
curl http://localhost:8080/openapi.json

# View in Swagger UI or other OpenAPI tools
# The spec includes complete documentation for:
# - All endpoints and their parameters
# - Request/response schemas
# - Data types and constraints
# - Example values
```

### GET /health

Health check endpoint.

**Response:**
```json
{
  "status": "ok",
  "service": "vision-server"
}
```

### POST /analyze

Analyze an image and return comprehensive vision analysis results.

**Request:**
```bash
curl -X POST \
  -H "Content-Type: application/octet-stream" \
  --data-binary @image.jpg \
  http://localhost:8080/analyze
```

**Response:**
```json
{
  "success": true,
  "timestamp": "2025-10-16T22:00:00Z",
  "imageInfo": {
    "width": 1920,
    "height": 1080,
    "format": "JPEG",
    "colorSpace": "sRGB"
  },
  "textRecognition": [
    {
      "text": "Hello World",
      "confidence": 0.95,
      "boundingBox": {
        "x": 0.1,
        "y": 0.2,
        "width": 0.3,
        "height": 0.05
      },
      "topCandidates": [
        {
          "text": "Hello World",
          "confidence": 0.95
        }
      ]
    }
  ],
  "faceDetection": [
    {
      "boundingBox": {
        "x": 0.3,
        "y": 0.2,
        "width": 0.2,
        "height": 0.3
      },
      "confidence": 0.99,
      "landmarks": {
        "leftEye": [...],
        "rightEye": [...],
        "nose": [...],
        "outerLips": [...],
        "innerLips": [...]
      },
      "captureQuality": 0.85,
      "roll": -2.5,
      "yaw": 5.0,
      "pitch": 1.2
    }
  ],
  "barcodes": [
    {
      "payload": "https://example.com",
      "symbology": "QR",
      "boundingBox": {...},
      "confidence": 1.0
    }
  ],
  "objects": [
    {
      "identifier": "dog",
      "confidence": 0.92
    },
    {
      "identifier": "outdoor",
      "confidence": 0.87
    }
  ]
}
```

**Note:** All coordinates use normalized values (0.0 to 1.0) where (0, 0) is the bottom-left corner and (1, 1) is the top-right corner.

## Example Usage

### Extract text from a document
```bash
curl -X POST \
  -H "Content-Type: application/octet-stream" \
  --data-binary @document.jpg \
  http://localhost:8080/analyze | jq '.textRecognition'
```

### Detect faces in a photo
```bash
curl -X POST \
  -H "Content-Type: application/octet-stream" \
  --data-binary @family-photo.jpg \
  http://localhost:8080/analyze | jq '.faceDetection'
```

### Scan a QR code
```bash
curl -X POST \
  -H "Content-Type: application/octet-stream" \
  --data-binary @qr-code.png \
  http://localhost:8080/analyze | jq '.barcodes'
```

### Classify objects in an image
```bash
curl -X POST \
  -H "Content-Type: application/octet-stream" \
  --data-binary @scene.jpg \
  http://localhost:8080/analyze | jq '.objects'
```

## Running as a Service

### Using launchd

1. Create a plist file at `~/Library/LaunchAgents/com.vision-server.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.vision-server</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/vision-server</string>
        <string>--port</string>
        <string>8080</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/vision-server.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/vision-server.error.log</string>
</dict>
</plist>
```

2. Load and start the service:

```bash
# Load the service
launchctl load ~/Library/LaunchAgents/com.vision-server.plist

# Start the service
launchctl start com.vision-server

# Check status
launchctl list | grep vision-server

# Stop the service
launchctl stop com.vision-server

# Unload the service
launchctl unload ~/Library/LaunchAgents/com.vision-server.plist
```

## Project Structure

```
vision-server/
├── Sources/
│   └── VisionServer/
│       ├── main.swift            # Entry point with ArgumentParser
│       ├── Server.swift          # SwiftNIO HTTP server
│       ├── VisionAnalyzer.swift  # Vision framework integration
│       └── Models.swift          # JSON response models
├── tests/
│   ├── meme.jpeg                # Test image
│   └── recipe.heic              # Test image
├── Package.swift                 # Swift Package Manager manifest
├── Makefile                      # Build automation
└── README.md                     # This file
```

## Implementation Details

### HTTP Server
- Built with SwiftNIO for high-performance async I/O
- Pure JSON API - no HTML interface
- Accepts direct binary uploads (application/octet-stream)
- Event-driven request handling

### Vision Framework Integration
- Uses multiple Vision requests in parallel:
  - `VNRecognizeTextRequest` - Text recognition with language detection
  - `VNDetectFaceLandmarksRequest` - Face detection with landmarks
  - `VNDetectFaceCaptureQualityRequest` - Face quality scoring
  - `VNDetectBarcodesRequest` - Barcode and QR code detection
  - `VNClassifyImageRequest` - Object classification

## Troubleshooting

### Port already in use
If you get a "bind failed" error, the port is already in use. Try a different port:
```bash
./vision-server --port 8081
```

### Permission denied
If you get a permission denied error when running the server:
```bash
chmod +x .build/release/vision-server
```

### Image not recognized
Ensure the image file is valid and in a supported format. Check the server logs for detailed error messages.

## License

This project is provided as-is for educational and development purposes.

## Contributing

Feel free to submit issues and enhancement requests!