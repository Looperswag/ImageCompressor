import Foundation

/// A record of a completed compression batch
struct CompressionHistory: Identifiable, Codable {
    let id: UUID
    let date: Date
    let presetName: String
    let fileCount: Int
    let totalOriginalSize: Int64
    let totalCompressedSize: Int64
    let files: [HistoryFile]

    struct HistoryFile: Codable {
        let originalName: String
        let originalSize: Int64
        let compressedSize: Int64
    }

    init(presetName: String, items: [ImageItem]) {
        self.id = UUID()
        self.date = Date()
        self.presetName = presetName
        self.fileCount = items.count
        self.totalOriginalSize = items.reduce(0) { $0 + $1.originalSize }
        self.totalCompressedSize = items.compactMap { $0.compressedSize }.reduce(0, +)

        self.files = items.compactMap { item in
            guard let compressedSize = item.compressedSize else { return nil }
            return HistoryFile(
                originalName: item.originalFileName,
                originalSize: item.originalSize,
                compressedSize: compressedSize
            )
        }
    }

    var totalSaved: Int64 {
        totalOriginalSize - totalCompressedSize
    }

    var savedPercentage: Double {
        guard totalOriginalSize > 0 else { return 0 }
        return Double(totalSaved) / Double(totalOriginalSize) * 100
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
