import Foundation
import Vision

// MARK: - Response Models

struct AnalysisResponse: Codable {
    let success: Bool
    let timestamp: String
    let imageInfo: ImageInfo?
    let textRecognition: [TextObservationResult]?
    let fullText: String?
    let faceDetection: [FaceObservationResult]?
    let barcodes: [BarcodeResult]?
    let objects: [ClassificationResult]?
    let imageAesthetics: AestheticsResult?
    let saliency: SaliencyResult?
    let error: String?

    static func success(
        imageInfo: ImageInfo,
        textRecognition: [TextObservationResult],
        fullText: String?,
        faceDetection: [FaceObservationResult],
        barcodes: [BarcodeResult],
        objects: [ClassificationResult],
        imageAesthetics: AestheticsResult?,
        saliency: SaliencyResult?
    ) -> AnalysisResponse {
        return AnalysisResponse(
            success: true,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            imageInfo: imageInfo,
            textRecognition: textRecognition,
            fullText: fullText,
            faceDetection: faceDetection,
            barcodes: barcodes,
            objects: objects,
            imageAesthetics: imageAesthetics,
            saliency: saliency,
            error: nil
        )
    }

    static func error(_ message: String) -> AnalysisResponse {
        return AnalysisResponse(
            success: false,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            imageInfo: nil,
            textRecognition: nil,
            fullText: nil,
            faceDetection: nil,
            barcodes: nil,
            objects: nil,
            imageAesthetics: nil,
            saliency: nil,
            error: message
        )
    }
}

struct ImageInfo: Codable {
    let width: Int
    let height: Int
    let format: String
    let colorSpace: String?
}

struct TextObservationResult: Codable {
    let text: String
    let confidence: Float
    let boundingBox: BoundingBox
    let topCandidates: [TextCandidate]
}

struct TextCandidate: Codable {
    let text: String
    let confidence: Float
}

struct FaceObservationResult: Codable {
    let boundingBox: BoundingBox
    let confidence: Float
    let landmarks: FaceLandmarks?
    let captureQuality: Float?
    let roll: Float?
    let yaw: Float?
    let pitch: Float?
}

struct FaceLandmarks: Codable {
    let leftEye: [Point]?
    let rightEye: [Point]?
    let nose: [Point]?
    let noseCrest: [Point]?
    let outerLips: [Point]?
    let innerLips: [Point]?
    let leftEyebrow: [Point]?
    let rightEyebrow: [Point]?
    let faceContour: [Point]?
}

struct BarcodeResult: Codable {
    let payload: String?
    let symbology: String
    let boundingBox: BoundingBox
    let confidence: Float
}

struct ClassificationResult: Codable {
    let identifier: String
    let confidence: Float
}

struct AestheticsResult: Codable {
    let overallScore: Float
    let isUtility: Float?
}

struct SaliencyResult: Codable {
    let objectBased: [SalientObject]?
    let attentionBased: SalientRegion?
}

struct SalientObject: Codable {
    let boundingBox: BoundingBox
    let confidence: Float
}

struct SalientRegion: Codable {
    let score: Float
}

struct BoundingBox: Codable {
    let x: Float
    let y: Float
    let width: Float
    let height: Float

    init(from rect: CGRect) {
        self.x = Float(rect.origin.x)
        self.y = Float(rect.origin.y)
        self.width = Float(rect.width)
        self.height = Float(rect.height)
    }
}

struct Point: Codable {
    let x: Float
    let y: Float

    init(from point: CGPoint) {
        self.x = Float(point.x)
        self.y = Float(point.y)
    }
}

// MARK: - Extension for Vision Observations

extension VNRecognizedTextObservation {
    func toResult() -> TextObservationResult? {
        guard let topCandidate = topCandidates(1).first else { return nil }

        let candidates = topCandidates(5).map { candidate in
            TextCandidate(text: candidate.string, confidence: candidate.confidence)
        }

        return TextObservationResult(
            text: topCandidate.string,
            confidence: topCandidate.confidence,
            boundingBox: BoundingBox(from: boundingBox),
            topCandidates: candidates
        )
    }
}

extension VNFaceObservation {
    func toResult() -> FaceObservationResult {
        var landmarksResult: FaceLandmarks? = nil

        if let landmarks = landmarks {
            landmarksResult = FaceLandmarks(
                leftEye: landmarks.leftEye?.normalizedPoints.map { Point(from: $0) },
                rightEye: landmarks.rightEye?.normalizedPoints.map { Point(from: $0) },
                nose: landmarks.nose?.normalizedPoints.map { Point(from: $0) },
                noseCrest: landmarks.noseCrest?.normalizedPoints.map { Point(from: $0) },
                outerLips: landmarks.outerLips?.normalizedPoints.map { Point(from: $0) },
                innerLips: landmarks.innerLips?.normalizedPoints.map { Point(from: $0) },
                leftEyebrow: landmarks.leftEyebrow?.normalizedPoints.map { Point(from: $0) },
                rightEyebrow: landmarks.rightEyebrow?.normalizedPoints.map { Point(from: $0) },
                faceContour: landmarks.faceContour?.normalizedPoints.map { Point(from: $0) }
            )
        }

        return FaceObservationResult(
            boundingBox: BoundingBox(from: boundingBox),
            confidence: confidence,
            landmarks: landmarksResult,
            captureQuality: faceCaptureQuality,
            roll: roll?.floatValue,
            yaw: yaw?.floatValue,
            pitch: pitch?.floatValue
        )
    }
}

extension VNBarcodeObservation {
    func toResult() -> BarcodeResult {
        return BarcodeResult(
            payload: payloadStringValue,
            symbology: symbology.rawValue,
            boundingBox: BoundingBox(from: boundingBox),
            confidence: confidence
        )
    }
}

extension VNClassificationObservation {
    func toResult() -> ClassificationResult {
        return ClassificationResult(
            identifier: identifier,
            confidence: confidence
        )
    }
}
