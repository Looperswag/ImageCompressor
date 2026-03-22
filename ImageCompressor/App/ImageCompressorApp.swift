import SwiftUI

@main
struct ImageCompressorApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 700, minHeight: 500)
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("添加图片...") {
                    NotificationCenter.default.post(name: .addImages, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(after: .toolbar) {
                Button("压缩全部") {
                    NotificationCenter.default.post(name: .compressAll, object: nil)
                }
                .keyboardShortcut("b", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let addImages = Notification.Name("addImages")
    static let compressAll = Notification.Name("compressAll")
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("defaultQuality") private var defaultQuality = 75
    @AppStorage("defaultFormat") private var defaultFormat = ExportFormat.jpeg.rawValue
    @AppStorage("stripMetadataDefault") private var stripMetadataDefault = true
    @AppStorage("showInFinderAfterCompression") private var showInFinderAfterCompression = true

    @State private var qualitySlider: Double = 75

    var body: some View {
        TabView {
            GeneralSettingsView(
                defaultQuality: $defaultQuality,
                defaultFormat: $defaultFormat,
                stripMetadataDefault: $stripMetadataDefault,
                showInFinderAfterCompression: $showInFinderAfterCompression,
                qualitySlider: $qualitySlider
            )
            .tabItem {
                Label("通用", systemImage: "gearshape")
            }

            AboutView()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(width: 400, height: 300)
        .onAppear {
            qualitySlider = Double(defaultQuality)
        }
    }
}

struct GeneralSettingsView: View {
    @Binding var defaultQuality: Int
    @Binding var defaultFormat: String
    @Binding var stripMetadataDefault: Bool
    @Binding var showInFinderAfterCompression: Bool
    @Binding var qualitySlider: Double

    var body: some View {
        Form {
            Section("默认设置") {
                Picker("默认格式", selection: $defaultFormat) {
                    ForEach(ExportFormat.visibleCases) { format in
                        Text(format.displayName).tag(format.rawValue)
                    }
                }

                VStack(alignment: .leading) {
                    Text("默认质量：\(Int(qualitySlider))%")
                    Slider(value: $qualitySlider, in: 1...100)
                        .onChange(of: qualitySlider) { _, newValue in
                            defaultQuality = Int(newValue)
                        }
                }

                Toggle("默认去除元数据", isOn: $stripMetadataDefault)
            }

            Section("压缩后") {
                Toggle("压缩后在 Finder 中显示", isOn: $showInFinderAfterCompression)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            Text(Constants.appName)
                .font(.title)
                .fontWeight(.bold)

            Text("版本 \(Constants.appVersion)")
                .foregroundStyle(.secondary)

            Text("快速简洁的 macOS 图片压缩工具")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            VStack(spacing: 8) {
                Text("基于 SwiftUI 构建")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Text("使用 macOS 内置 sips 进行压缩")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
