import SwiftUI

struct MainView: View {
    @State private var viewModel = MainViewModel()
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showClearConfirmation = false
    @State private var showCancelConfirmation = false

    var body: some View {
        HSplitView {
            // Left panel - Settings
            settingsPanel
                .frame(minWidth: 220, maxWidth: 300)

            // Right panel - Main content
            contentPanel
                .frame(minWidth: 400, minHeight: 400)
        }
        .sheet(isPresented: $showHistory) {
            HistorySheet(history: viewModel.compressionHistory) {
                Task { await viewModel.clearHistory() }
            }
        }
        .confirmationDialog(
            "清除所有图片",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("清除全部", role: .destructive) {
                viewModel.clearAll()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这将从队列中移除所有图片。")
        }
        .confirmationDialog(
            "取消压缩",
            isPresented: $showCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("取消压缩", role: .destructive) {
                viewModel.cancelCompression()
            }
            Button("继续", role: .cancel) {}
        } message: {
            Text("确定要取消当前压缩吗？")
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showHistory = true
                } label: {
                    Label("历史记录", systemImage: "clock.arrow.circlepath")
                }
                .help("查看压缩历史")
                .accessibilityLabel("查看压缩历史")

                Button {
                    showClearConfirmation = true
                } label: {
                    Label("清除", systemImage: "trash")
                }
                .disabled(viewModel.imageItems.isEmpty || viewModel.isProcessing)
                .help("清除所有图片")
                .accessibilityLabel("清除所有图片")
            }
        }
    }

    // MARK: - Settings Panel

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Presets
            PresetPicker(
                selectedPreset: $viewModel.selectedPreset,
                presets: CompressionPreset.allPresets
            )
            .onChange(of: viewModel.selectedPreset) { _, newPreset in
                viewModel.applyPreset(newPreset)
            }

            Divider()

            // Format
            FormatPicker(selectedFormat: $viewModel.exportFormat)

            // Quality
            CompressionSlider(
                value: $viewModel.quality,
                range: Constants.minQuality...Constants.maxQuality,
                format: viewModel.exportFormat
            )
            .disabled(!viewModel.exportFormat.supportsQuality)

            // Dimension
            DimensionPicker(
                maxDimension: $viewModel.maxDimension,
                customValue: .constant("")
            )

            // Metadata
            Toggle("去除元数据", isOn: $viewModel.stripMetadata)
                .toggleStyle(.checkbox)

            Divider()

            // Output directory
            VStack(alignment: .leading, spacing: 8) {
                Text("输出文件夹")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    viewModel.selectOutputDirectory()
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text(viewModel.outputDirectory?.lastPathComponent ?? "桌面（已压缩）")
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .padding(8)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Spacer()
        }
        .padding()
        .background(AppColors.secondaryBackground)
    }

    // MARK: - Content Panel

    @ViewBuilder
    private var contentPanel: some View {
        VStack(spacing: 0) {
            if viewModel.imageItems.isEmpty {
                // Empty state
                DropZoneView(isTargeted: false, onBrowse: {
                    viewModel.selectFiles()
                }, onDrop: { urls in
                    viewModel.addFiles(urls)
                })
                .keyboardShortcut("o", modifiers: .command)
            } else {
                // Image list
                VStack(spacing: 0) {
                    ImageListView(
                        items: $viewModel.imageItems,
                        isProcessing: viewModel.isProcessing,
                        onRemove: { viewModel.removeItem($0) },
                        onReveal: { viewModel.revealInFinder($0) }
                    )

                    // Bottom bar
                    bottomBar
                }
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            // Progress bar (shown during processing)
            if viewModel.isProcessing {
                VStack(spacing: 4) {
                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(.linear)
                    Text("\(Int(viewModel.progress * 100))% 完成")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            Divider()

            HStack {
                // Statistics
                statisticsView

                Spacer()

                // Action buttons
                actionButtons
            }
            .padding()
            .background(AppColors.secondaryBackground)
        }
    }

    @ViewBuilder
    private var statisticsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(viewModel.imageItems.count) 张图片")
                .font(.subheadline)
                .fontWeight(.medium)
                .accessibilityLabel("\(viewModel.imageItems.count) 张图片在队列中")

            if viewModel.totalCompressedSize > 0 {
                Text("已节省：\(ByteCountFormatter.string(fromByteCount: viewModel.totalOriginalSize - viewModel.totalCompressedSize, countStyle: .file))")
                    .font(.caption)
                    .foregroundStyle(AppColors.savingsGreen)
                    .accessibilityLabel("已节省：\(ByteCountFormatter.string(fromByteCount: viewModel.totalOriginalSize - viewModel.totalCompressedSize, countStyle: .file))")
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Add more files
            Button {
                viewModel.selectFiles()
            } label: {
                Label("添加", systemImage: "plus")
            }
            .disabled(viewModel.isProcessing)
            .accessibilityLabel("添加更多图片")

            // Compress button
            Button {
                if viewModel.isProcessing {
                    showCancelConfirmation = true
                } else {
                    viewModel.startCompression()
                }
            } label: {
                if viewModel.isProcessing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("取消")
                    }
                } else {
                    Label("压缩", systemImage: "arrow.down.circle")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.imageItems.isEmpty || viewModel.isProcessing && viewModel.completedCount > 0)
            .accessibilityLabel(viewModel.isProcessing ? "取消压缩" : "开始压缩")

            // Open folder
            if let url = viewModel.outputDirectory ?? viewModel.imageItems.first?.outputURL?.deletingLastPathComponent() {
                Button {
                    FileService.openInFinder(url)
                } label: {
                    Image(systemName: "folder")
                }
                .help("打开输出文件夹")
                .accessibilityLabel("打开输出文件夹")
            }
        }
    }
}

// MARK: - History Sheet

struct HistorySheet: View {
    let history: [CompressionHistory]
    let onClear: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("压缩历史")
                .font(.title2)
                .padding()

            if history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text("暂无压缩历史")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(history) { entry in
                        HistoryRow(entry: entry)
                    }
                }
            }

            HStack {
                Button("清除历史", role: .destructive) {
                    onClear()
                }
                .disabled(history.isEmpty)
                .accessibilityLabel("清除历史")

                Spacer()

                Button("关闭") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("关闭历史")
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
}

struct HistoryRow: View {
    let entry: CompressionHistory

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.presetName)
                    .font(.headline)

                Text(entry.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(entry.fileCount) files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("-\(ByteCountFormatter.string(fromByteCount: entry.totalSaved, countStyle: .file))")
                    .font(.headline)
                    .foregroundStyle(AppColors.savingsGreen)

                Text(String(format: "已节省 %.1f%%", entry.savedPercentage))
                    .font(.caption)
                    .foregroundStyle(AppColors.savingsGreen)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.presetName), \(entry.fileCount) 个文件, 已节省 \(ByteCountFormatter.string(fromByteCount: entry.totalSaved, countStyle: .file))")
    }
}

#Preview {
    MainView()
        .frame(width: 800, height: 600)
}
