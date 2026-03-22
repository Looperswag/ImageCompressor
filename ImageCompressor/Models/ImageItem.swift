import Foundation
import SwiftUI

/// Represents a single image item in the compression queue
struct ImageItem: Identifiable, Codable, Hashable {
    let id: UUID
    let fileURL: URL
    let originalFileName: String
    var originalSize: Int64
    var compressedSize: Int64?
    var status: CompressionStatus
    var errorMessage: String?
    var thumbnail: Data?
    var outputURL: URL?

    // Security-scoped resource access
    var securityScopedBookmark: Data?

    init(fileURL: URL) {
        self.id = UUID()
        self.fileURL = fileURL
        self.originalFileName = fileURL.lastPathComponent
        self.originalSize = 0
        self.compressedSize = nil
        self.status = .pending
        self.errorMessage = nil
        self.thumbnail = nil
        self.outputURL = nil

        // Create security-scoped bookmark for sandbox access
        self.securityScopedBookmark = try? fileURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        // Get file size
        if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let size = attributes[.size] as? Int64 {
            self.originalSize = size
        }
    }

    /// File size as formatted string
    var originalSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
    }

    /// Compressed size as formatted string
    var compressedSizeFormatted: String? {
        guard let size = compressedSize else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    /// Compression ratio as percentage
    var compressionRatio: Double? {
        guard let compressed = compressedSize, originalSize > 0 else { return nil }
        return Double(originalSize - compressed) / Double(originalSize) * 100
    }

    /// Compression ratio formatted string
    var compressionRatioFormatted: String? {
        guard let ratio = compressionRatio else { return nil }
        return String(format: "-%.1f%%", ratio)
    }

    /// Access the file with security scope
    /// Returns a Result to allow callers to distinguish between different failure modes
    func accessSecurityScopedResource<T>(_ operation: (URL) throws -> T) -> Result<T, Error> {
        guard let bookmark = securityScopedBookmark else {
            return .failure(ImageItemError.missingBookmark)
        }

        var isStale = false
        guard var url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope, .withoutImplicitStartAccessing],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return .failure(ImageItemError.bookmarkResolutionFailed)
        }

        // If bookmark is stale, we cannot recover - the user must re-select the file
        if isStale {
            return .failure(ImageItemError.bookmarkStale)
        }

        guard url.startAccessingSecurityScopedResource() else {
            return .failure(ImageItemError.accessDenied)
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            return .success(try operation(url))
        } catch {
            return .failure(error)
        }
    }

    /// Read file data with security scope access
    /// This is the primary method for getting file contents in a sandboxed app
    func readFileData() -> Result<Data, Error> {
        accessSecurityScopedResource { url in
            try Data(contentsOf: url)
        }
    }

    /// Access the file with security scope for async operations
    /// This is the preferred method for compression operations in sandbox
    func withSecurityScopedAccess<T>(_ operation: (URL) async throws -> T) async throws -> T {
        guard let bookmark = securityScopedBookmark else {
            throw ImageItemError.missingBookmark
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope, .withoutImplicitStartAccessing],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            throw ImageItemError.bookmarkResolutionFailed
        }

        // If bookmark is stale, we cannot recover
        if isStale {
            throw ImageItemError.bookmarkStale
        }

        guard url.startAccessingSecurityScopedResource() else {
            throw ImageItemError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        return try await operation(url)
    }
}

enum ImageItemError: LocalizedError {
    case missingBookmark
    case bookmarkResolutionFailed
    case bookmarkStale
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .missingBookmark:
            return "缺少安全书签"
        case .bookmarkResolutionFailed:
            return "无法解析文件访问"
        case .bookmarkStale:
            return "文件访问权限已过期，请重新添加文件"
        case .accessDenied:
            return "文件访问被拒绝"
        }
    }
}

/// Compression status for an image item
enum CompressionStatus: String, Codable {
    case pending
    case processing
    case completed
    case failed
    case cancelled

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .processing: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "minus.circle"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .secondary
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }
}
