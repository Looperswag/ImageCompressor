import SwiftUI

struct DropZoneView: View {
    let isTargeted: Bool
    let onBrowse: () -> Void
    let onDrop: ([URL]) -> Void

    @State private var isDragOver = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(isDragOver ? Color.accentColor : .secondary)
                .accessibilityLabel("拖放区域图标")

            VStack(spacing: 8) {
                Text(isDragOver ? "放下添加图片" : "拖拽图片到这里")
                    .font(.title2)
                    .fontWeight(.medium)
                    .accessibilityLabel(isDragOver ? "放下添加图片" : "拖拽图片到这里")

                Text("或")
                    .foregroundStyle(.secondary)

                Button {
                    onBrowse()
                } label: {
                    Label("浏览文件", systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("浏览文件以添加图片")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
                .foregroundStyle(isDragOver ? Color.accentColor : .secondary.opacity(0.5))
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isDragOver ? Color.accentColor.opacity(0.1) : AppColors.cardBackground)
                }
        }
        .animation(.easeInOut(duration: Constants.defaultAnimationDuration), value: isDragOver)
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            handleDrop(providers: providers)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("将图片拖放到这里或点击浏览文件选择")
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    urls.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            onDrop(urls)
        }

        return true
    }
}

#Preview {
    DropZoneView(isTargeted: false, onBrowse: {}, onDrop: { _ in })
        .frame(width: 400, height: 300)
}
