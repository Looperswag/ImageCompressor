import Foundation

/// Service for persisting compression history
actor HistoryStorageService {

    private static let fileName = "compression_history.json"

    /// Get the storage URL and ensure directory exists
    private static func storageURL() throws -> URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw HistoryStorageError.appSupportNotFound
        }
        let appDir = appSupport.appendingPathComponent("ImageCompressor")

        // Create directory if needed with proper error handling
        if !FileManager.default.fileExists(atPath: appDir.path) {
            do {
                try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
            } catch {
                throw HistoryStorageError.directoryCreationFailed(error.localizedDescription)
            }
        }

        return appDir.appendingPathComponent(fileName)
    }

    /// Load history from storage
    static func load() async -> [CompressionHistory] {
        do {
            let url = try storageURL()
            let data = try Data(contentsOf: url)
            let history = try JSONDecoder().decode([CompressionHistory].self, from: data)
            return history
        } catch {
            print("警告：加载压缩历史失败：\(error.localizedDescription)")
            return []
        }
    }

    /// Save history to storage
    static func save(_ history: [CompressionHistory]) async throws {
        let url = try storageURL()
        let data = try JSONEncoder().encode(history)
        try data.write(to: url, options: .atomic)
    }

    /// Add a new history entry
    static func add(_ entry: CompressionHistory) async throws {
        var history = await load()

        // Keep only last 100 entries
        history.insert(entry, at: 0)
        if history.count > 100 {
            history = Array(history.prefix(100))
        }

        try await save(history)
    }

    /// Clear all history
    static func clear() async throws {
        try await save([])
    }
}

enum HistoryStorageError: LocalizedError {
    case appSupportNotFound
    case directoryCreationFailed(String)

    var errorDescription: String? {
        switch self {
        case .appSupportNotFound:
            return "找不到应用程序支持目录"
        case .directoryCreationFailed(let message):
            return "创建存储目录失败：\(message)"
        }
    }
}
