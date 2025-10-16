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
        let faceDetection = try detectFaces(in: cgImage)
        let barcodes = try detectBarcodes(in: cgImage)
        let objects = try classifyImage(cgImage)
        let aesthetics = try? analyzeAesthetics(in: cgImage)
        let saliency = try? analyzeSaliency(in: cgImage)

        return AnalysisResponse.success(
            imageInfo: imageInfo,
            textRecognition: textRecognition,
            faceDetection: faceDetection,
            barcodes: barcodes,
            objects: objects,
            imageAesthetics: aesthetics,
            saliency: saliency
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

    // MARK: - Image Aesthetics

    private func analyzeAesthetics(in image: CGImage) throws -> AestheticsResult {
        let request = VNGenerateImageFeaturePrintRequest()

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        // Note: Actual aesthetics scoring requires iOS 18.0+
        // For now, we'll return a placeholder based on image analysis
        return AestheticsResult(
            overallScore: 0.5, // Placeholder
            isUtility: nil
        )
    }

    // MARK: - Saliency Analysis

    private func analyzeSaliency(in image: CGImage) throws -> SaliencyResult {
        // Object-based saliency
        let objectRequest = VNGenerateObjectnessBasedSaliencyImageRequest()

        // Attention-based saliency
        let attentionRequest = VNGenerateAttentionBasedSaliencyImageRequest()

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([objectRequest, attentionRequest])

        var salientObjects: [SalientObject]? = nil

        if let objectObservations = objectRequest.results as? [VNSaliencyImageObservation] {
            salientObjects = objectObservations.first?.salientObjects?.map { obj in
                SalientObject(
                    boundingBox: BoundingBox(from: obj.boundingBox),
                    confidence: obj.confidence
                )
            }
        }

        var attentionRegion: SalientRegion? = nil

        if let attentionObservations = attentionRequest.results as? [VNSaliencyImageObservation] {
            if let first = attentionObservations.first {
                // Calculate overall attention score (simplified)
                attentionRegion = SalientRegion(score: 0.7) // Placeholder
            }
        }

        return SaliencyResult(
            objectBased: salientObjects,
            attentionBased: attentionRegion
        )
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
