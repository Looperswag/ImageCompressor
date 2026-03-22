import Foundation
import AppKit

/// Service for file operations and validation
struct FileService {

    // MARK: - Security Checks

    /// Check if path is within allowed directory (prevents path traversal)
    static func isPathSafe(_ url: URL, within directory: URL) -> Bool {
        let normalizedPath = url.standardizedFileURL.path
        let normalizedDir = directory.standardizedFileURL.path
        return normalizedPath.hasPrefix(normalizedDir + "/")
    }

    /// Check if file is a symbolic link
    static func isSymbolicLink(_ url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return false
        }
        return attributes[.type] as? FileAttributeType == .typeSymbolicLink
    }

    /// Validate file path is safe (no path traversal, absolute path)
    static func isPathSafe(_ url: URL) -> Bool {
        let normalized = url.standardizedFileURL.path
        // Must be absolute path
        guard normalized.hasPrefix("/") else { return false }
        // Must not contain path traversal
        guard !normalized.contains("/../") && !normalized.hasSuffix("/..") else { return false }
        return true
    }

    // MARK: - Validation

    /// Validate if a file is a supported image
    static func isValidImageFile(_ url: URL) -> Bool {
        // Reject symbolic links to prevent following external links
        guard !isSymbolicLink(url) else { return false }
        // Validate path safety
        guard isPathSafe(url) else { return false }
        let extensionLower = url.pathExtension.lowercased()
        return Constants.supportedExtensions.contains(extensionLower)
    }

    /// Validate file size
    static func isFileSizeAcceptable(_ url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return false
        }
        return size <= Constants.maxFileSize
    }

    /// Check if URL is a directory
    static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    // MARK: - Directory Operations

    /// Create output directory if needed
    static func createOutputDirectory(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    // MARK: - Output URL Generation

    /// Generate output URL for compressed image
    static func generateOutputURL(
        for inputURL: URL,
        outputDirectory: URL,
        format: ExportFormat
    ) -> URL {
        // Validate input URL is safe
        guard isPathSafe(inputURL) else {
            // Fallback: use UUID-based filename to ensure safety
            let safeName = UUID().uuidString
            let newExtension = format.fileExtension
            return outputDirectory.appendingPathComponent("\(safeName)_compressed.\(newExtension)")
        }

        // Prevent path traversal by using only the filename component
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        // Sanitize filename - remove any path components that might have slipped through
        let sanitizedBaseName = baseName.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.")).inverted).joined()
        let newExtension = format.fileExtension
        let fileName = "\(sanitizedBaseName)_compressed.\(newExtension)"

        var outputURL = outputDirectory.appendingPathComponent(fileName)

        // Use UUID to ensure unique filename and avoid TOCTOU race condition
        if FileManager.default.fileExists(atPath: outputURL.path) {
            let uuidSuffix = UUID().uuidString.prefix(8)
            let newName = "\(sanitizedBaseName)_compressed_\(uuidSuffix).\(newExtension)"
            outputURL = outputDirectory.appendingPathComponent(newName)
        }

        return outputURL
    }

    // MARK: - File Operations

    /// Get file size
    static func fileSize(at url: URL) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return 0
        }
        return size
    }

    /// Open file in Finder
    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Open directory in Finder
    static func openInFinder(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
