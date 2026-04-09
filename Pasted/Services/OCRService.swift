import Foundation
import Vision
import AppKit

/// Performs OCR text recognition on image data using Apple Vision framework.
/// All processing runs on background threads via Swift concurrency.
final class OCRService {

    /// Recognizes text in the given image data using VNRecognizeTextRequest with `.accurate` level.
    /// Returns an `OCRResult` on success, or `nil` if no text was found or the data is invalid.
    ///
    /// - Parameters:
    ///   - imageData: Raw image data (TIFF, PNG, JPEG, etc.)
    ///   - clipboardItemID: The UUID of the parent `ClipboardItem` to link the result to.
    /// - Returns: An `OCRResult` containing recognized text, confidence, and language, or `nil`.
    static func recognizeText(in imageData: Data, clipboardItemID: UUID = UUID()) async -> OCRResult? {
        guard !imageData.isEmpty else { return nil }

        return await withCheckedContinuation { continuation in
            // Create a CGImage from the data
            guard let nsImage = NSImage(data: imageData),
                  let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                continuation.resume(returning: nil)
                return
            }

            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                // Extract recognized text and average confidence
                var textLines: [String] = []
                var totalConfidence: Float = 0
                var observationCount: Int = 0

                for observation in observations {
                    if let topCandidate = observation.topCandidates(1).first {
                        textLines.append(topCandidate.string)
                        totalConfidence += topCandidate.confidence
                        observationCount += 1
                    }
                }

                guard !textLines.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                let recognizedText = textLines.joined(separator: "\n")
                let averageConfidence = Double(totalConfidence) / Double(observationCount)

                // Detect language from the recognized text
                let detectedLanguage = detectLanguage(for: recognizedText)

                let result = OCRResult(
                    clipboardItemID: clipboardItemID,
                    recognizedText: recognizedText,
                    confidence: averageConfidence,
                    language: detectedLanguage
                )

                continuation.resume(returning: result)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - Private

    /// Detects the dominant language of the given text using NLLanguageRecognizer-style heuristics.
    /// Falls back to nil if the language cannot be determined.
    private static func detectLanguage(for text: String) -> String? {
        guard !text.isEmpty else { return nil }
        let tagger = NSLinguisticTagger(tagSchemes: [.language], options: 0)
        tagger.string = text
        return tagger.dominantLanguage
    }
}
