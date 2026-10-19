import AppKit
import ScreenCaptureKit
import Vision

/// Captures a screen region with ScreenCaptureKit and extracts text or barcode payloads with Vision.
enum TextRecognizer {
    enum CaptureError: LocalizedError {
        case displayNotFound
        var errorDescription: String? { "The selected display is no longer available." }
    }

    /// Returns the recognized text, or nil when nothing was found. The image never leaves memory.
    static func captureAndRecognize(rect: CGRect, displayID: CGDirectDisplayID, scale: CGFloat) async throws -> String? {
        let image = try await capture(rect: rect, displayID: displayID, scale: scale)
        let d = UserDefaults.standard
        return await Task.detached(priority: .userInitiated) {
            if d.bool(forKey: Prefs.barcodeMode), let payload = barcodes(in: image) { return payload }
            if let text = recognize(image, orientation: .up) { return text }
            if d.bool(forKey: Prefs.rotateRetry) { return recognize(image, orientation: .right) }
            return nil
        }.value
    }

    /// Languages the installed Vision revision can recognize.
    static func supportedLanguages() -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        return (try? request.supportedRecognitionLanguages()) ?? ["en-US"]
    }

    private static func capture(rect: CGRect, displayID: CGDirectDisplayID, scale: CGFloat) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.displayNotFound
        }
        let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = rect
        config.width = max(1, Int((rect.width * scale).rounded()))
        config.height = max(1, Int((rect.height * scale).rounded()))
        config.showsCursor = false
        config.captureResolution = .best
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    private static func barcodes(in image: CGImage) -> String? {
        let request = VNDetectBarcodesRequest()
        try? VNImageRequestHandler(cgImage: image).perform([request])
        let payloads = (request.results ?? []).compactMap(\.payloadStringValue).filter { !$0.isEmpty }
        return payloads.isEmpty ? nil : payloads.joined(separator: "\n")
    }

    private static func recognize(_ image: CGImage, orientation: CGImagePropertyOrientation) -> String? {
        let d = UserDefaults.standard
        let request = VNRecognizeTextRequest()
        let accurate = d.bool(forKey: Prefs.accurate)
        request.recognitionLevel = accurate ? .accurate : .fast
        request.usesLanguageCorrection = accurate
        request.automaticallyDetectsLanguage = d.bool(forKey: Prefs.autoDetectLanguage)
        let languages = Prefs.selectedLanguages
        if !languages.isEmpty { request.recognitionLanguages = languages }
        do {
            try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
        } catch {
            return nil
        }
        let observations = request.results ?? []
        let text = format(observations, join: d.bool(forKey: Prefs.joinLines), trim: d.bool(forKey: Prefs.trimWhitespace))
        return text.isEmpty ? nil : text
    }

    /// Orders observations top-to-bottom, then left-to-right, grouping boxes on the same visual line.
    static func format(_ observations: [VNRecognizedTextObservation], join: Bool, trim: Bool) -> String {
        let items = observations.compactMap { obs -> (box: CGRect, text: String)? in
            guard let text = obs.topCandidates(1).first?.string else { return nil }
            return (obs.boundingBox, text)
        }.sorted { $0.box.midY > $1.box.midY }

        var lines: [[(box: CGRect, text: String)]] = []
        for item in items {
            if let last = lines.last?.first, abs(last.box.midY - item.box.midY) < min(last.box.height, item.box.height) / 2 {
                lines[lines.count - 1].append(item)
            } else {
                lines.append([item])
            }
        }
        var rendered = lines.map { line in
            line.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ")
        }
        if trim {
            rendered = rendered.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        let result = rendered.joined(separator: join ? " " : "\n")
        return trim ? result.trimmingCharacters(in: .whitespacesAndNewlines) : result
    }
}
