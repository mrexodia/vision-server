import Foundation
import ArgumentParser
import NIOCore
import NIOPosix
import NIOHTTP1

struct VisionServerCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "vision-server",
        abstract: "Apple OCR Server - Vision Framework Image Analysis",
        discussion: """
        A simple HTTP server that analyzes images using Apple's Vision framework.

        SUPPORTED FEATURES:
          • Text Recognition (18 languages)
          • Face Detection with landmarks
          • Barcode & QR Code Detection
          • Object Classification
          • Image Aesthetics Analysis
          • Saliency Detection

        SUPPORTED IMAGE FORMATS:
          • JPEG / JPG • PNG • HEIC / HEIF • TIFF • BMP • GIF

        EXAMPLE:
          curl -X POST -H "Content-Type: application/octet-stream" --data-binary @image.jpg http://localhost:8080/analyze
        """
    )

    @Option(name: .shortAndLong, help: "Port to listen on")
    var port: Int = 8080

    func run() throws {
        print("Apple OCR Server - Vision Framework Image Analysis")
        print("================================================\n")
        print("Starting server on port \(port)...")

        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        defer {
            try? group.syncShutdownGracefully()
        }

        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(VisionServerHandler())
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

        let channel = try bootstrap.bind(host: "0.0.0.0", port: port).wait()

        print("Server ready!")
        print("• http://localhost:\(port)/ - Server information")
        print("• http://localhost:\(port)/health - Health check")
        print("• http://localhost:\(port)/analyze - Upload and analyze images")
        print("\nPress Ctrl+C to stop\n")

        try channel.closeFuture.wait()
    }
}

VisionServerCommand.main()
