import Foundation
import ArgumentParser
import NIOCore
import NIOPosix
import NIOHTTP1

struct VisionServerCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "vision-server",
        abstract: "Vision Server - Vision Framework Image Analysis",
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

    @Option(name: .shortAndLong, help: "Host address to bind to")
    var host: String = "127.0.0.1"

    func run() throws {
        print("Vision Server - Vision Framework Image Analysis")
        print("================================================\n")
        print("Starting server on \(host):\(port)...")

        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        defer {
            try? group.syncShutdownGracefully()
        }

        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(VisionServerHandler(port: port))
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

        let channel = try bootstrap.bind(host: host, port: port).wait()

        print("Server ready!")
        print("• http://\(host):\(port)/ - Server information")
        print("• http://\(host):\(port)/health - Health check")
        print("• http://\(host):\(port)/analyze - Upload and analyze images")
        print("\nPress Ctrl+C to stop\n")

        try channel.closeFuture.wait()
    }
}

VisionServerCommand.main()
