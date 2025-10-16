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
            handleRoot(context: context)
        case (.GET, "/health"):
            handleHealth(context: context)
        case (.POST, "/analyze"):
            handleAnalyze(request, body: body, context: context)
        default:
            sendResponse(status: .notFound, body: "Not Found", context: context)
        }
    }
    
    private func handleRoot(context: ChannelHandlerContext) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Apple OCR Server</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
                h1 { color: #007AFF; }
                code { background: #f5f5f5; padding: 2px 6px; border-radius: 3px; }
                .endpoint { background: #f9f9f9; padding: 15px; margin: 10px 0; border-left: 3px solid #007AFF; }
            </style>
        </head>
        <body>
            <h1>Apple OCR Server</h1>
            <p>Vision Framework Image Analysis Service</p>

            <div class="endpoint">
                <h3>POST /analyze</h3>
                <p>Upload an image for analysis</p>
                <code>curl -X POST -H "Content-Type: application/octet-stream" --data-binary @image.jpg http://localhost:8080/analyze</code>
            </div>

            <div class="endpoint">
                <h3>GET /health</h3>
                <p>Check server health</p>
                <code>curl http://localhost:8080/health</code>
            </div>

            <h3>Supported Features</h3>
            <ul>
                <li>Text Recognition (18 languages)</li>
                <li>Face Detection & Landmarks</li>
                <li>Barcode & QR Code Detection</li>
                <li>Object Classification</li>
                <li>Image Aesthetics Analysis</li>
                <li>Saliency Detection</li>
            </ul>

            <h3>Supported Image Formats</h3>
            <ul>
                <li>JPEG / JPG</li>
                <li>PNG</li>
                <li>HEIC / HEIF</li>
                <li>TIFF</li>
                <li>BMP</li>
                <li>GIF</li>
            </ul>
        </body>
        </html>
        """
        
        sendResponse(status: .ok, body: html, contentType: "text/html", context: context)
    }
    
    private func handleHealth(context: ChannelHandlerContext) {
        let json = """
        {
          "status": "ok",
          "service": "apple-ocr-server"
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
          "timestamp": "\(ISO8601DateFormatter().string(from: Date()))",
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
