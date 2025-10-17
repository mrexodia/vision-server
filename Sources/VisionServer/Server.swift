import NIOCore
import NIOPosix
import NIOHTTP1
import Foundation

final class VisionServerHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private var requestHead: HTTPRequestHead?
    private var bodyBuffer: ByteBuffer?
    private let analyzer = VisionAnalyzer()
    private let port: Int

    init(port: Int) {
        self.port = port
    }

    // Static date formatter for better performance
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()

    // Generate OpenAPI specification with dynamic server URL
    private static func generateOpenAPISpec(host: String) -> String {
        return """
        {
          "openapi": "3.0.3",
          "info": {
            "title": "Vision Server API",
            "description": "A macOS Vision framework API server for comprehensive image analysis including text recognition, face detection, barcode scanning, and object classification.",
            "version": "1.0.0",
            "contact": {
              "name": "Vision Server"
            }
          },
          "servers": [
            {
              "url": "\(host)",
              "description": "Current server"
            }
          ],
      "paths": {
        "/": {
          "get": {
            "summary": "Get OpenAPI specification",
            "description": "Returns this OpenAPI specification in JSON format",
            "operationId": "getOpenAPISpec",
            "responses": {
              "200": {
                "description": "OpenAPI specification",
                "content": {
                  "application/json": {
                    "schema": {
                      "$ref": "#/components/schemas/OpenAPISpec"
                    }
                  }
                }
              }
            }
          }
        },
        "/openapi.json": {
          "get": {
            "summary": "Get OpenAPI specification (alternative endpoint)",
            "description": "Returns the OpenAPI specification for tooling that expects this endpoint",
            "operationId": "getOpenAPISpecAlt",
            "responses": {
              "200": {
                "description": "OpenAPI specification",
                "content": {
                  "application/json": {
                    "schema": {
                      "$ref": "#/components/schemas/OpenAPISpec"
                    }
                  }
                }
              }
            }
          }
        },
        "/health": {
          "get": {
            "summary": "Health check",
            "description": "Check if the service is running and healthy",
            "operationId": "healthCheck",
            "responses": {
              "200": {
                "description": "Service is healthy",
                "content": {
                  "application/json": {
                    "schema": {
                      "$ref": "#/components/schemas/HealthResponse"
                    }
                  }
                }
              }
            }
          }
        },
        "/analyze": {
          "post": {
            "summary": "Analyze image",
            "description": "Perform comprehensive Vision framework analysis on an uploaded image",
            "operationId": "analyzeImage",
            "requestBody": {
              "required": true,
              "description": "Raw image data in binary format",
              "content": {
                "application/octet-stream": {
                  "schema": {
                    "type": "string",
                    "format": "binary"
                  }
                }
              }
            },
            "responses": {
              "200": {
                "description": "Successful analysis",
                "content": {
                  "application/json": {
                    "schema": {
                      "$ref": "#/components/schemas/AnalysisResponse"
                    }
                  }
                }
              },
              "400": {
                "description": "Bad request - invalid or missing image data",
                "content": {
                  "application/json": {
                    "schema": {
                      "$ref": "#/components/schemas/ErrorResponse"
                    }
                  }
                }
              },
              "500": {
                "description": "Internal server error during analysis",
                "content": {
                  "application/json": {
                    "schema": {
                      "$ref": "#/components/schemas/ErrorResponse"
                    }
                  }
                }
              }
            }
          }
        }
      },
      "components": {
        "schemas": {
          "OpenAPISpec": {
            "type": "object",
            "description": "OpenAPI 3.0 specification document"
          },
          "HealthResponse": {
            "type": "object",
            "required": ["status", "service"],
            "properties": {
              "status": {
                "type": "string",
                "enum": ["ok"],
                "example": "ok"
              },
              "service": {
                "type": "string",
                "example": "vision-server"
              }
            }
          },
          "ErrorResponse": {
            "type": "object",
            "required": ["success", "timestamp", "error"],
            "properties": {
              "success": {
                "type": "boolean",
                "example": false
              },
              "timestamp": {
                "type": "string",
                "format": "date-time",
                "example": "2025-10-17T10:30:00Z"
              },
              "error": {
                "type": "string",
                "example": "Analysis failed: Invalid image format"
              }
            }
          },
          "AnalysisResponse": {
            "type": "object",
            "required": ["success", "timestamp", "imageInfo"],
            "properties": {
              "success": {
                "type": "boolean",
                "example": true
              },
              "timestamp": {
                "type": "string",
                "format": "date-time",
                "example": "2025-10-17T10:30:00Z"
              },
              "imageInfo": {
                "$ref": "#/components/schemas/ImageInfo"
              },
              "textRecognition": {
                "type": "array",
                "items": {
                  "$ref": "#/components/schemas/TextObservation"
                },
                "description": "Array of individual text observations with bounding boxes and confidence scores"
              },
              "fullText": {
                "type": "string",
                "nullable": true,
                "description": "All recognized text ordered in natural reading order (top-to-bottom, left-to-right) with newlines preserved. Returns null if no text was detected. This is generated from textRecognition by sorting observations spatially.",
                "example": "First line of text\\nSecond line of text\\n\\nNew paragraph"
              },
              "faceDetection": {
                "type": "array",
                "items": {
                  "$ref": "#/components/schemas/FaceObservation"
                }
              },
              "barcodes": {
                "type": "array",
                "items": {
                  "$ref": "#/components/schemas/BarcodeObservation"
                }
              },
              "objects": {
                "type": "array",
                "items": {
                  "$ref": "#/components/schemas/ObjectClassification"
                }
              }
            }
          },
          "ImageInfo": {
            "type": "object",
            "required": ["width", "height", "format"],
            "properties": {
              "width": {
                "type": "integer",
                "example": 1920
              },
              "height": {
                "type": "integer",
                "example": 1080
              },
              "format": {
                "type": "string",
                "enum": ["JPEG", "PNG", "HEIC", "TIFF", "BMP", "GIF", "unknown"],
                "example": "JPEG"
              },
              "colorSpace": {
                "type": "string",
                "nullable": true,
                "example": "sRGB"
              }
            }
          },
          "BoundingBox": {
            "type": "object",
            "required": ["x", "y", "width", "height"],
            "properties": {
              "x": {
                "type": "number",
                "format": "double",
                "minimum": 0,
                "maximum": 1,
                "description": "Normalized X coordinate (0-1)"
              },
              "y": {
                "type": "number",
                "format": "double",
                "minimum": 0,
                "maximum": 1,
                "description": "Normalized Y coordinate (0-1)"
              },
              "width": {
                "type": "number",
                "format": "double",
                "minimum": 0,
                "maximum": 1,
                "description": "Normalized width (0-1)"
              },
              "height": {
                "type": "number",
                "format": "double",
                "minimum": 0,
                "maximum": 1,
                "description": "Normalized height (0-1)"
              }
            }
          },
          "TextObservation": {
            "type": "object",
            "required": ["text", "confidence", "boundingBox"],
            "properties": {
              "text": {
                "type": "string",
                "example": "Hello World"
              },
              "confidence": {
                "type": "number",
                "format": "double",
                "minimum": 0,
                "maximum": 1,
                "example": 0.95
              },
              "boundingBox": {
                "$ref": "#/components/schemas/BoundingBox"
              },
              "topCandidates": {
                "type": "array",
                "items": {
                  "type": "object",
                  "properties": {
                    "text": {
                      "type": "string"
                    },
                    "confidence": {
                      "type": "number",
                      "format": "double"
                    }
                  }
                }
              }
            }
          },
          "FaceObservation": {
            "type": "object",
            "required": ["boundingBox", "confidence"],
            "properties": {
              "boundingBox": {
                "$ref": "#/components/schemas/BoundingBox"
              },
              "confidence": {
                "type": "number",
                "format": "double",
                "minimum": 0,
                "maximum": 1
              },
              "landmarks": {
                "type": "object",
                "properties": {
                  "leftEye": {
                    "type": "array",
                    "items": {
                      "$ref": "#/components/schemas/Point"
                    }
                  },
                  "rightEye": {
                    "type": "array",
                    "items": {
                      "$ref": "#/components/schemas/Point"
                    }
                  },
                  "leftEyebrow": {
                    "type": "array",
                    "items": {
                      "$ref": "#/components/schemas/Point"
                    }
                  },
                  "rightEyebrow": {
                    "type": "array",
                    "items": {
                      "$ref": "#/components/schemas/Point"
                    }
                  },
                  "nose": {
                    "type": "array",
                    "items": {
                      "$ref": "#/components/schemas/Point"
                    }
                  },
                  "noseCrest": {
                    "type": "array",
                    "items": {
                      "$ref": "#/components/schemas/Point"
                    }
                  },
                  "medianLine": {
                    "type": "array",
                    "items": {
                      "$ref": "#/components/schemas/Point"
                    }
                  },
                  "outerLips": {
                    "type": "array",
                    "items": {
                      "$ref": "#/components/schemas/Point"
                    }
                  },
                  "innerLips": {
                    "type": "array",
                    "items": {
                      "$ref": "#/components/schemas/Point"
                    }
                  },
                  "leftPupil": {
                    "$ref": "#/components/schemas/Point"
                  },
                  "rightPupil": {
                    "$ref": "#/components/schemas/Point"
                  },
                  "faceContour": {
                    "type": "array",
                    "items": {
                      "$ref": "#/components/schemas/Point"
                    }
                  }
                }
              },
              "captureQuality": {
                "type": "number",
                "format": "double",
                "nullable": true
              },
              "roll": {
                "type": "number",
                "format": "double",
                "nullable": true,
                "description": "Face roll angle in degrees"
              },
              "yaw": {
                "type": "number",
                "format": "double",
                "nullable": true,
                "description": "Face yaw angle in degrees"
              },
              "pitch": {
                "type": "number",
                "format": "double",
                "nullable": true,
                "description": "Face pitch angle in degrees"
              }
            }
          },
          "Point": {
            "type": "object",
            "required": ["x", "y"],
            "properties": {
              "x": {
                "type": "number",
                "format": "double",
                "minimum": 0,
                "maximum": 1
              },
              "y": {
                "type": "number",
                "format": "double",
                "minimum": 0,
                "maximum": 1
              }
            }
          },
          "BarcodeObservation": {
            "type": "object",
            "required": ["payload", "symbology", "boundingBox", "confidence"],
            "properties": {
              "payload": {
                "type": "string",
                "example": "https://example.com"
              },
              "symbology": {
                "type": "string",
                "enum": ["QR", "Code128", "Code39", "EAN13", "UPCE", "PDF417", "Aztec", "DataMatrix", "I2of5", "ITF14", "EAN8", "Code39Mod43", "UPCA", "Code93", "Code93i"],
                "example": "QR"
              },
              "boundingBox": {
                "$ref": "#/components/schemas/BoundingBox"
              },
              "confidence": {
                "type": "number",
                "format": "double",
                "minimum": 0,
                "maximum": 1
              }
            }
          },
          "ObjectClassification": {
            "type": "object",
            "required": ["identifier", "confidence"],
            "properties": {
              "identifier": {
                "type": "string",
                "example": "dog"
              },
              "confidence": {
                "type": "number",
                "format": "double",
                "minimum": 0,
                "maximum": 1,
                "example": 0.92
              }
            }
          }
        }
      }
    }
    """
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)
        
        switch reqPart {
        case .head(let request):
            self.requestHead = request
            self.bodyBuffer = context.channel.allocator.buffer(capacity: 0)
            print("Received: \(request.method) \(request.uri)")
            
        case .body(let buffer):
            // Accumulate body chunks
            var buffer = buffer
            self.bodyBuffer?.writeBuffer(&buffer)
            
        case .end:
            guard let request = requestHead else { return }
            handleRequest(request, body: bodyBuffer, context: context)
            requestHead = nil
            bodyBuffer = nil
        }
    }
    
    private func handleRequest(_ request: HTTPRequestHead, body: ByteBuffer?, context: ChannelHandlerContext) {
        switch (request.method, request.uri) {
        case (.GET, "/"):
            handleOpenAPISpec(request: request, context: context)
        case (.GET, "/openapi.json"):
            handleOpenAPISpec(request: request, context: context)
        case (.GET, "/health"):
            handleHealth(context: context)
        case (.POST, "/analyze"):
            handleAnalyze(request, body: body, context: context)
        default:
            sendResponse(status: .notFound, body: "Not Found", context: context)
        }
    }

    private func handleOpenAPISpec(request: HTTPRequestHead, context: ChannelHandlerContext) {
        // Extract host from request headers or use default with actual port
        let hostHeader = request.headers["Host"].first ?? "localhost:\(port)"

        // Determine protocol (simplified - in production you'd check X-Forwarded-Proto, etc.)
        let proto = request.headers["X-Forwarded-Proto"].first ?? "http"
        let serverUrl = "\(proto)://\(hostHeader)"

        // Generate OpenAPI spec with the actual server URL
        let openAPISpec = Self.generateOpenAPISpec(host: serverUrl)
        sendResponse(status: .ok, body: openAPISpec, contentType: "application/json", context: context)
    }
    
    private func handleHealth(context: ChannelHandlerContext) {
        let json = """
        {
          "status": "ok",
          "service": "vision-server"
        }
        """
        sendResponse(status: .ok, body: json, contentType: "application/json", context: context)
    }
    
    private func handleAnalyze(_ request: HTTPRequestHead, body: ByteBuffer?, context: ChannelHandlerContext) {
        guard var body = body, body.readableBytes > 0 else {
            let errorResponse = makeErrorJSON("No request body")
            sendResponse(status: .badRequest, body: errorResponse, contentType: "application/json", context: context)
            return
        }
        
        // Convert ByteBuffer to Data
        let imageData = body.readBytes(length: body.readableBytes).map { Data($0) } ?? Data()
        
        print("Processing image (\(imageData.count) bytes)...")
        
        // Analyze image
        do {
            let result = try analyzer.analyze(imageData: imageData)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(result)
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Analysis complete")
                sendResponse(status: .ok, body: jsonString, contentType: "application/json", context: context)
            } else {
                let errorResponse = makeErrorJSON("Failed to encode response")
                sendResponse(status: .internalServerError, body: errorResponse, contentType: "application/json", context: context)
            }
        } catch {
            print("Analysis failed: \(error)")
            let errorResponse = makeErrorJSON("Analysis failed: \(error.localizedDescription)")
            sendResponse(status: .internalServerError, body: errorResponse, contentType: "application/json", context: context)
        }
    }
    
    private func makeErrorJSON(_ message: String) -> String {
        return """
        {
          "success": false,
          "timestamp": "\(Self.iso8601Formatter.string(from: Date()))",
          "error": "\(message)"
        }
        """
    }
    
    private func sendResponse(status: HTTPResponseStatus, body: String, contentType: String = "text/plain", context: ChannelHandlerContext) {
        let headers = HTTPHeaders([("Content-Type", contentType), ("Content-Length", String(body.utf8.count))])
        let head = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
        
        context.write(self.wrapOutboundOut(.head(head)), promise: nil)
        
        var buffer = context.channel.allocator.buffer(capacity: body.utf8.count)
        buffer.writeString(body)
        context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        
        context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
    }
}
