import SwiftUI

struct FormatPicker: View {
    @Binding var selectedFormat: ExportFormat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("输出格式")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("格式", selection: $selectedFormat) {
                ForEach(ExportFormat.visibleCases) { format in
                    HStack {
                        Text(format.displayName)
                        Text(format.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(format)
                }
            }
            .pickerStyle(.radioGroup)
        }
    }
}

struct DimensionPicker: View {
    @Binding var maxDimension: Int?
    @Binding var customValue: String

    let presets: [(String, Int?)] = [
        ("原始", nil),
        ("1920px (全高清)", 1920),
        ("1280px (高清)", 1280),
        ("1024px", 1024),
        ("800px", 800),
        ("640px", 640)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最大尺寸")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("最大尺寸", selection: $maxDimension) {
                ForEach(presets, id: \.1) { preset in
                    Text(preset.0).tag(preset.1)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

struct PresetPicker: View {
    @Binding var selectedPreset: CompressionPreset
    let presets: [CompressionPreset]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("预设")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("预设", selection: $selectedPreset) {
                ForEach(presets) { preset in
                    VStack(alignment: .leading) {
                        Text(preset.name)
                        Text(preset.description)
                            .font(.caption)
                    }
                    .tag(preset)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        FormatPicker(selectedFormat: .constant(.jpeg))
        DimensionPicker(maxDimension: .constant(nil), customValue: .constant(""))
        PresetPicker(selectedPreset: .constant(.unified), presets: CompressionPreset.allPresets)
    }
    .padding()
    .frame(width: 300)
}
