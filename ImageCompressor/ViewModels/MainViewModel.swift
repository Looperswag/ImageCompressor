import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
class MainViewModel {

    // MARK: - State

    var imageItems: [ImageItem] = []
    var isProcessing: Bool = false
    var currentProcessingIndex: Int?
    var progress: Double = 0
    var errorMessage: String?

    // Settings
    var selectedPreset: CompressionPreset = .unified
    var quality: Int = 85
    var maxDimension: Int?
    var exportFormat: ExportFormat = .auto
    var stripMetadata: Bool = false
    var outputDirectory: URL?

    // History
    var compressionHistory: [CompressionHistory] = []

    // Statistics
    var totalOriginalSize: Int64 { imageItems.reduce(0) { $0 + $1.originalSize } }
    var totalCompressedSize: Int64 { imageItems.compactMap { $0.compressedSize }.reduce(0, +) }
    var completedCount: Int { imageItems.filter { $0.status == .completed }.count }
    var failedCount: Int { imageItems.filter { $0.status == .failed }.count }

    // Cancellation support
    private var isCancelled: Bool = false

    // MARK: - Initialization

    init() {
        Task {
            await loadHistory()
        }
    }

    // MARK: - File Handling

    /// Handle dropped files
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []

        let group = DispatchGroup()

        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) ||
                  provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else {
                continue
            }

            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { [weak self] url, error in
                defer { group.leave() }
                guard let url = url, error == nil else { return }
                urls.append(url)
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.addFiles(urls)
        }

        return true
    }

    /// Handle file selection from open panel
    func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.message = "选择要压缩的图片"

        guard panel.runModal() == .OK else { return }

        addFiles(panel.urls)
    }

    /// Add files to the queue
    func addFiles(_ urls: [URL]) {
        for url in urls {
            // Skip if already added
            guard !imageItems.contains(where: { $0.fileURL == url }) else { continue }

            // Validate file
            guard FileService.isValidImageFile(url) else { continue }
            guard FileService.isFileSizeAcceptable(url) else { continue }

            var item = ImageItem(fileURL: url)

            // Generate thumbnail using security-scoped bookmark access
            // This ensures thumbnail generation works even for files outside sandbox
            Task {
                let thumbnailData: Data?
                let readResult = item.readFileData()

                switch readResult {
                case .success(let data):
                    // Generate thumbnail from data (sandbox-safe)
                    if let thumbnail = await SipsService.generateThumbnail(from: data),
                       let tiffData = thumbnail.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {
                        thumbnailData = pngData
                    } else {
                        thumbnailData = nil
                    }
                case .failure:
                    // Fall back to URL-based thumbnail (may fail if outside sandbox)
                    if let thumbnail = await SipsService.generateThumbnail(for: url),
                       let tiffData = thumbnail.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {
                        thumbnailData = pngData
                    } else {
                        thumbnailData = nil
                    }
                }

                // Update thumbnail on main thread
                if let data = thumbnailData {
                    await MainActor.run {
                        if let index = imageItems.firstIndex(where: { $0.id == item.id }) {
                            imageItems[index].thumbnail = data
                        }
                    }
                }
            }

            imageItems.append(item)
        }

        // Limit total files
        if imageItems.count > Constants.maxTotalFiles {
            imageItems = Array(imageItems.suffix(Constants.maxTotalFiles))
        }
    }

    /// Remove an item from the queue
    func removeItem(_ item: ImageItem) {
        imageItems.removeAll { $0.id == item.id }
    }

    /// Clear all items
    func clearAll() {
        imageItems.removeAll()
        errorMessage = nil
        progress = 0
    }

    // MARK: - Compression

    /// Start compression
    func startCompression() {
        guard !imageItems.isEmpty else { return }
        guard !isProcessing else { return }

        // Determine output directory
        let outputDir: URL
        if let customDir = outputDirectory {
            outputDir = customDir
        } else {
            // Default to Desktop/Compressed with safe fallback
            if let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
                outputDir = desktop.appendingPathComponent("Compressed Images")
            } else {
                // Fallback to Documents/Compressed
                let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                outputDir = documents.appendingPathComponent("Compressed Images")
            }
        }

        // Create output directory
        do {
            try FileService.createOutputDirectory(at: outputDir)
        } catch {
            errorMessage = "创建输出目录失败：\(error.localizedDescription)"
            return
        }

        isProcessing = true
        isCancelled = false
        progress = 0
        errorMessage = nil

        Task {
            await performCompression(outputDirectory: outputDir)
        }
    }

    /// Perform the actual compression
    private func performCompression(outputDirectory: URL) async {
        let totalItems = imageItems.count

        for (index, item) in imageItems.enumerated() {
            // Check for cancellation
            if isCancelled {
                break
            }

            currentProcessingIndex = index

            // Update status to processing
            imageItems[index].status = .processing

            do {
                // Generate output URL
                let outputURL = FileService.generateOutputURL(
                    for: item.fileURL,
                    outputDirectory: outputDirectory,
                    format: exportFormat
                )

                // Read file data using security-scoped bookmark
                // This ensures we can access files outside the sandbox (Desktop, Downloads, etc.)
                let inputData: Data
                let readResult = item.readFileData()

                switch readResult {
                case .success(let data):
                    inputData = data
                case .failure(let error):
                    throw error
                }

                // Perform compression using native AppKit APIs
                // This works within macOS sandbox without subprocess execution
                try await NativeCompressionService.compress(
                    inputData: inputData,
                    outputURL: outputURL,
                    format: exportFormat,
                    quality: quality,
                    maxDimension: maxDimension,
                    stripMetadata: stripMetadata
                )

                // Update with success
                await MainActor.run {
                    imageItems[index].status = .completed
                    imageItems[index].compressedSize = FileService.fileSize(at: outputURL)
                    imageItems[index].outputURL = outputURL
                }

            } catch {
                // Update with failure
                await MainActor.run {
                    imageItems[index].status = .failed
                    imageItems[index].errorMessage = error.localizedDescription
                }
            }

            progress = Double(index + 1) / Double(totalItems)
        }

        // Save history
        let completedItems = imageItems.filter { $0.status == .completed }
        if !completedItems.isEmpty {
            let history = CompressionHistory(presetName: selectedPreset.name, items: completedItems)
            do {
                try await HistoryStorageService.add(history)
                await loadHistory()
            } catch {
                // Log error but don't interrupt user flow
                print("警告：保存压缩历史失败：\(error.localizedDescription)")
            }
        }

        isProcessing = false
        currentProcessingIndex = nil

        // Open output directory - find the last successfully compressed file
        if let lastCompleted = imageItems.last(where: { $0.status == .completed })?.outputURL {
            FileService.revealInFinder(lastCompleted)
        } else if let outputURL = self.outputDirectory {
            // If no files were successfully compressed, open the output directory itself
            FileService.openInFinder(outputURL)
        }
    }

    /// Cancel compression
    func cancelCompression() {
        isCancelled = true
        isProcessing = false
        currentProcessingIndex = nil

        // Mark pending items as cancelled
        for index in imageItems.indices where imageItems[index].status == .processing {
            imageItems[index].status = .cancelled
        }
    }

    /// Select output directory
    func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "选择输出文件夹"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        outputDirectory = url
    }

    // MARK: - History

    private func loadHistory() async {
        compressionHistory = await HistoryStorageService.load()
    }

    func clearHistory() async {
        try? await HistoryStorageService.clear()
        compressionHistory = []
    }

    // MARK: - Helpers

    /// Update settings from preset
    func applyPreset(_ preset: CompressionPreset) {
        selectedPreset = preset
        quality = preset.quality
        maxDimension = preset.maxDimension
        exportFormat = preset.format
        stripMetadata = preset.stripMetadata
    }

    /// Open compressed file location
    func revealInFinder(_ item: ImageItem) {
        guard let outputURL = item.outputURL else { return }
        FileService.revealInFinder(outputURL)
    }
}
