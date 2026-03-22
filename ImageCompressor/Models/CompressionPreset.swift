import Foundation

/// Unified compression preset for intelligent compression
struct CompressionPreset: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let quality: Int
    let maxDimension: Int?
    let format: ExportFormat
    let stripMetadata: Bool

    // Unified smart compression preset
    static let unified = CompressionPreset(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "智能压缩",
        description: "自动优化质量和格式",
        quality: 85,
        maxDimension: nil,
        format: .auto,
        stripMetadata: false
    )

    static let allPresets: [CompressionPreset] = [.unified]

    /// Custom preset with user-specified settings
    static func custom(
        quality: Int,
        maxDimension: Int?,
        format: ExportFormat,
        stripMetadata: Bool
    ) -> CompressionPreset {
        CompressionPreset(
            id: UUID(),
            name: "自定义",
            description: "用户自定义设置",
            quality: quality,
            maxDimension: maxDimension,
            format: format,
            stripMetadata: stripMetadata
        )
    }
}
