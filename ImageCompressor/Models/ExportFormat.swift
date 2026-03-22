import Foundation

/// Supported export formats for image compression
enum ExportFormat: String, CaseIterable, Identifiable, Codable {
    case jpeg = "JPEG"
    case png = "PNG"
    case heic = "HEIC"
    case auto = "Auto"

    var id: String { rawValue }

    /// sips format string
    var sipsFormat: String {
        switch self {
        case .jpeg: return "jpeg"
        case .png: return "png"
        case .heic: return "heic"
        case .auto: return "jpeg" // Default when auto resolves
        }
    }

    /// File extension for the format
    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        case .auto: return "jpg"
        }
    }

    /// Whether this format supports quality settings
    var supportsQuality: Bool {
        switch self {
        case .jpeg: return true
        case .png: return false
        case .heic: return true
        case .auto: return true
        }
    }

    /// Display name with description
    var displayName: String {
        switch self {
        case .jpeg: return "JPEG"
        case .png: return "PNG"
        case .heic: return "HEIC"
        case .auto: return "自动"
        }
    }

    var description: String {
        switch self {
        case .jpeg: return "适合照片，文件更小"
        case .png: return "适合图形，无损压缩"
        case .heic: return "高效格式，节省空间"
        case .auto: return "自动选择最佳格式"
        }
    }

    /// Visible cases for UI picker (excludes .auto and .heic which are programmatic only)
    static let visibleCases: [ExportFormat] = [.jpeg, .png]

    /// Determine the best format for a given input format string
    /// - Parameter inputFormat: The format string from the input image (e.g., "jpeg", "png", "public.png")
    /// - Returns: The recommended export format
    static func bestFormat(for inputFormat: String) -> ExportFormat {
        let lowercased = inputFormat.lowercased()
        // Keep PNG format for images with transparency or lossless requirements
        if lowercased.contains("png") || lowercased.contains("tiff") || lowercased.contains("gif") {
            return .png
        }
        // Keep HEIC format for HEIC input (preserve high efficiency)
        if lowercased.contains("heic") {
            return .heic
        }
        // Default to JPEG for photos and other formats
        return .jpeg
    }
}
