import SwiftUI

struct ImageListView: View {
    @Binding var items: [ImageItem]
    let isProcessing: Bool
    let onRemove: (ImageItem) -> Void
    let onReveal: (ImageItem) -> Void

    var body: some View {
        List {
            ForEach(items) { item in
                ImageRowView(
                    item: item,
                    isProcessing: isProcessing,
                    onReveal: { onReveal(item) }
                )
                .contextMenu {
                    Button {
                        onReveal(item)
                    } label: {
                        Label("在 Finder 中显示", systemImage: "folder")
                    }

                    if !isProcessing {
                        Divider()

                        Button(role: .destructive) {
                            onRemove(item)
                        } label: {
                            Label("移除", systemImage: "trash")
                        }
                    }
                }
            }
            .onMove { source, destination in
                items.move(fromOffsets: source, toOffset: destination)
            }
            .onDelete { indexSet in
                items.remove(atOffsets: indexSet)
            }
        }
        .listStyle(.inset)
    }
}

struct ImageRowView: View {
    let item: ImageItem
    let isProcessing: Bool
    let onReveal: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            thumbnailView
                .frame(width: 48, height: 48)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.originalFileName)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(item.originalSizeFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let compressed = item.compressedSizeFormatted {
                        Text("→")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text(compressed)
                            .font(.caption)
                            .foregroundStyle(AppColors.savingsGreen)

                        if let ratio = item.compressionRatioFormatted {
                            Text(ratio)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(AppColors.savingsGreen)
                        }
                    }
                }
            }

            Spacer()

            // Status
            statusView
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.originalFileName), \(statusDescription)")
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let data = item.thumbnail,
           let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .accessibilityLabel("\(item.originalFileName) 的缩略图")
        } else {
            Image(systemName: "photo")
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityLabel("图片缩略图占位符")
        }
    }

    private var statusDescription: String {
        switch item.status {
        case .pending: return "等待中"
        case .processing: return "处理中"
        case .completed:
            if let ratio = item.compressionRatioFormatted {
                return "已完成，已节省 \(ratio)"
            }
            return "已完成"
        case .failed: return "失败：\(item.errorMessage ?? "未知错误")"
        case .cancelled: return "已取消"
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch item.status {
        case .pending:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
                .accessibilityLabel("等待中")

        case .processing:
            ProgressView()
                .scaleEffect(0.7)
                .accessibilityLabel("处理中")

        case .completed:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppColors.savingsGreen)
                    .accessibilityLabel("已完成")

                Button {
                    onReveal()
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.plain)
                .help("在 Finder 中显示")
                .accessibilityLabel("在 Finder 中显示压缩文件")
            }

        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(AppColors.error)
                .help(item.errorMessage ?? "失败")
                .accessibilityLabel("失败：\(item.errorMessage ?? "未知错误")")

        case .cancelled:
            Image(systemName: "minus.circle")
                .foregroundStyle(AppColors.warning)
                .accessibilityLabel("已取消")
        }
    }
}

#Preview {
    ImageListView(
        items: .constant([]),
        isProcessing: false,
        onRemove: { _ in },
        onReveal: { _ in }
    )
}
