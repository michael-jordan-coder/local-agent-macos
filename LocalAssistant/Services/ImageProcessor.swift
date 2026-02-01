import AppKit
import CryptoKit
import Foundation

enum ImageProcessor {
    private static let maxDimension: CGFloat = 1024

    /// In-memory cache: SHA256 hex of raw Data → base64 encoded (possibly downscaled) string.
    private static var base64Cache: [String: String] = [:]

    /// Processes raw image data: downscales if needed, caches base64 result.
    static func processedBase64(for imageData: Data) -> String {
        let key = sha256Hex(imageData)
        if let cached = base64Cache[key] {
            return cached
        }

        let result: String
        if let downscaled = downscale(imageData) {
            result = downscaled.base64EncodedString()
        } else {
            result = imageData.base64EncodedString()
        }

        base64Cache[key] = result
        return result
    }

    /// Batch-process an array of image Data into base64 strings.
    static func processedBase64Array(_ images: [Data]) -> [String] {
        images.map { processedBase64(for: $0) }
    }

    static func clearCache() {
        base64Cache.removeAll()
    }

    // MARK: - Private

    private static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func downscale(_ data: Data) -> Data? {
        guard let image = NSImage(data: data) else { return nil }

        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else {
            return nil // no downscale needed
        }

        let scale: CGFloat
        if size.width >= size.height {
            scale = maxDimension / size.width
        } else {
            scale = maxDimension / size.height
        }

        let newSize = NSSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())

        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(newSize.width),
            pixelsHigh: Int(newSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        bitmapRep.size = newSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize))
        NSGraphicsContext.restoreGraphicsState()

        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.82])
    }
}
