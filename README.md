# Apple OCR Server

A simple HTTP server for macOS that analyzes images using Apple's Vision framework. Upload an image and receive comprehensive analysis including text recognition, face detection, barcodes, object classification, and more.

## Features

- **Text Recognition** - Supports 18 languages (English, Chinese, French, German, Spanish, Portuguese, Russian, Ukrainian, Korean, Japanese, Arabic, Hebrew, Thai, Vietnamese, and more)
- **Face Detection** - Detects faces with landmarks (eyes, nose, mouth, eyebrows, face contour)
- **Barcode & QR Code Detection** - Supports QR, Code 128, Code 39, EAN-13, UPC-E, PDF417, Aztec, and more
- **Object Classification** - Identifies objects in images using Vision's built-in models
- **Image Aesthetics** - Analyzes visual appeal and composition
- **Saliency Detection** - Identifies attention-grabbing and important regions

## Supported Image Formats

- JPEG / JPG
- PNG
- HEIC / HEIF
- TIFF
- BMP
- GIF

## Building the Project

### Prerequisites

- macOS 13.0 or later
- Swift 5.9 or later
- Xcode Command Line Tools (for `swift` command)

### Build Steps

#### Using Make (Recommended)

```bash
# Build the project (Release configuration)
make

# The executable will be at: build/vision-server-bin

# Build and run
make run

# Build and install to /usr/local/bin
make install

# See all available commands
make help
```

#### Using Swift Package Manager Directly

```bash
# Build release version
swift build -c release

# The executable will be at: .build/release/vision-server

# Run directly
.build/release/vision-server

# Or with custom port
.build/release/vision-server --port 3000
```

## Usage

### Starting the Server

```bash
# Start on default port (8080)
./vision-server

# Start on custom port
./vision-server --port 3000

# Show help
./vision-server --help
```

### API Endpoints

#### GET /
Server information and documentation page (HTML)

#### GET /health
Health check endpoint

**Response:**
```json
{
  "status": "ok",
  "service": "apple-ocr-server"
}
```

#### POST /analyze
Upload and analyze an image

**Request:**
```bash
curl -X POST -H "Content-Type: application/octet-stream" --data-binary @image.jpg http://localhost:8080/analyze
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
  ],
  "imageAesthetics": {
    "overallScore": 0.75
  },
  "saliency": {
    "objectBased": [
      {
        "boundingBox": {...},
        "confidence": 0.88
      }
    ],
    "attentionBased": {
      "score": 0.72
    }
  }
}
```

## Running as a macOS Service

### Using launchd

1. Create a plist file at `~/Library/LaunchAgents/com.apple-ocr-server.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.apple-ocr-server</string>
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
    <string>/tmp/apple-ocr-server.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/apple-ocr-server.error.log</string>
</dict>
</plist>
```

2. Load and start the service:

```bash
# Load the service
launchctl load ~/Library/LaunchAgents/com.apple-ocr-server.plist

# Start the service
launchctl start com.apple-ocr-server

# Check status
launchctl list | grep apple-ocr-server

# View logs
tail -f /tmp/apple-ocr-server.log

# Stop the service
launchctl stop com.apple-ocr-server

# Unload the service
launchctl unload ~/Library/LaunchAgents/com.apple-ocr-server.plist
```

## Example Usage

### Analyze a document
```bash
curl -X POST -H "Content-Type: application/octet-stream" --data-binary @document.jpg http://localhost:8080/analyze | jq '.textRecognition'
```

### Detect faces in a photo
```bash
curl -X POST -H "Content-Type: application/octet-stream" --data-binary @family-photo.jpg http://localhost:8080/analyze | jq '.faceDetection'
```

### Scan a QR code
```bash
curl -X POST -H "Content-Type: application/octet-stream" --data-binary @qr-code.png http://localhost:8080/analyze | jq '.barcodes'
```

### Classify objects in an image
```bash
curl -X POST -H "Content-Type: application/octet-stream" --data-binary @scene.jpg http://localhost:8080/analyze | jq '.objects'
```

## Project Structure

```
apple-ocr/
├── Package.swift              # Swift Package Manager manifest
├── Makefile                   # Build automation
├── vision-server/             # Source files
│   ├── main.swift            # Entry point with ArgumentParser
│   ├── Server.swift          # SwiftNIO HTTP server
│   ├── VisionAnalyzer.swift  # Vision framework integration
│   └── Models.swift          # JSON response models
├── build/                     # Build output (gitignored)
│   └── vision-server-bin     # Compiled executable
├── vision-framework.md       # Vision framework documentation
└── README.md                 # This file
```

## Implementation Details

### HTTP Server
- Built with SwiftNIO for high-performance async I/O
- Accepts direct binary uploads (application/octet-stream)
- Event-driven request handling
- Returns JSON responses with detailed analysis

### Vision Framework Integration
- Uses multiple Vision requests in parallel:
  - `VNRecognizeTextRequest` - Text recognition with language detection
  - `VNDetectFaceLandmarksRequest` - Face detection with landmarks
  - `VNDetectFaceCaptureQualityRequest` - Face quality scoring
  - `VNDetectBarcodesRequest` - Barcode and QR code detection
  - `VNClassifyImageRequest` - Object classification
  - `VNGenerateObjectnessBasedSaliencyImageRequest` - Object saliency
  - `VNGenerateAttentionBasedSaliencyImageRequest` - Attention saliency

### Response Format
All coordinates use normalized values (0.0 to 1.0) where:
- (0, 0) is the bottom-left corner
- (1, 1) is the top-right corner
- This matches Vision framework's coordinate system

## Troubleshooting

### Port already in use
If you get a "bind failed" error, the port is already in use. Try a different port:
```bash
./vision-server --port 8081
```

### Permission denied
If you get a permission denied error when running the server:
```bash
chmod +x vision-server
```

### Image not recognized
Ensure the image file is valid and in a supported format. Check the server logs for detailed error messages.

## License

This project is provided as-is for educational and development purposes.

## Contributing

Feel free to submit issues and enhancement requests!
