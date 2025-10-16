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

    // Static date formatter for better performance
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()
    
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
        // Simple JSON response for root endpoint
        let json = """
        {
          "status": "healthy",
          "service": "apple-ocr",
          "endpoints": {
            "GET /": "Service info",
            "GET /health": "Health check",
            "POST /analyze": "Analyze image"
          }
        }
        """
        sendResponse(status: .ok, body: json, contentType: "application/json", context: context)
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
