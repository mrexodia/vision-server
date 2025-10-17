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

        // Create all Vision requests
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        textRequest.automaticallyDetectsLanguage = true

        let faceLandmarksRequest = VNDetectFaceLandmarksRequest()
        let faceQualityRequest = VNDetectFaceCaptureQualityRequest()
        let barcodeRequest = VNDetectBarcodesRequest()
        let classificationRequest = VNClassifyImageRequest()
        let bodyPoseRequest = VNDetectHumanBodyPoseRequest()
        let handPoseRequest = VNDetectHumanHandPoseRequest()
        handPoseRequest.maximumHandCount = 2
        let attentionSaliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        let objectnessSaliencyRequest = VNGenerateObjectnessBasedSaliencyImageRequest()
        let animalRequest = VNRecognizeAnimalsRequest()
        let rectangleRequest = VNDetectRectanglesRequest()
        rectangleRequest.minimumAspectRatio = 0.1
        rectangleRequest.maximumAspectRatio = 1.0
        rectangleRequest.minimumSize = 0.1
        rectangleRequest.maximumObservations = 10
        let horizonRequest = VNDetectHorizonRequest()
        let contourRequest = VNDetectContoursRequest()
        contourRequest.contrastAdjustment = 1.0
        contourRequest.detectsDarkOnLight = true
        let humanRectangleRequest = VNDetectHumanRectanglesRequest()
        let featurePrintRequest = VNGenerateImageFeaturePrintRequest()

        // Use single handler for all requests - Vision framework handles parallelization
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // Perform all requests in parallel
        try handler.perform([
            textRequest,
            faceLandmarksRequest,
            faceQualityRequest,
            barcodeRequest,
            classificationRequest,
            bodyPoseRequest,
            handPoseRequest,
            attentionSaliencyRequest,
            objectnessSaliencyRequest,
            animalRequest,
            rectangleRequest,
            horizonRequest,
            contourRequest,
            humanRectangleRequest,
            featurePrintRequest
        ])

        // Extract text recognition results
        let textObservations = (textRequest.results as? [VNRecognizedTextObservation])?.compactMap { $0.toResult() } ?? []
        let fullText = textObservations.isEmpty ? nil : orderTextObservations(textObservations)

        // Extract face detection results
        var faceResults: [FaceObservationResult] = []
        if let landmarksObs = faceLandmarksRequest.results as? [VNFaceObservation] {
            faceResults = landmarksObs.map { $0.toResult() }
        }
        // Merge capture quality if available
        if let qualityObs = faceQualityRequest.results as? [VNFaceObservation] {
            for (index, qualityObservation) in qualityObs.enumerated() {
                if index < faceResults.count {
                    var result = faceResults[index]
                    result = FaceObservationResult(
                        boundingBox: result.boundingBox,
                        confidence: result.confidence,
                        landmarks: result.landmarks,
                        captureQuality: qualityObservation.faceCaptureQuality,
                        roll: result.roll,
                        yaw: result.yaw,
                        pitch: result.pitch
                    )
                    faceResults[index] = result
                }
            }
        }

        // Extract barcode results
        let barcodes = (barcodeRequest.results as? [VNBarcodeObservation])?.map { $0.toResult() } ?? []

        // Extract classification results
        let objects = (classificationRequest.results as? [VNClassificationObservation])?
            .filter { $0.confidence > 0.1 }
            .prefix(10)
            .map { $0.toResult() } ?? []

        // Extract body pose
        let bodyPose = (bodyPoseRequest.results as? [VNHumanBodyPoseObservation])?.first?.toResult()

        // Extract hand poses
        let handPoses = (handPoseRequest.results as? [VNHumanHandPoseObservation])?.compactMap { $0.toResult() }

        // Extract saliency results
        var attentionResult: SalientRegion? = nil
        var objectResults: [SalientObject] = []
        if let attentionObs = attentionSaliencyRequest.results?.first as? VNSaliencyImageObservation {
            attentionResult = SalientRegion(score: attentionObs.confidence)
        }
        if let objectnessObs = objectnessSaliencyRequest.results?.first as? VNSaliencyImageObservation,
           let salientObjects = objectnessObs.salientObjects {
            objectResults = salientObjects.map { SalientObject(boundingBox: BoundingBox(from: $0.boundingBox), confidence: $0.confidence) }
        }
        let saliency = SaliencyResult(objectBased: objectResults.isEmpty ? nil : objectResults, attentionBased: attentionResult)

        // Extract animal recognition
        let animals = (animalRequest.results as? [VNRecognizedObjectObservation])?.map { $0.toAnimalResult() }

        // Extract rectangles
        let rectangles = (rectangleRequest.results as? [VNRectangleObservation])?.map { $0.toRectangleResult() }

        // Extract horizon
        let horizon = (horizonRequest.results as? [VNHorizonObservation])?.first?.toResult()

        // Extract contours
        let contours = (contourRequest.results as? [VNContoursObservation])?.first?.toResult()

        // Extract human rectangles
        let humanRectangles = (humanRectangleRequest.results as? [VNHumanObservation])?.map { $0.toHumanRectangleResult() }

        // Extract feature print
        let featurePrint = (featurePrintRequest.results as? [VNFeaturePrintObservation])?.first?.toResult()

        return AnalysisResponse.success(
            imageInfo: imageInfo,
            textRecognition: textObservations,
            fullText: fullText,
            faceDetection: faceResults,
            barcodes: barcodes,
            objects: objects,
            imageAesthetics: nil,  // Requires macOS 15+ Sequoia with specific APIs
            saliency: saliency,
            bodyPose: bodyPose,
            handPoses: handPoses,
            animals: animals,
            rectangles: rectangles,
            horizon: horizon,
            contours: contours,
            humanRectangles: humanRectangles,
            featurePrint: featurePrint
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

    // MARK: - Text Ordering (Improved Algorithm)

    private func orderTextObservations(_ observations: [TextObservationResult]) -> String {
        guard !observations.isEmpty else { return "" }

        // Sort observations by Y-coordinate (top to bottom)
        // Note: Vision coordinates have origin at bottom-left, so higher Y = higher on page
        let sortedObservations = observations.sorted { $0.boundingBox.y > $1.boundingBox.y }

        var paragraphs: [[String]] = [[]]
        var previousY: Float = 1.0
        var previousHeight: Float = 0.06

        for observation in sortedObservations {
            let currentY = observation.boundingBox.y
            let height = observation.boundingBox.height
            let verticalGap = previousY - currentY - previousHeight

            // Detect paragraph breaks using vertical gaps
            // Use line height multiplier instead of fixed threshold to adapt to text size
            // Gap must be > 1.5x the average line height to be considered a paragraph break
            let avgHeight = (height + previousHeight) / 2.0
            let hasLargeVerticalGap = verticalGap > (avgHeight * 1.5)

            let isNewParagraph = hasLargeVerticalGap

            if isNewParagraph && !paragraphs.last!.isEmpty {
                paragraphs.append([])
            }

            paragraphs[paragraphs.count - 1].append(observation.text)
            previousY = currentY
            previousHeight = height
        }

        // Join paragraphs with double newlines
        return paragraphs
            .filter { !$0.isEmpty }
            .map { $0.joined(separator: " ") }
            .joined(separator: "\n\n")
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

    // MARK: - Body Pose Detection

    private func detectBodyPose(in image: CGImage) throws -> BodyPoseResult? {
        let request = VNDetectHumanBodyPoseRequest()

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNHumanBodyPoseObservation],
              let observation = observations.first else {
            return nil
        }

        return observation.toResult()
    }

    // MARK: - Hand Pose Detection

    private func detectHandPoses(in image: CGImage) throws -> [HandPoseResult] {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2  // Default: detect up to 2 hands

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNHumanHandPoseObservation] else {
            return []
        }

        return observations.compactMap { $0.toResult() }
    }

    // MARK: - Saliency Detection

    private func detectSaliency(in image: CGImage) throws -> SaliencyResult {
        let attentionRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        let objectnessRequest = VNGenerateObjectnessBasedSaliencyImageRequest()

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([attentionRequest, objectnessRequest])

        var attentionResult: SalientRegion? = nil
        var objectResults: [SalientObject] = []

        // Process attention-based saliency
        if let attentionObs = attentionRequest.results?.first as? VNSaliencyImageObservation {
            // Get overall saliency score (average of salient region)
            attentionResult = SalientRegion(score: attentionObs.confidence)
        }

        // Process objectness-based saliency
        if let objectnessObs = objectnessRequest.results?.first as? VNSaliencyImageObservation {
            if let salientObjects = objectnessObs.salientObjects {
                objectResults = salientObjects.map { obj in
                    SalientObject(
                        boundingBox: BoundingBox(from: obj.boundingBox),
                        confidence: obj.confidence
                    )
                }
            }
        }

        return SaliencyResult(
            objectBased: objectResults.isEmpty ? nil : objectResults,
            attentionBased: attentionResult
        )
    }

    // MARK: - Animal Recognition

    private func recognizeAnimals(in image: CGImage) throws -> [AnimalResult] {
        let request = VNRecognizeAnimalsRequest()

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNRecognizedObjectObservation] else {
            return []
        }

        return observations.map { $0.toAnimalResult() }
    }

    // MARK: - Rectangle Detection

    private func detectRectangles(in image: CGImage) throws -> [RectangleResult] {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.1
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.1
        request.maximumObservations = 10

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNRectangleObservation] else {
            return []
        }

        return observations.map { $0.toRectangleResult() }
    }

    // MARK: - Horizon Detection

    private func detectHorizon(in image: CGImage) throws -> HorizonResult? {
        let request = VNDetectHorizonRequest()

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNHorizonObservation],
              let observation = observations.first else {
            return nil
        }

        return observation.toResult()
    }

    // MARK: - Contour Detection

    private func detectContours(in image: CGImage) throws -> ContourResult? {
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 1.0
        request.detectsDarkOnLight = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNContoursObservation],
              let observation = observations.first else {
            return nil
        }

        return observation.toResult()
    }

    // MARK: - Human Rectangle Detection

    private func detectHumanRectangles(in image: CGImage) throws -> [HumanRectangleResult] {
        let request = VNDetectHumanRectanglesRequest()

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNHumanObservation] else {
            return []
        }

        return observations.map { $0.toHumanRectangleResult() }
    }

    // MARK: - Feature Print Generation

    private func generateFeaturePrint(for image: CGImage) throws -> FeaturePrintResult? {
        let request = VNGenerateImageFeaturePrintRequest()

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNFeaturePrintObservation],
              let observation = observations.first else {
            return nil
        }

        return observation.toResult()
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
