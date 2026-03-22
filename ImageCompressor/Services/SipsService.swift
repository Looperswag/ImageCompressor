import Foundation
import AppKit

/// Service for interacting with the macOS `sips` command-line tool
actor SipsService {

    /// Image properties returned by sips
    struct ImageProperties {
        let width: Int
        let height: Int
        let format: String
        let dpiWidth: Int
        let dpiHeight: Int
    }

    /// Compress an image using sips with security-scoped bookmark support
    /// Note: inputURL must be accessed via security scope before calling this method
    /// or the inputData must be provided directly
    static func compress(
        inputData: Data,
        outputURL: URL,
        format: ExportFormat,
        quality: Int,
        maxDimension: Int?,
        stripMetadata: Bool
    ) async throws {
        // Validate output directory is writable
        let outputDir = outputURL.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: outputDir.path) else {
            throw SipsError.invalidInput
        }

        // Validate output path is safe
        guard FileService.isPathSafe(outputURL) else {
            throw SipsError.invalidInput
        }

        // Create a temporary file within the app's sandbox for sips to process
        let tempDir = FileManager.default.temporaryDirectory
        let tempInputURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("tmp")

        defer {
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempInputURL)
        }

        // Write input data to temp file
        try inputData.write(to: tempInputURL)

        // Determine output format
        let resolvedFormat: ExportFormat
        if format == .auto {
            // Detect format from input data (check file signature)
            resolvedFormat = detectFormat(from: inputData)
        } else {
            resolvedFormat = format
        }

        var arguments: [String] = []

        // Format and quality
        arguments.append("-s")
        arguments.append("format")
        arguments.append(resolvedFormat.sipsFormat)
        arguments.append("-s")
        arguments.append("formatOptions")
        arguments.append(resolvedFormat == .jpeg ? "\(quality)" : "default")

        // Dimension constraint (maintains aspect ratio)
        if let maxDim = maxDimension {
            arguments.append("-Z")
            arguments.append("\(maxDim)")
        }

        // Strip metadata if requested
        if stripMetadata {
            arguments.append("-a") // Strip all properties
        }

        // Input and output - use temp file path
        arguments.append(tempInputURL.path)
        arguments.append("--out")
        arguments.append(outputURL.path)

        let result = try await ProcessRunner.run(
            executable: "/usr/bin/sips",
            arguments: arguments,
            timeout: 60
        )

        guard result.succeeded else {
            throw SipsError.compressionFailed
        }
    }

    /// Detect image format from file data
    private static func detectFormat(from data: Data) -> ExportFormat {
        guard data.count >= 12 else { return .jpeg }

        // Check for PNG signature
        if data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 {
            return .png
        }

        // Check for JPEG signature
        if data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF {
            return .jpeg
        }

        // Check for HEIC signature (ftypheic)
        // Note: sips doesn't support HEIC as output format, so we convert to JPEG
        if data.count >= 12 {
            let header = data.subdata(in: 4..<12).map { String(format: "%02x", $0) }.joined()
            if header.contains("66747970") && // "ftyp"
               data[8..<12].elementsEqual([0x68, 0x65, 0x69, 0x63]) { // "heic"
                return .jpeg  // Convert HEIC input to JPEG output
            }
        }

        // Default to JPEG
        return .jpeg
    }

    /// Get image properties from data using sips
    static func getProperties(for imageData: Data) async throws -> ImageProperties {
        // Create a temporary file for sips to process
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("tmp")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        try imageData.write(to: tempURL)

        let result = try await ProcessRunner.run(
            executable: "/usr/bin/sips",
            arguments: ["-g", "all", tempURL.path],
            timeout: 10
        )

        guard result.succeeded else {
            throw SipsError.propertyReadFailed
        }

        return parseProperties(from: result.standardOutput)
    }

    /// Generate a thumbnail for preview using modern NSGraphicsContext API
    @MainActor
    static func generateThumbnail(for url: URL, maxSize: Int = Constants.thumbnailSize) async -> NSImage? {
        guard let image = NSImage(contentsOf: url) else { return nil }

        let ratio = min(
            CGFloat(maxSize) / image.size.width,
            CGFloat(maxSize) / image.size.height
        )

        let newSize = NSSize(
            width: image.size.width * ratio,
            height: image.size.height * ratio
        )

        // Use modern NSGraphicsContext instead of deprecated lockFocus/unlockFocus
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        if let context = NSGraphicsContext.current {
            context.imageInterpolation = .high
            image.draw(
                in: NSRect(origin: .zero, size: newSize),
                from: NSRect(origin: .zero, size: image.size),
                operation: .copy,
                fraction: 1.0
            )
        }
        newImage.unlockFocus()

        return newImage
    }

    /// Generate a thumbnail from image data (sandbox-safe version)
    @MainActor
    static func generateThumbnail(from data: Data, maxSize: Int = Constants.thumbnailSize) async -> NSImage? {
        guard let image = NSImage(data: data) else { return nil }

        let ratio = min(
            CGFloat(maxSize) / image.size.width,
            CGFloat(maxSize) / image.size.height
        )

        let newSize = NSSize(
            width: image.size.width * ratio,
            height: image.size.height * ratio
        )

        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        if let context = NSGraphicsContext.current {
            context.imageInterpolation = .high
            image.draw(
                in: NSRect(origin: .zero, size: newSize),
                from: NSRect(origin: .zero, size: image.size),
                operation: .copy,
                fraction: 1.0
            )
        }
        newImage.unlockFocus()

        return newImage
    }

    /// Parse sips output to extract properties
    private static func parseProperties(from output: String) -> ImageProperties {
        var width = 0, height = 0, dpiWidth = 72, dpiHeight = 72
        var format = "unknown"

        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("pixelWidth:") {
                width = Int(trimmed.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "0") ?? 0
            } else if trimmed.contains("pixelHeight:") {
                height = Int(trimmed.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "0") ?? 0
            } else if trimmed.contains("format:") {
                format = trimmed.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "unknown"
            } else if trimmed.contains("dpiWidth:") {
                dpiWidth = Int(trimmed.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "72") ?? 72
            } else if trimmed.contains("dpiHeight:") {
                dpiHeight = Int(trimmed.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "72") ?? 72
            }
        }

        return ImageProperties(
            width: width,
            height: height,
            format: format,
            dpiWidth: dpiWidth,
            dpiHeight: dpiHeight
        )
    }
}

enum SipsError: LocalizedError {
    case compressionFailed
    case propertyReadFailed
    case invalidInput

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "压缩失败"
        case .propertyReadFailed:
            return "读取图片属性失败"
        case .invalidInput:
            return "无效的输入图片"
        }
    }
}
