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
    let bodyPose: BodyPoseResult?
    let handPoses: [HandPoseResult]?
    let animals: [AnimalResult]?
    let rectangles: [RectangleResult]?
    let horizon: HorizonResult?
    let contours: ContourResult?
    let humanRectangles: [HumanRectangleResult]?
    let featurePrint: FeaturePrintResult?
    let error: String?

    static func success(
        imageInfo: ImageInfo,
        textRecognition: [TextObservationResult],
        fullText: String?,
        faceDetection: [FaceObservationResult],
        barcodes: [BarcodeResult],
        objects: [ClassificationResult],
        imageAesthetics: AestheticsResult?,
        saliency: SaliencyResult?,
        bodyPose: BodyPoseResult?,
        handPoses: [HandPoseResult]?,
        animals: [AnimalResult]?,
        rectangles: [RectangleResult]?,
        horizon: HorizonResult?,
        contours: ContourResult?,
        humanRectangles: [HumanRectangleResult]?,
        featurePrint: FeaturePrintResult?
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
            bodyPose: bodyPose,
            handPoses: handPoses,
            animals: animals,
            rectangles: rectangles,
            horizon: horizon,
            contours: contours,
            humanRectangles: humanRectangles,
            featurePrint: featurePrint,
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
            bodyPose: nil,
            handPoses: nil,
            animals: nil,
            rectangles: nil,
            horizon: nil,
            contours: nil,
            humanRectangles: nil,
            featurePrint: nil,
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

// MARK: - Body Pose Models

struct BodyPoseResult: Codable {
    let joints: [String: JointPoint]
    let confidence: Float
}

struct JointPoint: Codable {
    let position: Point
    let confidence: Float
}

// MARK: - Hand Pose Models

struct HandPoseResult: Codable {
    let chirality: String  // "left" or "right"
    let joints: [String: JointPoint]
    let confidence: Float
}

// MARK: - Animal Recognition Models

struct AnimalResult: Codable {
    let label: String  // "cat" or "dog"
    let confidence: Float
    let boundingBox: BoundingBox
}

// MARK: - Shape Detection Models

struct RectangleResult: Codable {
    let boundingBox: BoundingBox
    let topLeft: Point
    let topRight: Point
    let bottomLeft: Point
    let bottomRight: Point
    let confidence: Float
}

struct HorizonResult: Codable {
    let angle: Float  // in degrees
    let confidence: Float
}

struct ContourResult: Codable {
    let contourCount: Int
    let normalizedPathCount: Int
}

struct HumanRectangleResult: Codable {
    let boundingBox: BoundingBox
    let confidence: Float
}

// MARK: - Feature Print Models

struct FeaturePrintResult: Codable {
    let elementCount: Int
    let elementType: String
}

// MARK: - Extensions for New Vision Observations

extension VNHumanBodyPoseObservation {
    func toResult() -> BodyPoseResult? {
        guard let recognizedPoints = try? recognizedPoints(.all) else { return nil }

        var joints: [String: JointPoint] = [:]
        for (key, point) in recognizedPoints {
            joints[String(describing: key.rawValue)] = JointPoint(
                position: Point(from: point.location),
                confidence: point.confidence
            )
        }

        return BodyPoseResult(
            joints: joints,
            confidence: confidence
        )
    }
}

extension VNHumanHandPoseObservation {
    func toResult() -> HandPoseResult? {
        guard let recognizedPoints = try? recognizedPoints(.all) else { return nil }

        var joints: [String: JointPoint] = [:]
        for (key, point) in recognizedPoints {
            joints[String(describing: key.rawValue)] = JointPoint(
                position: Point(from: point.location),
                confidence: point.confidence
            )
        }

        let chiralityString: String
        switch chirality {
        case .left:
            chiralityString = "left"
        case .right:
            chiralityString = "right"
        default:
            chiralityString = "unknown"
        }

        return HandPoseResult(
            chirality: chiralityString,
            joints: joints,
            confidence: confidence
        )
    }
}

extension VNRecognizedObjectObservation {
    func toAnimalResult() -> AnimalResult {
        return AnimalResult(
            label: labels.first?.identifier ?? "unknown",
            confidence: confidence,
            boundingBox: BoundingBox(from: boundingBox)
        )
    }
}

extension VNRectangleObservation {
    func toRectangleResult() -> RectangleResult {
        return RectangleResult(
            boundingBox: BoundingBox(from: boundingBox),
            topLeft: Point(from: topLeft),
            topRight: Point(from: topRight),
            bottomLeft: Point(from: bottomLeft),
            bottomRight: Point(from: bottomRight),
            confidence: confidence
        )
    }
}

extension VNHorizonObservation {
    func toResult() -> HorizonResult {
        // Convert angle from radians to degrees
        let degrees = angle * 180.0 / .pi
        return HorizonResult(
            angle: Float(degrees),
            confidence: confidence
        )
    }
}

extension VNContoursObservation {
    func toResult() -> ContourResult {
        // Get a rough count of points in the path
        var pointCount = 0
        normalizedPath.applyWithBlock { element in
            if element.pointee.type != .closeSubpath {
                pointCount += 1
            }
        }

        return ContourResult(
            contourCount: contourCount,
            normalizedPathCount: pointCount
        )
    }
}

extension VNHumanObservation {
    func toHumanRectangleResult() -> HumanRectangleResult {
        return HumanRectangleResult(
            boundingBox: BoundingBox(from: boundingBox),
            confidence: confidence
        )
    }
}

extension VNFeaturePrintObservation {
    func toResult() -> FeaturePrintResult {
        // VNFeaturePrintObservation doesn't directly expose element details
        // We can only return basic information
        return FeaturePrintResult(
            elementCount: data.count,
            elementType: String(describing: type(of: data))
        )
    }
}
