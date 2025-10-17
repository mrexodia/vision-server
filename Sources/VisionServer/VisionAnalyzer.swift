import Foundation
import Vision
import CoreImage
import AppKit

class VisionAnalyzer {

    // MARK: - Main Analysis Method

    func analyze(imageData: Data) throws -> AnalysisResponse {
        // Create CGImage from data
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return AnalysisResponse.error("Failed to decode image data")
        }

        // Get image info
        let imageInfo = ImageInfo(
            width: cgImage.width,
            height: cgImage.height,
            format: detectImageFormat(data: imageData),
            colorSpace: cgImage.colorSpace?.name as String?
        )

        // Perform all analyses
        let textRecognition = try recognizeText(in: cgImage)
        let fullText = textRecognition.isEmpty ? nil : orderTextObservations(textRecognition)
        let faceDetection = try detectFaces(in: cgImage)
        let barcodes = try detectBarcodes(in: cgImage)
        let objects = try classifyImage(cgImage)
        // Note: Aesthetics and saliency analysis removed as they were returning placeholder values
        // These features require iOS 18.0+ or more complex implementation

        return AnalysisResponse.success(
            imageInfo: imageInfo,
            textRecognition: textRecognition,
            fullText: fullText,
            faceDetection: faceDetection,
            barcodes: barcodes,
            objects: objects,
            imageAesthetics: nil,
            saliency: nil
        )
    }

    // MARK: - Text Recognition

    private func recognizeText(in image: CGImage) throws -> [TextObservationResult] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true

        // Supported languages (18 total)
        // English, Chinese, French, Italian, German, Spanish, Portuguese,
        // Russian, Ukrainian, Korean, Japanese, Arabic, Hebrew, Thai, Vietnamese, etc.

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return []
        }

        return observations.compactMap { $0.toResult() }
    }

    // MARK: - Text Ordering

    private func orderTextObservations(_ observations: [TextObservationResult]) -> String {
        guard !observations.isEmpty else { return "" }

        // Group observations into lines based on vertical proximity
        // Note: Vision coordinates have origin at bottom-left, so higher Y = higher on page
        let sortedByY = observations.sorted { $0.boundingBox.y > $1.boundingBox.y }

        var lines: [[TextObservationResult]] = []
        var currentLine: [TextObservationResult] = []
        var lastY: Float?

        for observation in sortedByY {
            let currentY = observation.boundingBox.y
            let height = observation.boundingBox.height

            if let prevY = lastY {
                // Check if this observation is on a new line
                // Consider it a new line if vertical distance is more than half the height
                let verticalDistance = abs(prevY - currentY)
                if verticalDistance > height * 0.5 {
                    // Start a new line
                    if !currentLine.isEmpty {
                        lines.append(currentLine)
                    }
                    currentLine = [observation]
                } else {
                    // Same line
                    currentLine.append(observation)
                }
            } else {
                // First observation
                currentLine.append(observation)
            }

            lastY = currentY
        }

        // Don't forget the last line
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        // Sort each line left-to-right and build the full text
        var result = ""
        var previousLineY: Float?

        for line in lines {
            // Sort left to right
            let sortedLine = line.sorted { $0.boundingBox.x < $1.boundingBox.x }

            // Check if we need a paragraph break (larger vertical gap)
            if let prevY = previousLineY {
                let currentY = sortedLine.first?.boundingBox.y ?? 0
                let avgHeight = sortedLine.first?.boundingBox.height ?? 0.05
                let verticalGap = abs(prevY - currentY)

                // If gap is more than 1.5x the average height, consider it a paragraph break
                if verticalGap > avgHeight * 1.5 {
                    result += "\n\n"
                } else {
                    result += "\n"
                }
            }

            // Join text in the line with spaces
            let lineText = sortedLine.map { $0.text }.joined(separator: " ")
            result += lineText

            previousLineY = sortedLine.first?.boundingBox.y
        }

        return result
    }

    // MARK: - Face Detection

    private func detectFaces(in image: CGImage) throws -> [FaceObservationResult] {
        // First detect faces with landmarks
        let landmarksRequest = VNDetectFaceLandmarksRequest()

        // Also detect capture quality
        let qualityRequest = VNDetectFaceCaptureQualityRequest()

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([landmarksRequest, qualityRequest])

        var results: [FaceObservationResult] = []

        if let landmarksObservations = landmarksRequest.results as? [VNFaceObservation] {
            results = landmarksObservations.map { $0.toResult() }
        }

        // Merge capture quality if available
        if let qualityObservations = qualityRequest.results as? [VNFaceObservation] {
            for (index, qualityObs) in qualityObservations.enumerated() {
                if index < results.count {
                    var result = results[index]
                    result = FaceObservationResult(
                        boundingBox: result.boundingBox,
                        confidence: result.confidence,
                        landmarks: result.landmarks,
                        captureQuality: qualityObs.faceCaptureQuality,
                        roll: result.roll,
                        yaw: result.yaw,
                        pitch: result.pitch
                    )
                    results[index] = result
                }
            }
        }

        return results
    }

    // MARK: - Barcode Detection

    private func detectBarcodes(in image: CGImage) throws -> [BarcodeResult] {
        let request = VNDetectBarcodesRequest()

        // Supports multiple symbologies:
        // QR, Code 128, Code 39, Code 93, EAN-8, EAN-13, UPC-E, PDF417, Aztec, etc.

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNBarcodeObservation] else {
            return []
        }

        return observations.map { $0.toResult() }
    }

    // MARK: - Image Classification

    private func classifyImage(_ image: CGImage) throws -> [ClassificationResult] {
        let request = VNClassifyImageRequest()

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNClassificationObservation] else {
            return []
        }

        // Return top results with reasonable confidence
        return observations
            .filter { $0.confidence > 0.1 }
            .prefix(10)
            .map { $0.toResult() }
    }


    // MARK: - Helper Methods

    private func detectImageFormat(data: Data) -> String {
        guard data.count >= 12 else { return "unknown" }

        let bytes = [UInt8](data.prefix(12))

        // JPEG
        if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return "JPEG"
        }

        // PNG
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "PNG"
        }

        // GIF
        if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 {
            return "GIF"
        }

        // HEIC/HEIF
        if bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70 {
            let subtype = String(bytes: bytes[8...11], encoding: .ascii) ?? ""
            if subtype.contains("heic") || subtype.contains("heix") ||
               subtype.contains("hevc") || subtype.contains("hevx") {
                return "HEIC"
            }
            return "HEIF"
        }

        // BMP
        if bytes[0] == 0x42 && bytes[1] == 0x4D {
            return "BMP"
        }

        // TIFF
        if (bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00) ||
           (bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A) {
            return "TIFF"
        }

        return "unknown"
    }
}
